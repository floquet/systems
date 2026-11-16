#!/usr/bin/env bash
set -euo pipefail
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

HOST="$(hostname)"
LOG_FILE="hardware-probe_${HOST}.log"
BANNER=$(printf '=%.0s' {1..80})
DIVIDER=$(printf -- '-%.0s' {1..80})
STRESS_SEC="${1:-0}"   # Pass seconds as arg 1 (e.g., ./probe-hardware.sh 15) to run 24-thread load check

run_cmd() {
    printf "\n+ %s\n" "$*"
    "$@"
}

read_pkg_temp() {
    for tz in /sys/class/thermal/thermal_zone*; do
        if [[ -r "$tz/type" && "$(cat "$tz/type")" == "x86_pkg_temp" ]]; then
            awk '{printf "%.1f C", $1/1000}' "$tz/temp"
            return
        fi
    done
    printf "N/A"
}

{
    echo "$BANNER"
    echo "HARDWARE & SUBSYSTEM CHARACTERIZATION PROBE: ${HOST}"
    echo "Timestamp: $(date -Is)"
    echo "Kernel:    $(uname -srmo)"
    echo "$BANNER"

    echo ""
    echo "1. PROCESSOR TOPOLOGY, CACHES & FREQUENCY"
    echo "$DIVIDER"
    run_cmd lscpu | grep -E "Model name|Architecture|CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|MHz|cache|Virtualization"
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        printf "+ cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor\n"
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    fi

    echo ""
    echo "2. MEMORY (RAM) CAPACITY & DIMM TOPOLOGY"
    echo "$DIVIDER"
    run_cmd free -h
    if command -v lshw >/dev/null 2>&1; then
        printf "+ lshw -short -C memory\n"
        lshw -short -C memory 2>/dev/null || true
    fi

    echo ""
    echo "3. PHYSICAL STORAGE (EXCLUDING LOOP DEVICES)"
    echo "$DIVIDER"
    run_cmd lsblk -d -e 7 -o NAME,MODEL,SIZE,ROTA,TRAN,SCHED,MOUNTPOINTS
    run_cmd df -h / "$HOME"

    echo ""
    echo "4. SEQUENTIAL STORAGE THROUGHPUT (DIRECT I/O SCRATCH TEST)"
    echo "$DIVIDER"
    SCRATCH_FILE="./.probe_io_tmp_${HOST}.bin"
    trap 'rm -f "$SCRATCH_FILE"' EXIT
    run_cmd dd if=/dev/zero of="$SCRATCH_FILE" bs=1M count=1024 oflag=direct status=none
    WRITE_OUT=$(dd if=/dev/zero of="$SCRATCH_FILE" bs=1M count=1024 oflag=direct 2>&1 | tail -n 1)
    READ_OUT=$(dd if="$SCRATCH_FILE" of=/dev/null bs=1M iflag=direct 2>&1 | tail -n 1)
    rm -f "$SCRATCH_FILE"
    echo "Sequential Write (1 GiB O_DIRECT): $WRITE_OUT"
    echo "Sequential Read  (1 GiB O_DIRECT): $READ_OUT"

    echo ""
    echo "5. PCIe / GPU / NETWORK INTERCONNECTS"
    echo "$DIVIDER"
    if command -v lspci >/dev/null 2>&1; then
        run_cmd lspci | grep -E "VGA|3D|Display|NVMe|SATA|Ethernet|Network" || true
    fi

    echo ""
    echo "6. THERMALS & SUSTAINED LOAD CHECK"
    echo "$DIVIDER"
    echo "Baseline Package Temp: $(read_pkg_temp)"

    if [[ "$STRESS_SEC" -gt 0 ]]; then
        NTHREADS=$(nproc)
        echo "Launching ${NTHREADS} worker threads for ${STRESS_SEC}s (watch htop)..."
        PIDS=()
        for ((i=0; i<NTHREADS; i++)); do
            timeout "${STRESS_SEC}s" sha256sum /dev/zero >/dev/null 2>&1 &
            PIDS+=($!)
        done
        sleep $(( STRESS_SEC > 2 ? STRESS_SEC - 1 : 1 ))
        AVG_MHZ=$(awk '/cpu MHz/ {sum+=$4; n++} END {if(n>0) printf "%.1f MHz", sum/n}' /proc/cpuinfo)
        LOAD_TEMP=$(read_pkg_temp)
        wait "${PIDS[@]}" 2>/dev/null || true
        echo "Under ${NTHREADS}-Thread Load -> Avg Core Clock: ${AVG_MHZ} | Package Temp: ${LOAD_TEMP}"
    fi

    echo ""
    echo "$BANNER"
    echo "PROBE COMPLETE — Saved to ${LOG_FILE}"
    echo "$BANNER"
} 2>&1 | tee "$LOG_FILE"

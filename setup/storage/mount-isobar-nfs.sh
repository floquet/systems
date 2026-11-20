#!/usr/bin/env bash
printf "%s\n" "$(tput bold 2>/dev/null || true)$(date) ${BASH_SOURCE[0]}$(tput sgr0 2>/dev/null || true)"
# invocation: sudo ./mount-isobar-nfs.sh 2>&1 | tee mount-isobar-nfs.log
set -euo pipefail

counter=0
subcounter=0
start_time=${SECONDS}

function new_step() {
    export counter=$((counter + 1))
    export subcounter=0
    echo ""
    echo "Step ${counter}: ${1}"
}

function sub_step() {
    export subcounter=$((subcounter + 1))
    echo ""
    echo "  Substep ${counter}.${subcounter}: ${1}"
}

function display_total_elapsed_time() {
    local total_elapsed_time=$((SECONDS - start_time))
    local total_minutes=$((total_elapsed_time / 60))
    local total_seconds=$((total_elapsed_time % 60))
    echo ""
    printf "Total elapsed time: %02d:%02d (MM:SS)\n" "$total_minutes" "$total_seconds"
}

# --- Configuration ---
NAS_HOST="isobar"
NAS_IP="10.11.26.37"
SHARES=("anode" "cathode")
EXPORT_ROOT="/srv/nfs"
MOUNT_ROOT="/mnt"
NFS_OPTS="nfsvers=3,tcp,nofail,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.device-timeout=10,x-systemd.idle-timeout=600,_netdev"

if [[ ${EUID} -ne 0 ]]; then
    echo "Error: Run with sudo (sudo ${BASH_SOURCE[0]})" >&2
    exit 1
fi

new_step "Register ${NAS_HOST} (${NAS_IP}) in /etc/hosts"
if grep -qE "^[[:space:]]*${NAS_IP}[[:space:]]+.*\b${NAS_HOST}\b" /etc/hosts; then
    sub_step "${NAS_HOST} already mapped to ${NAS_IP} in /etc/hosts"
else
    sed -i.bak "/[[:space:]]${NAS_HOST}\b/d" /etc/hosts
    printf "%s\t%s\n" "${NAS_IP}" "${NAS_HOST}" >> /etc/hosts
    sub_step "Added '${NAS_IP} ${NAS_HOST}' to /etc/hosts (backup at /etc/hosts.bak)"
fi

new_step "Verify NFS client tooling (nfs-common)"
if command -v mount.nfs >/dev/null 2>&1; then
    sub_step "nfs-common already installed"
else
    sub_step "Installing nfs-common via apt"
    apt-get update -qq && apt-get install -y -qq nfs-common
fi

new_step "Configure mount points and /etc/fstab entries for ${SHARES[*]}"
cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

for share in "${SHARES[@]}"; do
    local_mnt="${MOUNT_ROOT}/${share}"
    remote_src="${NAS_HOST}:${EXPORT_ROOT}/${share}"
    fstab_line="${remote_src}  ${local_mnt}  nfs  ${NFS_OPTS}  0  0"

    sub_step "Preparing ${local_mnt} -> ${remote_src}"
    mkdir -p "${local_mnt}"

    if grep -qE "^[[:space:]]*${remote_src}[[:space:]]+" /etc/fstab; then
        echo "    Entry for ${remote_src} already exists in /etc/fstab"
    else
        printf "%s\n" "${fstab_line}" >> /etc/fstab
        echo "    Appended to /etc/fstab: ${fstab_line}"
    fi
done

new_step "Reload systemd units and verify fstab syntax"
systemctl daemon-reload
findmnt --verify --verbose

new_step "Test connectivity and mount status for ${NAS_HOST}"
if ping -c 1 -W 2 "${NAS_HOST}" >/dev/null 2>&1; then
    systemctl restart remote-fs.target || true
    for share in "${SHARES[@]}"; do
        sub_step "Checking ${MOUNT_ROOT}/${share}"
        ls -ld "${MOUNT_ROOT}/${share}" || true
    done
    df -hT -t nfs || true
else
    echo "Notice: ${NAS_HOST} (${NAS_IP}) is currently unreachable; automounts will activate automatically once online."
fi

display_total_elapsed_time

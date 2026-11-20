#!/usr/bin/env bash
printf "%s\n" "$(tput bold 2>/dev/null || true)$(date) ${BASH_SOURCE[0]}$(tput sgr0 2>/dev/null || true)"
# invocation: ./export-isobar-nfs.sh 2>&1 | tee export-isobar-nfs.log
set -euo pipefail
trap 'echo "ERROR on line ${LINENO}: ${BASH_COMMAND}" >set -euo pipefail2' ERR

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
TARGET_HOST="isobar"
LAN_SUBNET="10.11.26.0/24"
OWNER_UID="1000"
OWNER_GID="1000"

declare -A DRIVE_UUIDS=(
    ["anode"]="3bb8c0ab-309b-4dcf-8c35-008423e53b2c"
    ["cathode"]="42a274db-0816-49a8-9563-4a973d252082"
)

MOUNT_ROOT="/mnt"
EXPORT_ROOT="/srv/nfs"
EXT4_OPTS="defaults,noatime,nofail,x-systemd.device-timeout=10"
NFS_EXPORT_OPTS="rw,sync,no_subtree_check,no_root_squash"

if [[ ${EUID} -ne 0 ]]; then
    echo "Error: Run as root on ${TARGET_HOST}" >&2
    exit 1
fi

new_step "Set system hostname to ${TARGET_HOST}"
if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl set-hostname "${TARGET_HOST}"
else
    printf "%s\n" "${TARGET_HOST}" > /etc/hostname
    hostname "${TARGET_HOST}"
fi

if grep -qE "^127\.0\.1\.1[[:space:]]+" /etc/hosts; then
    sed -i.bak "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t${TARGET_HOST}/" /etc/hosts
else
    printf "127.0.1.1\t%s\n" "${TARGET_HOST}" >> /etc/hosts
fi
sub_step "Hostname verified as: $(hostname)"

new_step "Verify NFS kernel server packages"
if dpkg -s nfs-kernel-server >/dev/null 2>&1; then
    sub_step "nfs-kernel-server already installed"
else
    sub_step "Installing nfs-kernel-server via apt-get"
    apt-get update -qq && apt-get install -y -qq nfs-kernel-server
fi

new_step "Configure persistent UUID mounts and NFSv4 bind mounts"
cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
mkdir -p "${EXPORT_ROOT}"

for name in anode cathode; do
    uuid="${DRIVE_UUIDS[$name]}"
    phys_mnt="${MOUNT_ROOT}/${name}"
    export_dir="${EXPORT_ROOT}/${name}"

    sub_step "Mounting UUID=${uuid} -> ${phys_mnt} and binding -> ${export_dir}"
    mkdir -p "${phys_mnt}" "${export_dir}"

    phys_line="UUID=${uuid}  ${phys_mnt}  ext4  ${EXT4_OPTS}  0  2"
    if grep -qE "^[[:space:]]*UUID=${uuid}[[:space:]]+" /etc/fstab; then
        echo "    Physical mount for UUID=${uuid} already in /etc/fstab"
    else
        printf "%s\n" "${phys_line}" >> /etc/fstab
        echo "    Added: ${phys_line}"
    fi

    bind_line="${phys_mnt}  ${export_dir}  none  bind,nofail,x-systemd.requires-mounts-for=${phys_mnt}  0  0"
    if grep -qE "^[[:space:]]*${phys_mnt}[[:space:]]+${export_dir}[[:space:]]+" /etc/fstab; then
        echo "    Bind mount for ${export_dir} already in /etc/fstab"
    else
        printf "%s\n" "${bind_line}" >> /etc/fstab
        echo "    Added: ${bind_line}"
    fi
done

new_step "Activate mounts and set UID/GID ${OWNER_UID}:${OWNER_GID} ownership"
systemctl daemon-reload
mount -a
for name in anode cathode; do
    chown "${OWNER_UID}:${OWNER_GID}" "${MOUNT_ROOT}/${name}"
done
for m in /mnt/anode /mnt/cathode /srv/nfs/anode /srv/nfs/cathode; do findmnt -T "$m"; done

new_step "Configure /etc/exports for NFSv4 (${LAN_SUBNET})"
if [[ -f /etc/exports ]]; then
    cp -a /etc/exports "/etc/exports.bak.$(date +%Y%m%d-%H%M%S)"
fi

root_export="${EXPORT_ROOT}  ${LAN_SUBNET}(ro,fsid=0,sync,no_subtree_check)"
if ! grep -qE "^[[:space:]]*${EXPORT_ROOT}[[:space:]]+" /etc/exports 2>/dev/null; then
    printf "%s\n" "${root_export}" >> /etc/exports
fi

for name in anode cathode; do
    export_dir="${EXPORT_ROOT}/${name}"
    share_export="${export_dir}  ${LAN_SUBNET}(${NFS_EXPORT_OPTS})"
    sub_step "Adding export rule for ${export_dir}"
    if grep -qE "^[[:space:]]*${export_dir}[[:space:]]+" /etc/exports; then
        echo "    Export rule for ${export_dir} already exists"
    else
        printf "%s\n" "${share_export}" >> /etc/exports
        echo "    Added: ${share_export}"
    fi
done

new_step "Reload NFS exports and enable nfs-kernel-server on boot"
exportfs -ra
systemctl enable --now nfs-kernel-server
exportfs -v

display_total_elapsed_time

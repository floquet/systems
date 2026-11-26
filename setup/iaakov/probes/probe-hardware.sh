#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./probe-hardware.sh
# invocation: probe-hardware-iaakov
# arguments: none
# flags: none
# purpose: discover available computational resources
# requirements: standard Ubuntu utilities
# privileges: none
# system modifications: none

counter=0
start_time=${SECONDS}

new_step()
{
    counter=$((counter + 1))
    printf '\nStep %d: %s\n' "${counter}" "$1"
}

probe()
{
    printf '\n%s' '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
}

new_step "Machine identity"
probe hostname

new_step "Processor topology"
printf "\n$ lscpu (selected fields)\n\n"
lscpu | grep -E "^[[:space:]]*(Architecture|Model name|CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|CPU max MHz|CPU min MHz|L1d|L1i|L2|L3|NUMA node\(s\)):"

new_step "Available processing units"
probe nproc

new_step "Memory capacity"
probe free -h

new_step "Storage devices"
probe lsblk -e 7 -o NAME,MODEL,SIZE,TYPE,ROTA,MOUNTPOINTS

new_step "Filesystem capacity"
probe df -h / "$HOME"

new_step "Virtualization environment"
probe systemd-detect-virt

new_step "Summary"
elapsed=$((SECONDS - start_time))
printf 'Elapsed time: %dh:%dm:%ds\n' \
    $((elapsed / 3600)) \
    $((elapsed % 3600 / 60)) \
    $((elapsed % 60))
printf 'End: %s\n' "$(date)"

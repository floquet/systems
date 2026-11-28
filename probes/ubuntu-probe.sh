#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./ubuntu-probe.sh
# arguments: none
# flags: none
# purpose: identify the Ubuntu operating environment
# requirements: standard Ubuntu utilities
# privileges: none

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

new_step "Linux distribution"
probe cat /etc/os-release

new_step "Kernel and architecture"
probe uname -a
probe dpkg --print-architecture

new_step "Virtualization environment"
probe systemd-detect-virt

new_step "System uptime"
probe uptime

new_step "Shell and package manager"
probe bash --version
probe apt --version

new_step "Summary"
elapsed=$((SECONDS - start_time))
printf 'Elapsed time: %dh:%dm:%ds\n' \
    $((elapsed / 3600)) \
    $((elapsed % 3600 / 60)) \
    $((elapsed % 60))
printf 'End: %s\n' "$(date)"

#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# Invocation: source spack-activate-env-dantopa.sh
# Purpose: Activate the persistent development environment.
# Source this script in each new development terminal.

printf '\n$ source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh\n'
source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh

printf '\n$ spack env activate env-dantopa\n'
if spack env activate env-dantopa; then
    printf '\n$ spack env status\n'
    spack env status

    printf '\n$ spack find -l pagmo2\n'
    spack find -l pagmo2
else
    printf 'Activation failed: env-dantopa is unavailable.\n'
fi

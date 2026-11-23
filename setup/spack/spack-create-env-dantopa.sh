#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# Invocation: ./spack-create-env-dantopa.sh
# Purpose: Create and configure the persistent development environment.
# Run only for initial setup or intentional reconfiguration.

printf '\n$ source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh\n'
source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh

printf '\n$ spack env list\n'
spack env list

printf '\n$ spack env create env-dantopa\n'
if ! spack env list | grep -Eq '(^|[[:space:]])env-dantopa([[:space:]]|$)'; then
    spack env create env-dantopa
else
    printf 'Environment env-dantopa already exists; skipping creation.\n'
fi

printf '\n$ spack env activate env-dantopa\n'
spack env activate env-dantopa || exit 1

printf '\n$ spack add pagmo2@2.20.0\n'
spack add pagmo2@2.20.0

printf '\n$ spack concretize\n'
spack concretize

printf '\n$ spack find -c\n'
spack find -c

printf '\n$ spack repo list\n'
spack repo list

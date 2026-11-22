#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# Invocation: ./spack-create-env-dantopa.sh
# Purpose: Create the persistent Spack development environment.

printf '\n$ source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh\n'
source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh

printf '\n$ spack env create env-dantopa\n'
spack env create env-dantopa

printf '\n$ spack env list\n'
spack env list

printf '\n$ spack repo list\n'
spack repo list

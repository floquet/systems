#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# Invocation: source ./spack-activate-env-dantopa.sh
# Purpose: Initialize Spack and activate the development environment.
# Must be sourced to modify the current shell.

printf '\n$ source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh\n'
source /home/dantopa/spacktivity/genesis/share/spack/setup-env.sh

printf '\n$ spack env activate env-dantopa\n'
spack env activate env-dantopa

printf '\n$ spack env status\n'
spack env status

printf '\n$ spack find -l pagmo2\n'
spack find -l pagmo2

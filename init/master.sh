#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

recorderStart=$SECONDS

# Paths must be established before any dependent init scripts.
source "${pInit}/paths.sh"

source "${pInit}/alias.sh"
source "${pInit}/arXiver.sh"
source "${pInit}/env.sh"
source "${pInit}/fortran.sh"
source "${pInit}/fortran-stack.sh"
source "${pInit}/git.sh"
source "${pInit}/go.sh"
source "${pInit}/grep.sh"
source "${pInit}/ptyxis.sh"
source "${pInit}/snapshotter.sh" &
source "${pInit}/spack-bootstrap.sh"
source "${pInit}/ssh.sh"
source "${pInit}/vim.sh"
source "${pInit}/recorder.sh"

# commit changes to builds repo (git.sh)
commit-builds

echo "time used: $((SECONDS - recorderStart)) seconds"


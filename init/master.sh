#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

recorderStart=$SECONDS

# turn of shell bell in WSL
bind "set bell-style none"

# Paths must be established before any dependent init scripts.
source "${pInit}/paths.sh"

source "${pInit}/alias.sh"
source "${pInit}/arXiver.sh"
source "${pInit}/env.sh"
source "${pInit}/files.sh"
source "${pInit}/fortran.sh"
source "${pInit}/fortran-stack.sh"
source "${pInit}/git.sh"
source "${pInit}/go.sh"
source "${pInit}/grep.sh"
source "${pInit}/ptyxis.sh"
source "${pInit}/snapshotter.sh" 
source "${pInit}/spack-bootstrap.sh"
source "${pInit}/ssh.sh"
source "${pInit}/vim.sh"
source "${pInit}/recorder.sh"

# commit changes to builds repo (git.sh)
commit-builds

#changes in systems repo
# Commit changes in systems repository
git -C "${pSystems}" add -A
git -C "${pSystems}" diff --cached --quiet ||
    git -C "${pSystems}" commit \
        -m "master.sh by $USER on $(hostname) $(date '+%Y-%m-%d %H:%M:%S')"

echo "time used: $((SECONDS - recorderStart)) seconds"


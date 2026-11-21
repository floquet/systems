#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

recorderStart=$SECONDS

# Disable shell bell
bind "set bell-style none"

# Establish paths before dependent initialization scripts
source "${pInit}/paths.sh"

# Initialize shell environment
source "${pInit}/alias.sh"
source "${pInit}/arXiver.sh"
source "${pInit}/env.sh"
source "${pInit}/files.sh"
source "${pInit}/fortran.sh"
source "${pInit}/fortran-stack.sh"
source "${pInit}/git.sh"
source "${pInit}/go.sh"
source "${pInit}/grep.sh"
source "${pInit}/latex.sh"
source "${pInit}/ptyxis.sh"
source "${pInit}/spack-bootstrap.sh"
source "${pInit}/screenshot.sh"
source "${pInit}/ssh.sh"
source "${pInit}/vim.sh"
source "${pInit}/recorder.sh"

# Serialize snapshots and Git operations across shell sessions
(
    flock -x 200 || exit 1

    # Update machine-specific snapshots
    source "${pInit}/snapshotter.sh"

    # Commit changes in builds repository
    commit-builds

    # Commit changes in systems repository
    git -C "${pSystems}" add -A
    if ! git -C "${pSystems}" diff --cached --quiet; then
        git -C "${pSystems}" commit \
            -m "master.sh by ${USER} on $(hostname) $(date '+%Y-%m-%d %H:%M:%S')"
    fi

) 200>"${HOME}/.git-init.lock"

# use miltary time
alias date="date '+%a %b %d %H:%M:%S %Z %Y'"

# Report initialization time
echo "time used: $((SECONDS - recorderStart)) seconds"


# High-contrast directory color (bold bright cyan instead of unreadable dark blue)
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b)"
    export LS_COLORS="${LS_COLORS/di=01;34:/di=01;93:}"
fi

# Swap unreadable dark blue path (01;34m / 1;34m) in PS1 for bold bright cyan (01;96m)
PS1="${PS1//01;34m/01;96m}"
PS1="${PS1//1;34m/01;96m}"

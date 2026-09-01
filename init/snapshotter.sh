#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

repo="${pGithub}/systems"
dest="${repo}/snapshots/${HOSTNAME}"

mkdir -p "${dest}"

# Key dotfiles
rsync -a -- "${HOME}/.bashrc"         "${dest}/"
rsync -a -- "${HOME}/.vimrc"          "${dest}/"
rsync -a -- "${HOME}/.gitconfig"      "${dest}/"
rsync -a -- "${HOME}/.${HOSTNAME}.sh" "${dest}/"

# Entire machine-specific working directory
rsync -a \
    "${HOME}/${HOSTNAME}/" \
    "${dest}/${HOSTNAME}/"



#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

: "${pSystems:?pSystems is not set}"

pSnapshot="${pSystems}/snapshots/${HOSTNAME}"
mkdir -p "${pSnapshot}"

cp -- "$HOME/.vimrc"          "${pSnapshot}/"
cp -- "$HOME/.gitconfig"      "${pSnapshot}/"
# cp -a -- "$HOME/.config/nvim" "${pSnapshot}/"
cp -- "$HOME/.${HOSTNAME}.sh" "${pSnapshot}/"


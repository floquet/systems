#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

: "${pHere}:?pHere is not set in master.sh}"

dest="${pHere}/snapshots/${HOSTNAME}"
mkdir -p "${dest}"

cp    -- "$HOME/.vimrc"          "$dest/"
cp    -- "$HOME/.gitconfig"      "$dest/"
#cp -a -- "$HOME/.config/nvim"    "$dest/"
cp    -- "$HOME/.$(hostname).sh" "$dest/"


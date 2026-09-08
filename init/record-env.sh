#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

date > "${pSnapshot}/env.txt"
echo "env" >> "${pSnapshot}/env.txt"
env >> "${pSnapshot}/env.txt"


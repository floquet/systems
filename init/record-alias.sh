#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"
	
# capture machine settings
date > "${pSnapshot}/alias.txt"
echo "alias" >> "${pSnapshot}/alias.txt"
alias >> "${pSnapshot}/alias.txt"


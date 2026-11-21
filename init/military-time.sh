#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# Default to 24-hour (military) time.
# Preserve explicit date formats and other command-line arguments.

unalias date 2>/dev/null || true

date() {
    if (( $# == 0 )); then
        command date '+%a %b %d %H:%M:%S %Z %Y'
    else
        command date "$@"
    fi
    export -f date
}

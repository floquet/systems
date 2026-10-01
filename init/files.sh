#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# File helpers.
# Invocation: open-file FILE
# Opens FILE with its default application, without completion notifications.

function open-file() {
    if (( $# != 1 )); then
        printf 'Usage: open-file FILE\n' >&2
        return 1
    fi

    xdg-open "$1" >/dev/null 2>&1 &
    disown
}


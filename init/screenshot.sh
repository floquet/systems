#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# GNOME screenshot management for Beamer presentations.
# Set land to the active presentation's graphics directory.

shotmove() {
    local src name

    [[ -n "${land:-}" ]] || {
        echo "shotmove: land is not set" >&2
        return 1
    }

    name="${1:?Usage: shotmove NAME}"

    src=$(find "$HOME/Pictures/Screenshots" -maxdepth 1 \
        -type f -name 'Screenshot From *.png' \
        -printf '%T@ %p\n' |
        sort -nr | head -1 | cut -d' ' -f2-)

    [[ -n "$src" ]] || {
        echo "shotmove: no screenshot found" >&2
        return 1
    }

    mkdir -p "$land"
    mv -i -- "$src" "$land/${name%.png}.png"
}

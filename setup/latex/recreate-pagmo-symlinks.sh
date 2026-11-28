#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# Install in: systems/setup/latex/recreate-pagmo-symlinks.sh
# Invocation (from any directory, with systems/bin on PATH):
# PAGMO_SRC=/home/dantopa/repos-isomer/gitlab/pagmo/src/zdt \
# PAGMO_PRES=/home/dantopa/repos-isomer/github/framework/pres/pagmo \
# recreate-pagmo-symlinks.sh

PAGMO_SRC="${PAGMO_SRC:?Set PAGMO_SRC to the ZDT source directory}"
PAGMO_PRES="${PAGMO_PRES:?Set PAGMO_PRES to the presentation directory}"

[[ -d "$PAGMO_SRC" ]] || { printf 'Missing source directory: %s\n' "$PAGMO_SRC" >&2; exit 1; }
[[ -d "$PAGMO_PRES" ]] || { printf 'Missing presentation directory: %s\n' "$PAGMO_PRES" >&2; exit 1; }

printf 'Source: %s\nPresentation: %s\n' "$PAGMO_SRC" "$PAGMO_PRES"
for kind in dat cpp; do
    if [[ "$kind" == dat ]]; then destination="$PAGMO_PRES/local/data"; else destination="$PAGMO_PRES/local/codes"; fi
    printf '\nmkdir -p "%s"\n' "$destination"
    mkdir -p "$destination"
    count=0
    for source in "$PAGMO_SRC"/pagmo-zdt-*."$kind"; do
        [[ -f "$source" ]] || continue
        target="$destination/$(basename "$source")"
        if [[ -e "$target" && ! -L "$target" ]]; then
            printf 'ERROR: refusing to overwrite regular file: %s\n' "$target" >&2
            exit 1
        fi
        printf 'ln -sfn "%s" "%s"\n' "$source" "$target"
        ln -sfn "$source" "$target"
        printf 'readlink "%s"\n' "$target"
        readlink "$target"
        if [[ -L "$target" && -f "$target" && "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
            printf 'VERIFIED: %s\n' "$target"
        else
            printf 'ERROR: symlink verification failed: %s\n' "$target" >&2
            exit 1
        fi
        count=$((count + 1))
    done
    printf 'Verified %d .%s links\n' "$count" "$kind"
done
printf '\nAll created symlinks verified.\n'

#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# ptyxis.sh

_pt_profile_uuid()
{
    local target_label="$1"
    local raw_uuids uid label
    raw_uuids=$(gsettings get org.gnome.Ptyxis profile-uuids 2>/dev/null | tr -d "[]',")
    for uid in $raw_uuids; do
        label=$(gsettings get "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${uid}/" label 2>/dev/null | tr -d "'")
        if [[ "$label" == "$target_label" ]]; then
            printf "%s" "$uid"
            return 0
        fi
    done
    return 1
}

pt()
{
    local key="$1"
    local mode="${2:-tab}"

    local title
    local path="$HOME"
    local command=""
    local profile_label=""

    case "$key" in

        builds)
            title="Builds"
            path="$HOME/repos-$(hostname)/github/builds"
            ;;

        framework)
            title="Framework"
            path="$HOME/repos-$(hostname)/gitlab/framework"
            ;;

        github)
            title="GitHub"
            path="$HOME/repos-$(hostname)/github"
            ;;

        gitlab)
            title="GitLab"
            path="$HOME/repos-$(hostname)/gitlab"
            ;;

        wolfram|Wolfram)
            title="Wolfram"
            path="$HOME"
            command="/usr/local/Wolfram/Wolfram/15.0/Executables/wolfram"
            ;;

        jop)
            title="JOP"
            path="$HOME/repos-$(hostname)/github/jop"
            ;;

        f|fortran)
            title="Fortran"
            path="$HOME/repos-$(hostname)/github/f"
            ;;

        isotope)
            title="🔴 ISOTOPE"
            profile_label="isotope (Crimson)"
            command="ssh dantopa@isotope.local"
            ;;

        isotone)
            title="🔵 ISOTONE"
            profile_label="isotone (Navy)"
            command="ssh dantopa@isotone.local"
            ;;

        host3)
            title="🟢 HOST3"
            profile_label="host3 (Forest)"
            command="ssh dantopa@host3.local"
            ;;

        host4)
            title="🟣 HOST4"
            profile_label="host4 (Plum)"
            command="ssh dantopa@host4.local"
            ;;

        *)
            echo "usage: pt {builds|framework|github|gitlab|jop|wolfram|f|isotope|isotone|host3|host4} [w]"
            return 1
            ;;

    esac

    if [[ ! -d "$path" ]]; then
        echo "pt: directory does not exist: $path"
        return 1
    fi

    local profile_uuid=""
    if [[ -n "$profile_label" ]]; then
        profile_uuid=$(_pt_profile_uuid "$profile_label")
    fi

    local -a args=(
        --title="$title"
        --working-directory="$path"
    )

    if [[ -n "$profile_uuid" ]]; then
        [[ "$mode" == "w" ]] && args+=(--new-window)
        args+=(--tab-with-profile="$profile_uuid")
    elif [[ "$mode" == "w" ]]; then
        args+=(--new-window)
    else
        args+=(--tab)
    fi

    if [[ -n "$command" ]]; then
        ptyxis "${args[@]}" -- $command
    else
        ptyxis "${args[@]}"
    fi
}

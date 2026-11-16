#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# ptyxis.sh

pt()
{
    local key="$1"
    local mode="${2:-tab}"

    local title
    local path="$HOME"
    local command=""
    local profile=""

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
            profile="e0b4e9a7-7630-4640-889f-9857523e2f8a"
            command="ssh dantopa@isotope.local"
            ;;

        isotone)
            title="🔵 ISOTONE"
            profile="079beb87-5a12-43b1-946d-42f91ad90113"
            command="ssh dantopa@isotone.local"
            ;;

        host3)
            title="🟢 HOST3"
            profile="ffc65a6e-b975-412e-8785-02cb6f1f9f4d"
            command="ssh dantopa@host3.local"
            ;;

        host4)
            title="🟣 HOST4"
            profile="9709a692-8633-41fa-aba0-2f15d4521642"
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

    local -a args=(
        --title="$title"
        --working-directory="$path"
    )

    if [[ "$mode" == "w" ]]; then
        args+=(--new-window)
    else
        args+=(--tab)
    fi

    if [[ -n "$profile" ]]; then
        args+=(--profile="$profile")
    fi

    if [[ -n "$command" ]]; then
        ptyxis "${args[@]}" -- $command
    else
        ptyxis "${args[@]}"
    fi
}

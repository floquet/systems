#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./apt-refresh.sh [flags]
# invocation: apt-refresh-iaakov [flags]
# arguments: none
# flags:
#   --help        Display invocation instructions
#   --update      Refresh APT metadata
#   --upgrade     Upgrade installed packages
#   --autoremove  Remove unnecessary dependencies
#   --all         Execute all three operations
# default: display help
# environment: APT_RESULTS_DIR overrides results directory

start_time=${SECONDS}
counter=0
machine=$(hostname -s)
script_path=$(readlink -f "${BASH_SOURCE[0]}")
results_dir="${APT_RESULTS_DIR:-${HOME}/.info/${machine}/apt/iaakov/refresh}"

update=false
upgrade=false
autoremove=false

new_step()
{
    counter=$((counter + 1))
    printf '\nStep %d: %s\n' "${counter}" "$1"
}

enunciate()
{
    printf '\n%s' '$'
    printf ' %q' "$@"
    printf '\n\n'
}

usage()
{
    cat <<USAGE
Invocation:
  ./apt-refresh.sh [flags]
  apt-refresh-iaakov [flags]

Flags:
  --help        Display invocation instructions
  --update      Refresh APT metadata
  --upgrade     Upgrade installed packages
  --autoremove  Remove unnecessary dependencies
  --all         Execute all three operations

No arguments: display help.
USAGE
}

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --update)
            update=true
            ;;
        --upgrade)
            upgrade=true
            ;;
        --autoremove)
            autoremove=true
            ;;
        --all)
            update=true
            upgrade=true
            autoremove=true
            ;;
        *)
            printf 'ERROR: Unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
    shift
done

new_step "Settings"

run_id=$(date +%Y%m%d-%H%M%S)-$$
run_dir="${results_dir}/${run_id}"
status_file="${run_dir}/status.tsv"

printf '  machine: %s\n' "${machine}"
printf '  script:  %s\n' "${script_path}"
printf '  results: %s\n' "${run_dir}"

enunciate mkdir -p "${run_dir}"
mkdir -p "${run_dir}" || exit 1

printf 'operation\treturn_code\tlog_return_code\n' \
    > "${status_file}" || exit 1

run_logged()
{
    local operation="$1"
    shift
    local logfile="${run_dir}/${operation}.txt"
    local -a status

    {
        date
        enunciate "$@"
    } | tee "${logfile}" || return 1

    "$@" 2>&1 | tee -a "${logfile}"
    status=("${PIPESTATUS[@]}")

    printf '%s\t%d\t%d\n' \
        "${operation}" "${status[0]}" "${status[1]}" \
        >> "${status_file}" || return 1

    if [[ ${status[0]} -eq 0 && ${status[1]} -eq 0 ]]; then
        printf '\nPASS: %s\n' "${operation}"
        return 0
    else
        printf '\nFAIL: %s (command rc=%d, log rc=%d)\n' \
            "${operation}" "${status[0]}" "${status[1]}"
        return 1
    fi
}

result=0

if ${update}; then
    new_step "Refresh APT metadata"
    run_logged update sudo apt-get update || result=1
fi

if [[ ${result} -eq 0 ]] && ${upgrade}; then
    new_step "Upgrade installed packages"
    run_logged upgrade sudo apt-get upgrade -y || result=1
fi

if [[ ${result} -eq 0 ]] && ${autoremove}; then
    new_step "Remove unnecessary dependencies"
    run_logged autoremove sudo apt-get autoremove || result=1
fi

new_step "Summary"

enunciate cat "${status_file}"
cat "${status_file}"

elapsed=$((SECONDS - start_time))
printf '\nResults: %s\n' "${run_dir}"
printf 'Elapsed time: %dh:%dm:%ds\n' \
    $((elapsed / 3600)) \
    $((elapsed % 3600 / 60)) \
    $((elapsed % 60))

if [[ ${result} -eq 0 ]]; then
    printf 'Overall result: PASS\n'
else
    printf 'Overall result: FAIL\n'
fi

printf 'End: %s\n' "$(date)"
exit "${result}"

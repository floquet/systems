#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./apt-genesis.sh [flags] [groups ...]
# invocation: apt-genesis-iaakov [flags] [groups ...]
# arguments: package group names, without .txt extension
# flags:
#   --help       Display invocation instructions
#   --list       List available package groups
#   --dry-run    Simulate installation
#   --all        Select all package groups
#   --update     Refresh APT metadata
# default: display help; install nothing
# environment: APT_RESULTS_DIR overrides results directory

start_time=${SECONDS}
counter=0
machine=$(hostname -s)
script_path=$(readlink -f "${BASH_SOURCE[0]}")
script_dir=$(dirname "${script_path}")
package_dir="${script_dir}/packages"
results_dir="${APT_RESULTS_DIR:-${HOME}/.info/${machine}/apt/iaakov}"

dry_run=false
select_all=false
update=false
groups=()
manifests=()
packages=()

# ----------------------------------------------------------------------
# Enunciation
# ----------------------------------------------------------------------

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

fail()
{
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

# ----------------------------------------------------------------------
# Invocation
# ----------------------------------------------------------------------

usage()
{
    cat <<USAGE
Invocation:
  ./apt-genesis.sh [flags] [groups ...]

Flags:
  --help       Display this message
  --list       List available package groups
  --dry-run    Simulate installation
  --all        Select all package groups
  --update     Refresh APT metadata

Examples:
  ./apt-genesis.sh --list
  ./apt-genesis.sh --dry-run python
  ./apt-genesis.sh --dry-run --all
  ./apt-genesis.sh python tools-database
  ./apt-genesis.sh --update
  ./apt-genesis.sh --update python
  ./apt-genesis.sh --all

No arguments: display help.
No automatic upgrade or autoremove.
USAGE
}

list_groups()
{
    local manifest group count
    printf '\nAvailable package groups:\n\n'
    printf '  %-24s %8s\n' "GROUP" "PACKAGES"
    for manifest in "${package_dir}"/*.txt; do
        [[ -f "${manifest}" ]] || continue
        group=$(basename "${manifest}" .txt)
        count=$(grep -Ec '^[[:space:]]*[^#[:space:]]' "${manifest}")
        printf '  %-24s %8d\n' "${group}" "${count}"
    done
}

# ----------------------------------------------------------------------
# Parse arguments
# ----------------------------------------------------------------------

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
        --list)
            list_groups
            exit 0
            ;;
        --dry-run)
            dry_run=true
            ;;
        --all)
            select_all=true
            ;;
        --update)
            update=true
            ;;
        -*)
            fail "Unknown flag: $1"
            ;;
        *)
            groups+=("$1")
            ;;
    esac
    shift
done

if ${dry_run} && ${update}; then
    fail "--dry-run and --update cannot be combined"
fi

if ${select_all} && [[ ${#groups[@]} -gt 0 ]]; then
    fail "Use --all or named groups, not both"
fi

# ----------------------------------------------------------------------
# Resolve manifests
# ----------------------------------------------------------------------

new_step "Resolve package manifests"

if ${select_all}; then
    for manifest in "${package_dir}"/*.txt; do
        [[ -f "${manifest}" ]] || continue
        groups+=("$(basename "${manifest}" .txt)")
    done
fi

for group in "${groups[@]}"; do
    [[ "${group}" =~ ^[a-zA-Z0-9_-]+$ ]] ||
        fail "Invalid package group: ${group}"
    manifest="${package_dir}/${group}.txt"
    [[ -f "${manifest}" ]] ||
        fail "Manifest not found: ${manifest}"
    manifests+=("${manifest}")
    printf '  %s\n' "${manifest}"
done

# ----------------------------------------------------------------------
# Assemble unique package list
# ----------------------------------------------------------------------

if [[ ${#manifests[@]} -gt 0 ]]; then
    mapfile -t packages < <(
        awk '
            {
                sub(/^[[:space:]]+/, "")
                sub(/[[:space:]]+$/, "")
            }
            NF && !/^#/ { print }
        ' "${manifests[@]}" | sort -u
    )
    [[ ${#packages[@]} -gt 0 ]] ||
        fail "No packages found in selected manifests"
fi

if [[ ${#packages[@]} -eq 0 ]] && ! ${update}; then
    fail "No package groups selected"
fi

# ----------------------------------------------------------------------
# Provenance and results
# ----------------------------------------------------------------------

new_step "Settings"

run_id=$(date +%Y%m%d-%H%M%S)-$$
run_dir="${results_dir}/${run_id}"
mkdir -p "${run_dir}" || fail "Cannot create ${run_dir}"
status_file="${run_dir}/status.tsv"

printf '  machine:         %s\n' "${machine}"
printf '  script:          %s\n' "${script_path}"
printf '  package_dir:     %s\n' "${package_dir}"
printf '  results:         %s\n' "${run_dir}"
printf '  package groups:  %d\n' "${#groups[@]}"
printf '  unique packages: %d\n' "${#packages[@]}"
printf '  dry-run:         %s\n' "${dry_run}"

printf 'operation\treturn_code\tlog_return_code\n' > "${status_file}"
printf '%s\n' "${groups[@]}" > "${run_dir}/groups.txt"
printf '%s\n' "${packages[@]}" > "${run_dir}/packages.txt"

# ----------------------------------------------------------------------
# Execute and record a command
# ----------------------------------------------------------------------

run_logged()
{
    local operation="$1"
    shift
    local logfile="${run_dir}/${operation}.txt"
    local -a status

    {
        date
        enunciate "$@"
    } | tee "${logfile}"

    "$@" 2>&1 | tee -a "${logfile}"
    status=("${PIPESTATUS[@]}")

    printf '%s\t%d\t%d\n' \
        "${operation}" "${status[0]}" "${status[1]}" \
        >> "${status_file}"

    if [[ ${status[0]} -eq 0 && ${status[1]} -eq 0 ]]; then
        printf '\nPASS: %s\n' "${operation}"
        return 0
    else
        printf '\nFAIL: %s (command rc=%d, log rc=%d)\n' \
            "${operation}" "${status[0]}" "${status[1]}"
        return 1
    fi
}

# ----------------------------------------------------------------------
# APT operations
# ----------------------------------------------------------------------

result=0

if ${update}; then
    new_step "Refresh APT metadata"
    run_logged update sudo apt-get update || result=1
fi

if [[ ${result} -eq 0 && ${#packages[@]} -gt 0 ]]; then
    if ${dry_run}; then
        new_step "Simulate package installation"
        run_logged simulation apt-get -s install "${packages[@]}" ||
            result=1
    else
        new_step "Install packages"
        run_logged install sudo apt-get install -y "${packages[@]}" ||
            result=1
    fi
fi

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------

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

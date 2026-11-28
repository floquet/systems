#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# invocation: ./setup-bin-links.sh
# arguments: none
# flags: none
# purpose: register Iaakov APT utilities in systems/bin

script_path=$(readlink -f "${BASH_SOURCE[0]}")
script_dir=$(dirname "${script_path}")
systems_dir=$(cd "${script_dir}/../../.." && pwd)
bin_dir="${systems_dir}/bin"

printf '\nSettings:\n'
printf '  script_dir:  %s\n' "${script_dir}"
printf '  systems_dir: %s\n' "${systems_dir}"
printf '  bin_dir:     %s\n' "${bin_dir}"

enunciate()
{
    printf '\n%s' '$'
    printf ' %q' "$@"
    printf '\n\n'
}

create_link()
{
    local source="$1"
    local target="$2"

    if [[ ! -x "${source}" ]]; then
        printf 'ERROR: Source is not executable: %s\n' "${source}"
        return 1
    fi

    if [[ -L "${target}" && -e "${target}" &&
          "${source}" -ef "${target}" ]]; then
        printf '\nEXISTS: %s\n' "${target}"
        return 0
    fi

    if [[ -e "${target}" || -L "${target}" ]]; then
        printf 'ERROR: Refusing to overwrite %s\n' "${target}"
        return 1
    fi

    enunciate ln -sr "${source}" "${target}"
    ln -sr "${source}" "${target}"
}

result=0

create_link "${script_dir}/apt-genesis.sh" \
    "${bin_dir}/apt-genesis-iaakov" || result=1

create_link "${script_dir}/apt-refresh.sh" \
    "${bin_dir}/apt-refresh-iaakov" || result=1

enunciate ls -l "${bin_dir}/apt-genesis-iaakov" \
    "${bin_dir}/apt-refresh-iaakov"

ls -l "${bin_dir}/apt-genesis-iaakov" \
    "${bin_dir}/apt-refresh-iaakov" || result=1

create_link "${script_dir}/../probes/probe-hardware.sh" \
    "${bin_dir}/probe-hardware-iaakov" || result=1

create_link "${script_dir}/../probes/ubuntu-probe.sh" \
    "${bin_dir}/ubuntu-probe-iaakov" || result=1

create_link "${script_dir}/../probes/probe-software.sh" \
    "${bin_dir}/probe-software-iaakov" || result=1

exit "${result}"

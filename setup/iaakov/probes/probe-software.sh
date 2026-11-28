#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold 2>/dev/null)${BASH_SOURCE[0]}$(tput sgr0 2>/dev/null)"

# invocation: ./probe-software.sh
# arguments: none
# flags: none
# purpose: inventory installed software and compare with APT manifests
# privileges: none
# environment: SOFTWARE_RESULTS_DIR overrides output root

machine=$(hostname -s)
script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
package_dir="${script_dir}/../apt/packages"
results_root="${SOFTWARE_RESULTS_DIR:-${HOME}/.info/${machine}/software}"
run_dir="${results_root}/$(date +%Y%m%d-%H%M%S)-$$"
start_time=${SECONDS}
counter=0
mkdir -p "${run_dir}" || exit 1
printf 'probe\treturn_code\n' > "${run_dir}/status.tsv" || exit 1

capture()
{
    local name="$1" rc
    shift
    counter=$((counter + 1))
    printf '\nStep %d: %s\n' "${counter}" "${name}"
    printf '%s' '$'
    printf ' %q' "$@"
    printf '\n'
    "$@" > "${run_dir}/${name}.txt" 2>&1
    rc=$?
    printf '%s\t%d\n' "${name}" "${rc}" >> "${run_dir}/status.tsv"
    printf '  rc=%d; lines=%s\n' "${rc}" "$(wc -l < "${run_dir}/${name}.txt")"
}

optional()
{
    local name="$1"
    shift
    if command -v "$1" >/dev/null 2>&1; then
        capture "${name}" "$@"
    else
        printf '\nSKIP: %s (%s unavailable)\n' "${name}" "$1"
        printf '%s\tSKIP\n' "${name}" >> "${run_dir}/status.tsv"
    fi
}

inventory_path()
{
    printf '%s\n' "${PATH}" | tr ':' '\n'
}

inventory_commands()
{
    local cmd
    for cmd in gcc g++ gfortran clang clang++ flang ifx ifort icx \
        mpicc mpicxx mpifort mpirun caf cafrun cmake make ninja meson \
        python python3 pip pip3 ipython3 jupyter jupyter-lab uv pipx conda mamba \
        julia R Rscript rustc cargo go java javac node npm \
        sqlite3 sqlitebrowser psql postgres duckdb mysql mariadb \
        git git-lfs gh spack docker podman apptainer singularity \
        pdflatex lualatex latexmk wolfram wolframscript matlab \
        vim nvim rg fd fdfind bat batcat pv parallel jq; do
        printf '\n%s\n' "${cmd}"
        type -a "${cmd}" 2>/dev/null || printf 'NOT FOUND\n'
    done
}

inventory_local()
{
    local dir
    for dir in /opt /usr/local/bin /usr/local/sbin /usr/local/lib \
        "${HOME}/.local/bin" "${HOME}/bin" "${HOME}/.cargo/bin"; do
        printf '\n%s\n' "${dir}"
        if [[ -d "${dir}" ]]; then
            ls -la -- "${dir}"
        else
            printf 'NOT FOUND\n'
        fi
    done
}

inventory_manifests()
{
    local manifest
    for manifest in "${package_dir}"/*.txt; do
        [[ -f "${manifest}" ]] || continue
        awk '{sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "")} NF && !/^#/ {print}' "${manifest}"
    done | LC_ALL=C sort -u
}

compare_apt()
{
    local package status version
    while IFS= read -r package; do
        [[ -n "${package}" ]] || continue
        if status=$(dpkg-query -W -f='${db:Status-Status}\t${Version}' "${package}" 2>/dev/null) && [[ "${status}" == installed$'\t'* ]]; then
            version=${status#*$'\t'}
            printf '%s\t%s\n' "${package}" "${version}"
        else
            printf '%s\tNOT INSTALLED\n' "${package}"
        fi
    done < "${run_dir}/apt-declared.txt"
}

manual_versions()
{
    local package
    while IFS= read -r package; do
        dpkg-query -W -f='${binary:Package}\t${Version}\n' "${package}" 2>/dev/null || printf '%s\tUNKNOWN\n' "${package}"
    done < "${run_dir}/apt-manual.txt"
}

python_inventory()
{
    "$1" -c 'import sys, importlib.metadata as m; print("Executable:",sys.executable); print("Version:",sys.version); print("Prefix:",sys.prefix); print("Base prefix:",sys.base_prefix); print("\nDistributions:"); print("\n".join(sorted((str(d.metadata.get("Name", "UNKNOWN"))+"=="+str(d.version or "UNKNOWN") for d in m.distributions()),key=str.casefold)))'
}

printf '\nResults: %s\n' "${run_dir}"
capture hostname hostname
capture ubuntu cat /etc/os-release
capture kernel uname -a
capture path inventory_path
capture commands inventory_commands
capture local-installations inventory_local
capture apt-manual apt-mark showmanual
capture apt-manual-versions manual_versions
capture dpkg-installed dpkg-query -W -f='${db:Status-Status}\t${binary:Package}\t${Version}\n'
if [[ -d "${package_dir}" ]]; then
    capture apt-declared inventory_manifests
    capture apt-declared-status compare_apt
    capture apt-manual-not-declared bash -c 'comm -23 <(LC_ALL=C sort -u "$1") <(LC_ALL=C sort -u "$2")' _ "${run_dir}/apt-manual.txt" "${run_dir}/apt-declared.txt"
else
    printf '\nSKIP: APT manifest comparison (directory unavailable)\n'
fi
optional spack-version spack --version
optional spack-installed spack find -lv
optional spack-explicit spack find --explicit
optional spack-environments spack env list
optional spack-compilers spack compiler list
for interpreter in python3 python; do
    if command -v "${interpreter}" >/dev/null 2>&1; then
        capture "${interpreter}-distributions" python_inventory "${interpreter}"
    fi
done
if [[ -x /usr/bin/python3 ]]; then
    capture system-python3-distributions python_inventory /usr/bin/python3
fi
optional conda-environments conda env list
optional conda-packages conda list
optional pipx-packages pipx list
optional uv-tools uv tool list
optional snap-packages snap list
optional flatpak-packages flatpak list
optional cargo-packages cargo install --list
optional npm-global npm list -g --depth=0
optional gcc-version gcc --version
optional gfortran-version gfortran --version
optional clang-version clang --version
optional mpi-version mpirun --version
optional julia-version julia --version
optional r-version R --version
optional sqlite-version sqlite3 --version
optional postgres-version psql --version
optional duckdb-version duckdb --version
printf '\nResults: %s\n' "${run_dir}"
printf 'Elapsed time: %ds\n' "$((SECONDS-start_time))"
printf 'Review status.tsv and inventory files before sharing.\n'
printf 'End: %s\n' "$(date)"

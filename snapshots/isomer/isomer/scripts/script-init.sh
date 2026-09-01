export big_spack_mirror="/mnt/T7-Shield/spack_mirror"

alias lss='ls -alh'

export big_spack_mirror="/mnt/T7-Shield/spack_mirror"

feed_spack_mirror()
{
    echo "rsync from SPACK_ROOT = ${SPACK_ROOT}"
    echo "rsync to   mirror     = ${big_spack_mirror}"

    if [[ -z "${SPACK_ROOT}" ]]; then
        echo "ERROR: SPACK_ROOT is not defined."
        return 1
    fi

    mkdir -p "${big_spack_mirror}/_source-cache/archive"

   echo "rsync -vauh ${SPACK_ROOT}/var/spack/cache/_source-cache/archive/. ${big_spack_mirror}/_source-cache/archive/."

    rsync -vauh \
        "${SPACK_ROOT}/var/spack/cache/_source-cache/archive/." \
        "${big_spack_mirror}/_source-cache/archive/."
}


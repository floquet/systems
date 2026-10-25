#!/usr/bin/env bash

# Create a Beamer presentation and enter its main directory.
create-pres() {
    local project="${1:?Usage: create-pres PROJECT_NAME}"

    "${pFramework}/global/constructors/v2/create-pres.sh" \
        "$project" || return

    cd "${pFramework}/pres/${project}/main" || return
}


#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# Forge roots already established by ~/.${HOSTNAME}.sh
: "${pRepos:?pRepos is not set}"
: "${pGithub:?pGithub is not set}"
: "${pGitlab:?pGitlab is not set}"
: "${pSystems:?pSystems is not set}"
: "${pInit:?pInit is not set}"

# GitHub repositories
export pBuilds="${pGithub}/builds"
export pFramework="${pGithub}/framework"
export pNotes="${pGithub}/notes"
export pSpacklandia="${pGithub}/spacklandia"
export pShellLibrary="${pGithub}/shell-library"

# Systems repository
export pSnapshots="${pSystems}/snapshots"
export pSnapshot="${pSnapshots}/${HOSTNAME}"
dir_systems_bin="${pSystems}/bin"

case ":${PATH}:" in
    *":${dir_systems_bin}:"*) ;;
    *) export PATH="${dir_systems_bin}:${PATH}" ;;
esac

# Build/system paths
export pUbuntu="${pBuilds}/linux/ubuntu"
export pScripts="${pUbuntu}/scripts"
export pInfo="${pUbuntu}/info"

export pHyperion="${pGitlab}/hyperion"
export pZebra="${pFramework}/pres/zebra"


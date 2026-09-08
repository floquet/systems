#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# bootstrap: locate the shared systems repository
export pRepos="${HOME}/repos-${HOSTNAME}"
export pGithub="${pRepos}/github"
export pGitlab="${pRepos}/gitlab"

export pSystems="${pGithub}/systems"
export pInit="${pSystems}/init"

# shared shell environment
source "${pInit}/master.sh"

# machine-specific configuration
# source "${pInit}/spack-tethys.sh"


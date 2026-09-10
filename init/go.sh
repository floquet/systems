#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# && ensures pwd runs only when cd is successful
alias goRepos='cd "${pRepos}" && pwd'
alias goGithub='cd "${pGithub}" && pwd'
alias goBuilds='cd "${pBuilds}" && pwd'
alias goUbuntu='cd "${pUbuntu}" && pwd'
alias goScripts='cd "${pScripts}" && pwd'

# GitHub repositories
alias goF='cd "${pGithub}/f" && pwd'
alias goJop='cd "${pGithub}/jop" && pwd'
alias goNotes='cd "${pGithub}/notes" && pwd'
alias goShellLibrary='cd "${pGithub}/shell-library" && pwd'
alias goSpacklandia='cd "${pGithub}/spacklandia" && pwd'
alias goEcho='cd "${pGithub}/echo" && pwd'
alias goFramework='cd "${pGithub}/framework" && pwd'
alias goDocs='cd "${pGithub}/frameworki/docs" && pwd'
alias goPres='cd "${pGithub}/framework/pres" && pwd'
alias goSystems='cd "${pGithub}/systems" && pwd'

# Gitlab repositories
alias goGitlab='cd "${pGitlab}" && pwd'
alias goAnimations='cd "${pGitlab}/animations" && pwd'
alias goIcons='cd "${pGitlab}/icons" && pwd'
alias goHyperion='cd "${pGitlab}/hyperion" && pwd'
alias goOeuvre='cd "${pGitlab}/oeuvre" && pwd'
alias goPlacemat='cd "${pGitlab}/placemat" && pwd'
alias goPresentations='cd "${pGitlab}/presentations" && pwd'
alias goStrange='cd "${pGitlab}/strange" && pwd'
alias goZazzle='cd "${pGitlab}/zazzle" && pwd'

function goio() {
    local p
    p="$(pwd | sed -E 's|/(nb|wl)/|/io/|')"
    cd "${p}" && pwd
}

function gonb() {
    local p
    p="$(pwd | sed -E 's|/(io|wl)/|/nb/|')"
    cd "${p}" && pwd
}

function gowl() {
    local p
    p="$(pwd | sed -E 's|/(io|nb)/|/wl/|')"
    cd "${p}" && pwd
}


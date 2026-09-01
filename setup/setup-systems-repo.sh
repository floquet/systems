#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

counter=0
subcounter=0
start_time=${SECONDS}

function new_step() {
    export counter=$((counter + 1))
    export subcounter=0
    echo ""
    echo "Step ${counter}: ${1}"
}

function sub_step() {
    export subcounter=$((subcounter + 1))
    echo ""
    echo "  Substep ${counter}.${subcounter}: ${1}"
}

function display_total_elapsed_time() {
    local total_elapsed_time=$((SECONDS - start_time))
    local total_minutes=$((total_elapsed_time / 60))
    local total_seconds=$((total_elapsed_time % 60))
    echo ""
    printf "Total elapsed time: %02d:%02d (MM:SS)\n" \
        "$total_minutes" "$total_seconds"
}

# ----------------------------------------------------------------------
# Repository layout
# ----------------------------------------------------------------------

repo="${HOME}/repos-${HOSTNAME}/github/systems"

new_step "Create repository root: ${repo}"
          mkdir -p "${repo}"

new_step "Create initialization directories"
          mkdir -p \
              "${repo}/init"

new_step "Create host directories"
          mkdir -p \
              "${repo}/hosts/isomer" \
              "${repo}/hosts/isotope" \
              "${repo}/hosts/isotone" \
              "${repo}/hosts/quaxolotl" \
              "${repo}/hosts/nuclide"

new_step "Create setup directories"
          mkdir -p \
              "${repo}/setup/ssh" \
              "${repo}/setup/git" \
              "${repo}/setup/spack" \
              "${repo}/setup/latex" \
              "${repo}/setup/network"

new_step "Create probe directories"
          mkdir -p \
              "${repo}/probes/hardware" \
              "${repo}/probes/network" \
              "${repo}/probes/storage" \
              "${repo}/probes/compiler" \
              "${repo}/probes/environment"

new_step "Create snapshot directories"
          mkdir -p \
              "${repo}/snapshots/isomer" \
              "${repo}/snapshots/isotope" \
              "${repo}/snapshots/isotone" \
              "${repo}/snapshots/quaxolotl" \
              "${repo}/snapshots/nuclide"

# Git does not track empty directories.
new_step "Add .gitkeep to empty directories"
          find "${repo}" \
              -type d \
              -empty \
              -exec touch {}/.gitkeep \;

new_step "Display repository layout"
          tree -a "${repo}"

display_total_elapsed_time

# dantopa@isomer:~/isomer/scripts$ ./setup-systems-repo.sh 
# Mon Aug 31 10:47:40 PM MDT 2026, ./setup-systems-repo.sh
 
# Step 1: Create repository root: /home/dantopa/repos-isomer/github/systems
 
# Step 2: Create initialization directories
 
# Step 3: Create host directories
 
# Step 4: Create setup directories
 
# Step 5: Create probe directories
 
# Step 6: Create snapshot directories
 
# Step 7: Add .gitkeep to empty directories
 
# Step 8: Display repository layout
# /home/dantopa/repos-isomer/github/systems
# ├── hosts
# │   ├── isomer
# │   │   └── .gitkeep
# │   ├── isotone
# │   │   └── .gitkeep
# │   ├── isotope
# │   │   └── .gitkeep
# │   ├── nuclide
# │   │   └── .gitkeep
# │   └── quaxolotl
# │       └── .gitkeep
# ├── init
# │   └── .gitkeep
# ├── probes
# │   ├── compiler
# │   │   └── .gitkeep
# │   ├── environment
# │   │   └── .gitkeep
# │   ├── hardware
# │   │   └── .gitkeep
# │   ├── network
# │   │   └── .gitkeep
# │   └── storage
# │       └── .gitkeep
# ├── setup
# │   ├── git
# │   │   └── .gitkeep
# │   ├── latex
# │   │   └── .gitkeep
# │   ├── network
# │   │   └── .gitkeep
# │   ├── spack
# │   │   └── .gitkeep
# │   └── ssh
# │       └── .gitkeep
# └── snapshots
#     ├── isomer
#     │   └── .gitkeep
#     ├── isotone
#     │   └── .gitkeep
#     ├── isotope
#     │   └── .gitkeep
#     ├── nuclide
#     │   └── .gitkeep
#     └── quaxolotl
#         └── .gitkeep
 
# 26 directories, 21 files
 
# Total elapsed time: 00:00 (MM:SS)


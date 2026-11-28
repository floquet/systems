#!/usr/bin/env bash
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"

# ----------------------------------------------------------------------
# Fortran compiler
# ----------------------------------------------------------------------

alias gcc=gcc-16
alias gfortran=gfortran-16

export FC=caf

# ----------------------------------------------------------------------
# GNU Fortran warnings
# ----------------------------------------------------------------------

export Wflags="
-Wall
-Wextra
-Waliasing
-Wsurprising
-Wimplicit-procedure
-Wintrinsics-std
-Wfunction-elimination
-Wc-binding-type
-Wrealloc-lhs-all
-Wuse-without-only
-Wconversion-extra
"

# ----------------------------------------------------------------------
# GNU Fortran diagnostics / runtime checking
# ----------------------------------------------------------------------

export fflags="
-ffpe-trap=denormal,invalid,zero
-fbacktrace
-fmax-errors=5
-fcheck=all
-fcheck=do
-fcheck=pointer
-fno-protect-parens
-faggressive-function-elimination
-fdiagnostics-color=auto
-finit-derived
-fimplicit-none
-fallow-argument-mismatch
"

# ----------------------------------------------------------------------
# Specialized numerical-kernel option
# ----------------------------------------------------------------------
# -fno-realloc-lhs
#     Suppresses standard Fortran automatic allocation and reallocation.
#     Potentially useful in intensive numerical kernels with controlled
#     allocation lifetimes and array dimensions.
#     Not appropriate as a universal compiler flag.
#     Prefer -Wrealloc-lhs-all to identify potential reallocations.
#     Enable selectively, based on measured performance.

# ----------------------------------------------------------------------
# Optimization / language behavior
# ----------------------------------------------------------------------

export oflags="
-g
-Og
-pedantic
"

# Canonical flag set
export allflags="${Wflags} ${fflags} ${oflags}"

# ----------------------------------------------------------------------
# Inspection
# ----------------------------------------------------------------------

alias echogf='echo "$allflags"'
alias echowf='echo "$Wflags"'
alias echoff='echo "$fflags"'
alias echoof='echo "$oflags"'

# ----------------------------------------------------------------------
# Compile a single .f08 source
#
# Usage:
#     gf alpha
#
# Executes:
#     gfortran <flags> alpha.f08 -o alpha
# ----------------------------------------------------------------------

gf() {
    local stem="$1"

    if [[ -z "$stem" ]]; then
        echo "Usage: gf <file-stem>"
        return 1
    fi

    echo "gfortran ${allflags} ${stem}.f08 -o ${stem}"
    gfortran ${allflags} "${stem}.f08" -o "${stem}"
}



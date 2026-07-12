#!/usr/bin/env bash
# KryptOS build helpers. Source after env.sh:  source lib/build.sh
# Gives every package recipe the same shape: logged, resumable, fail-loud.

set -o pipefail

: "${LFS:?source env.sh first}"
: "${KRYPTOS_ROOT:?source env.sh first}"

LOG_DIR="$LFS/build-logs"
STATE_DIR="$LFS/build-state"
mkdir -p "$LOG_DIR" "$STATE_DIR" 2>/dev/null || true

msg()  { printf '\033[1;35m[KryptOS]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# is_done <name>  → true if that step already completed (resume support).
# NB: do NOT name this 'done' — that's a bash reserved word and silently breaks
# sourcing this file (then 'step' is undefined).
is_done() { [ -f "$STATE_DIR/$1.done" ]; }
mark()    { touch "$STATE_DIR/$1.done"; }

# Find a source tarball in $LFS/sources by package prefix, e.g. find_src gcc-
find_src() {
    local hit
    hit=$(ls "$LFS/sources/$1"*.tar.* 2>/dev/null | head -1) || true
    [ -n "$hit" ] || die "source not found for '$1' in $LFS/sources"
    printf '%s\n' "$hit"
}

# extract_to <workdir> <tarball>  → extracts and echoes the created dir
extract_to() {
    local work="$1" tarball="$2" before after
    mkdir -p "$work"; pushd "$work" >/dev/null
    before=$(ls -1)
    tar -xf "$tarball"
    after=$(ls -1)
    popd >/dev/null
    comm -13 <(printf '%s\n' "$before" | sort) <(printf '%s\n' "$after" | sort) | head -1 \
        | sed "s|^|$work/|"
}

# into <pkg-prefix>  → fresh-extract the package and cd into it (scratch dir).
B_WORK="${B_WORK:-/tmp/kbuild}"
into() { rm -rf "$B_WORK"; local d; d=$(extract_to "$B_WORK" "$(find_src "$1")"); cd "$d"; }

# step <name> <command...>  → run once, logged, resumable.
#   step gcc-pass1 build_gcc_pass1
step() {
    local name="$1"; shift
    if is_done "$name"; then msg "skip  $name (already done)"; return 0; fi
    msg "build $name ..."

    # Recipe must not be invoked directly as an if-condition. Bash disables
    # errexit inside functions used as conditions, allowing a later successful
    # command to hide an earlier configure/build failure.
    local rc restore_errexit=0
    case $- in *e*) restore_errexit=1; set +e ;; esac

    ( set -e; "$@" ) >"$LOG_DIR/$name.log" 2>&1
    rc=$?
    [ "$restore_errexit" -eq 1 ] && set -e

    if [ "$rc" -eq 0 ]; then
        mark "$name"; msg "ok    $name"
    else
        die "$name FAILED — see $LOG_DIR/$name.log (tail -40 it)"
    fi
}

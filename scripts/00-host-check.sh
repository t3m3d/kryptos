#!/usr/bin/env bash
# Verify the Linux build host has the tools (and versions) LFS needs.
# Adapted from the LFS book's version-check; run before building anything.
set -u

ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[31mMISS\033[0m %s\n' "$*"; FAIL=1; }
FAIL=0

echo "KryptOS host check"
echo "------------------"

ver() {  # ver <cmd> <args-to-print-version>
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1  $("$@" 2>&1 | head -1)"
    else
        bad "$1 not found"
    fi
}

ver bash --version
ver ld --version            # binutils
ver bison --version
ver chattr --version        # e2fsprogs
ver diff --version
ver find --version
ver gawk --version
ver gcc --version
ver g++ --version
ver grep --version
ver gzip --version
ver m4 --version
ver make --version
ver patch --version
ver perl -V:version
ver python3 --version
ver sed --version
ver tar --version
ver makeinfo --version      # texinfo
ver xz --version

# awk and yacc must resolve (LFS expects symlinks to gawk/bison)
command -v awk  >/dev/null 2>&1 && ok "awk -> $(readlink -f "$(command -v awk)")"  || bad "awk missing"
command -v yacc >/dev/null 2>&1 && ok "yacc -> $(readlink -f "$(command -v yacc)")" || bad "yacc missing (bison)"

# g++ can compile + link a trivial program
echo 'int main(){}' > /tmp/__kryptos_cc_test.cc
if g++ -o /tmp/__kryptos_cc_test /tmp/__kryptos_cc_test.cc 2>/dev/null && /tmp/__kryptos_cc_test; then
    ok "g++ compiles + links"
else
    bad "g++ cannot compile/link a test program"
fi
rm -f /tmp/__kryptos_cc_test /tmp/__kryptos_cc_test.cc

echo "------------------"
if [ "$FAIL" -eq 0 ]; then
    echo "Host looks ready. (Cross-check versions against the LFS $(. ./env.sh >/dev/null 2>&1; echo "${LFS_VERSION:-}") book.)"
else
    echo "Install the MISSing tools, then re-run."
    exit 1
fi

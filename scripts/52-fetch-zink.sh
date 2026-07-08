#!/usr/bin/env bash
# Fetch Vulkan pieces needed for Mesa zink + lavapipe. This is the software
# Vulkan path Hyprland/Aquamarine needs when llvmpipe EGL lacks native fences.
set -uo pipefail
: "${LFS:=/mnt/lfs}"
S="$LFS/sources"
mkdir -p "$S"; cd "$S"

URLS=(
  "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v1.3.296.tar.gz"
  "https://github.com/KhronosGroup/SPIRV-Headers/archive/refs/tags/vulkan-sdk-1.3.296.0.tar.gz"
  "https://github.com/KhronosGroup/SPIRV-Tools/archive/refs/tags/vulkan-sdk-1.3.296.0.tar.gz"
  "https://github.com/KhronosGroup/glslang/archive/refs/tags/15.0.0.tar.gz"
  "https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/v1.3.296.tar.gz"
)

fail=()
for u in "${URLS[@]}"; do
    f="$(basename "$u")"
    case "$u" in
        *Vulkan-Headers*) f="Vulkan-Headers-1.3.296.tar.gz" ;;
        *SPIRV-Headers*)  f="SPIRV-Headers-1.3.296.0.tar.gz" ;;
        *SPIRV-Tools*)    f="SPIRV-Tools-1.3.296.0.tar.gz" ;;
        *glslang*)        f="glslang-15.0.0.tar.gz" ;;
        *Vulkan-Loader*)  f="Vulkan-Loader-1.3.296.tar.gz" ;;
    esac
    if [ -s "$f" ]; then echo "have $f"; continue; fi
    echo "fetch $f"
    if ! timeout 240 wget -q -c -O "$f" "$u"; then
        echo "  FAILED $u"; rm -f "$f"; fail+=("$u")
    fi
done

echo "----"
if [ ${#fail[@]} -gt 0 ]; then
    printf '%s\n' "${fail[@]}" > "$S/zink-failed.txt"
    echo "FAILURES (${#fail[@]}) -> $S/zink-failed.txt:"; printf '  %s\n' "${fail[@]}"
    exit 1
fi
echo "all zink/lavapipe sources present in $S"

#!/usr/bin/env bash
# Desktop graphics fix - Vulkan userland for Mesa zink + lavapipe.
# Run in chroot after ch11-desktop-p1.sh has installed CMake/Ninja and before
# rebuilding Mesa in ch11-desktop-p2.sh. Resumable via /build-state markers.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

cmakeb() { local p="$1"; shift; into "$p"; rm -rf build; \
    cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release "$@"; \
    ninja -C build; ninja -C build install; }

extract_keep() {
    local work="$1" prefix="$2" src dir
    rm -rf "$work"; mkdir -p "$work"
    src=$(find_src "$prefix")
    dir=$(extract_to "$work" "$src")
    printf '%s\n' "$dir"
}

b_vulkan_headers() { cmakeb Vulkan-Headers-; }

b_spirv_headers() { cmakeb SPIRV-Headers-; }

b_spirv_tools() {
    local hdr
    hdr=$(extract_keep /tmp/kbuild-spirv-headers SPIRV-Headers-)
    cmakeb SPIRV-Tools- \
        -DSPIRV-Headers_SOURCE_DIR="$hdr" \
        -DSPIRV_SKIP_TESTS=ON \
        -DSPIRV_WERROR=OFF \
        -DSPIRV_TOOLS_BUILD_STATIC=OFF
}

b_glslang() {
    # glslang is not the critical lavapipe piece, but keeping it available makes
    # shader-tool expectations less surprising later. Keep tests/offline extras out.
    cmakeb glslang- \
        -DENABLE_TESTS=OFF \
        -DENABLE_GLSLANG_BINARIES=ON \
        -DENABLE_OPT=OFF \
        -DENABLE_SPVREMAPPER=OFF \
        -DBUILD_SHARED_LIBS=ON
}

b_vulkan_loader() {
    cmakeb Vulkan-Loader- \
        -DVULKAN_HEADERS_INSTALL_DIR=/usr \
        -DBUILD_TESTS=OFF \
        -DBUILD_WSI_XCB_SUPPORT=OFF \
        -DBUILD_WSI_XLIB_SUPPORT=OFF \
        -DBUILD_WSI_WAYLAND_SUPPORT=ON
}

b_vulkan_runtime_dirs() {
    install -dv /usr/share/vulkan/icd.d /usr/share/vulkan/implicit_layer.d /usr/share/vulkan/explicit_layer.d
    test -e /usr/lib/libvulkan.so -o -e /usr/lib/libvulkan.so.1
}

msg "zink/lavapipe prerequisites: Vulkan headers, SPIR-V tools, glslang, loader"
step z_vulkan_headers b_vulkan_headers
step z_spirv_headers  b_spirv_headers
step z_spirv_tools    b_spirv_tools
step z_glslang        b_glslang
step z_vulkan_loader  b_vulkan_loader
step z_vulkan_dirs    b_vulkan_runtime_dirs
msg "zink/lavapipe prerequisites done - remove /build-state/d_mesa.done, then rerun ch11-desktop-p2.sh so Mesa builds swrast Vulkan."

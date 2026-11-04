#!/usr/bin/env bash
# Desktop layer, Phase 2 — graphics + the rest of the render stack.
#   render-2: libpng, libjpeg-turbo, libwebp, fribidi, cairo, pango
#   graphics: LLVM + Mesa (llvmpipe, virgl, zink + lavapipe)
# Runs inside the chroot; resumable. LLVM + Mesa are the long compiles.
set -uo pipefail
set +h
export LFS=/ KRYPTOS_ROOT=/root/kryptos
source /root/kryptos/lib/build.sh

mesonb() { local p="$1"; shift; into "$p"; rm -rf build; \
    meson setup build --prefix=/usr --libdir=lib --buildtype=release "$@"; \
    ninja -C build; ninja -C build install; }
cmakeb() { local p="$1"; shift; into "$p"; rm -rf b; \
    cmake -S . -B b -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release "$@"; \
    ninja -C b; ninja -C b install; }

# --- render-2 ---
b_libpng()  { into libpng-; ./configure --prefix=/usr --disable-static; make; make install; }
b_libjpeg() { cmakeb libjpeg-turbo- -DENABLE_STATIC=OFF -DWITH_JPEG8=ON; }
b_libwebp() { cmakeb libwebp- -DBUILD_SHARED_LIBS=ON -DWEBP_LINK_STATIC=OFF; }
b_fribidi() { mesonb fribidi- -Ddocs=false -Dtests=false; }
b_cairo()   { mesonb cairo- -Dtests=disabled -Dxlib=disabled -Dxcb=disabled -Dspectre=disabled; }
b_pango()   { mesonb pango- -Dintrospection=disabled; }
b_markupsafe() { into markupsafe-; python3 -m pip install --no-index --no-build-isolation --no-deps .; }
b_mako()       { into mako-;       python3 -m pip install --no-index --no-build-isolation --no-deps .; }
b_pyyaml()     { into pyyaml-;     python3 -m pip install --no-index --no-build-isolation --no-deps .; }


# --- LLVM (software GL backend for Mesa's llvmpipe) ---
b_llvm() {
    into llvm-19                       # llvm-19.1.4.src (not the llvm-cmake aux)
    local top="$B_WORK"
    tar -C "$top" -xf "$(find_src llvm-cmake-)";   mv "$top/cmake-19.1.4.src"      "$top/cmake"
    tar -C "$top" -xf "$(find_src third-party-)";  mv "$top/third-party-19.1.4.src" "$top/third-party"
    local llvm_target
    case "$(uname -m)" in
        x86_64)        llvm_target="X86;AMDGPU" ;;
        aarch64|arm64) llvm_target=AArch64 ;;
        *) die "unsupported LLVM target architecture: $(uname -m)" ;;
    esac
    mkdir -p build; cd build
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="$llvm_target" \
        -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_ENABLE_FFI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_ENABLE_TERMINFO=OFF \
        -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_ZLIB=ON -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF ..
    ninja
    ninja install
}

# --- glslang (Mesa needs glslangValidator for the RADV Vulkan driver) ---
b_glslang() {
    into glslang-
    cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_OPT=OFF -DBUILD_EXTERNAL=OFF -DBUILD_TESTING=OFF -DENABLE_SPIRV=ON
    cmake --build build
    cmake --install build
}

# --- Mesa (VM/software renderers plus AMD radeonsi/RADV on x86_64) ---
b_mesa() {
    into mesa-24.3.4
    rm -rf build
    local gallium="llvmpipe,virgl,zink" vulkan="swrast"
    if [ "$(uname -m)" = x86_64 ]; then
        # radeonsi covers AMD hardware. Intel's iris is deferred: it needs
        # intel_clc -> libclc -> clang, and this toolchain has no clang.
        gallium+=",radeonsi"
        vulkan="amd,swrast"
    fi
    meson setup build --prefix=/usr --libdir=lib --buildtype=release \
        -Dplatforms=wayland -Dgallium-drivers="$gallium" -Dvulkan-drivers="$vulkan" \
        -Dglx=disabled -Degl=enabled -Dgbm=enabled -Dgles2=enabled -Dopengl=true \
        -Dllvm=enabled -Dshared-llvm=enabled -Dvideo-codecs= -Dlmsensors=disabled \
        -Dgallium-extra-hud=false -Dxlib-lease=disabled -Dglvnd=disabled
    ninja -C build
    local stale
    for stale in /usr/lib/libgallium-*.so; do
        [ -e "$stale" ] || [ -L "$stale" ] || continue
        rm -f "$stale"
    done
    [ ! -L /usr/lib/gbm/dri_gbm.so ] || rm -f /usr/lib/gbm/dri_gbm.so
    ninja -C build install
    # Mesa installs one Gallium megadriver but does not create the DRI loader
    # symlinks this image needs. Keep Mesa's real dri_gbm backend intact and
    # point only DRI loader names at the megadriver.
    local gl_path gl d dri_drivers="kms_swrast swrast virtio_gpu zink"
    gl_path=$(find /usr/lib -maxdepth 1 -type f -name 'libgallium-*.so' -print -quit)
    if [ -z "$gl_path" ]; then
        echo "Mesa gallium megadriver was not installed" >&2
        return 1
    fi
    gl=$(basename "$gl_path")
    mkdir -pv /usr/lib/dri /usr/lib/gbm
    [ "$(uname -m)" != x86_64 ] || dri_drivers+=" radeonsi"
    for d in $dri_drivers; do
        ln -sfnvT "../$gl" "/usr/lib/dri/${d}_dri.so"
        [ "$(readlink "/usr/lib/dri/${d}_dri.so")" = "../$gl" ]
    done
    if [ "$(uname -m)" = x86_64 ]; then
        llvm-config --targets-built | grep -qw AMDGPU
        pkg-config --exists libdrm_amdgpu
        test -e /usr/lib/libvulkan_radeon.so
    fi
    test -s /usr/lib/gbm/dri_gbm.so
    readelf -Ws /usr/lib/gbm/dri_gbm.so | grep -qw gbmint_get_backend
}

msg "desktop Phase 2: render-2 + graphics (LLVM/Mesa)"
step d_libpng       b_libpng
step d_libjpeg      b_libjpeg
step d_libwebp      b_libwebp
step d_fribidi      b_fribidi
step d_cairo        b_cairo
step d_pango        b_pango
step d_markupsafe   b_markupsafe
step d_mako         b_mako
step d_pyyaml       b_pyyaml
step d_llvm         b_llvm
step d_glslang      b_glslang
step d_mesa         b_mesa
msg "desktop Phase 2 done — next: input/session + hypr stack."

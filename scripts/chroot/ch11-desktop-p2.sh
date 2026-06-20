#!/usr/bin/env bash
# Desktop layer, Phase 2 — graphics + the rest of the render stack.
#   render-2: libpng, libjpeg-turbo, libwebp, fribidi, cairo, pango
#   graphics: LLVM (for llvmpipe software GL) + Mesa (llvmpipe + virgl)
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

# --- LLVM (software GL backend for Mesa's llvmpipe) ---
b_llvm() {
    into llvm-19                       # llvm-19.1.4.src (not the llvm-cmake aux)
    local top="$B_WORK"
    tar -C "$top" -xf "$(find_src llvm-cmake-)";   mv "$top/cmake-19.1.4.src"      "$top/cmake"
    tar -C "$top" -xf "$(find_src third-party-)";  mv "$top/third-party-19.1.4.src" "$top/third-party"
    mkdir -p build; cd build
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="AArch64" \
        -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_ENABLE_FFI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_ENABLE_TERMINFO=OFF \
        -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_ZLIB=ON -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF ..
    ninja
    ninja install
}

# --- Mesa (llvmpipe software GL + virgl for QEMU virtio-gpu) ---
b_mesa() {
    into mesa-
    rm -rf build
    meson setup build --prefix=/usr --libdir=lib --buildtype=release \
        -Dplatforms=wayland -Dgallium-drivers=llvmpipe,virgl -Dvulkan-drivers= \
        -Dglx=disabled -Degl=enabled -Dgbm=enabled -Dgles2=enabled -Dopengl=true \
        -Dllvm=enabled -Dshared-llvm=enabled -Dvideo-codecs= -Dlmsensors=disabled \
        -Dgallium-extra-hud=false -Dxlib-lease=disabled -Dglvnd=disabled
    ninja -C build
    ninja -C build install
}

msg "desktop Phase 2: render-2 + graphics (LLVM/Mesa)"
step d_libpng       b_libpng
step d_libjpeg      b_libjpeg
step d_libwebp      b_libwebp
step d_fribidi      b_fribidi
step d_cairo        b_cairo
step d_pango        b_pango
step d_llvm         b_llvm
step d_mesa         b_mesa
msg "desktop Phase 2 done — next: input/session + hypr stack."

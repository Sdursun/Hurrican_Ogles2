#!/bin/bash
# Builds the static 68k libraries for the ogles2 (OpenGL ES 2.0) build of
# Hurrican with libnix, like the MiniGL build, into $SDK:
#   ogles2 SDK (headers, libogles2.a), SDL2 with the ogles2 backend,
#   libmodplug, SDL2_image 2 (PNG/BMP) and SDL2_mixer 2 (WAV + modplug).
# zlib and libpng are the toolchain's own (built by build-deps.sh).
#
# SDL2 is Steffen Haeuser's SDL2_68k with the ogles2 project's patches and
# GLES2 backend (github.com/ladislawv/ogles2, ports/sdl2) applied, built
# here with libnix: ogles2's prebuilt libSDL2.a is clib2, and the
# toolchain's libstdc++ only works with libnix (its file and console
# streams crash or stay silent with clib2). SDL_68k's prebuilt SDL2_mixer
# has modplug switched off, so the mixer is built here too.
#
# Requires an installed AmigaPorts m68k-amigaos-gcc toolchain (with vasm),
# the unpacked ogles2 SDK archive and PiStorm3D's minigl.library 29.1 SDK.
# Usage: build-deps-ogles2.sh <ogles2 sdk dir> <minigl sdk dir>
#   e.g. .../ogles2-1.3.1-sdk/ogles2/SDK .../PiStorm3D/SDK

set -euo pipefail

OGLES2_SDK=$1
MINIGL_SDK=$2
PREFIX=${PREFIX:-/opt/amiga}
SDK=${SDK:-$PREFIX/hurrican-ogles2-sdk}
DEPS=${DEPS:-$HOME/amiga-deps-ogles2}
JOBS=${JOBS:-$(nproc)}
# ogles2's ports/sdl2/build.sh pins these
OGLES2_REPO_COMMIT=${OGLES2_REPO_COMMIT:-}
SDL68K_COMMIT=3632f48dc4d085355954322ae452ecc7b007ebc6

export PATH=$PREFIX/bin:$PATH
CC=m68k-amigaos-gcc
AR=m68k-amigaos-ar
CPU="-m68040 -mhard-float -noixemul"
OPT="-O2 -fomit-frame-pointer"
HERE=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$DEPS" "$SDK/include" "$SDK/lib"

clone() { # dir url [branch]
    [ -d "$DEPS/$1" ] && return
    git clone ${3:+--depth 1 -b $3} "$2" "$DEPS/$1"
}

build_static() { # srcdir outlib cflags sources...
    local src=$1 out=$2 flags=$3; shift 3
    local obj="$DEPS/obj-$(basename "$out" .a)"
    rm -rf "$obj"; mkdir -p "$obj"
    for f in "$@"; do
        $CC $CPU $OPT $flags -I"$SDK/include" -I"$SDK/include/SDL2" \
            -c "$src/$f" -o "$obj/$(basename "${f%.c}").o"
    done
    rm -f "$SDK/lib/$out"
    $AR rcs "$SDK/lib/$out" "$obj"/*.o
}

echo "== ogles2 SDK"
cp -r "$OGLES2_SDK/include/." "$SDK/include/"
cp "$OGLES2_SDK/lib/libogles2.a" "$SDK/lib/"
cp "$MINIGL_SDK/lib/libminigl.a" "$SDK/lib/"

echo "== SDL2 (SDL2_68k + ogles2 backend, libnix)"
clone ogles2-src https://github.com/ladislawv/ogles2.git
[ -n "$OGLES2_REPO_COMMIT" ] && git -C "$DEPS/ogles2-src" checkout -q "$OGLES2_REPO_COMMIT"
clone SDL2_68k https://github.com/SteffenHaeuser/SDL2_68k.git
S=$DEPS/SDL2_68k
git -C "$S" -c advice.detachedHead=false checkout -q "$SDL68K_COMMIT"
git -C "$S" checkout -q -- .
git -C "$S" clean -qfdx
for p in "$DEPS"/ogles2-src/ports/sdl2/patches/*.patch; do
    git -C "$S" apply "$p"
done
L=$S/libSDL2-amigaos3-main
cp "$DEPS"/ogles2-src/ports/sdl2/src/video/amigaos3/SDL_os3opengles2.[ch] "$L/src/video/amigaos3/"
# the clib2 Makefile drops SDL's debug output; do the same for libnix
sed -i 's/ -DSDL_OS3_DEBUG$//' "$L/Makefile.libnix"
# SDL's own libm declares u_int32_t, which libnix's sys/types.h has already
sed -i 's|^#if !defined(__HAIKU__) && !defined(__PSP__)|#if !defined(__AMIGAOS3__) \&\& !defined(__HAIKU__) \&\& !defined(__PSP__)|' \
    "$L/src/libm/math_private.h"
# Intuition takes at most 24 as SA_Depth; a 32-bit RTG mode is opened with
# depth 24 and chosen by SA_DisplayID. With 32 OpenScreenTags fails, and the
# fullscreen window is left without an Intuition window to draw into.
sed -i 's|SA_Depth,      (ULONG)depth,|SA_Depth,      (ULONG)(depth > 24 ? 24 : depth),|' \
    "$L/src/video/amigaos3/SDL_os3window.c" "$L/src/video/amigaos3/SDL_os3video.c"
# SDL2_68k's joystick driver reports no joysticks; ours reads lowlevel.library
# and the Xbox 360 pads of xbox360w.class (see the file)
cp "$HERE"/joystick/sdl2/SDL_sysjoystick.c "$HERE"/joystick/amiga_xbox360w.h \
   "$HERE"/joystick/xbox360w.h "$L/src/joystick/amigaos3/"
# SDL2_68k was written for GCC 6: its config defines no HAVE_STDLIB_H etc.,
# so the C library's prototypes come in through -include here, and GCC 14's
# stricter C rules are relaxed with -fpermissive
LIBC_INC="-fpermissive -include stdlib.h -include string.h -include strings.h -include ctype.h -include stdio.h -include math.h"
# MiniGL's headers reach ../../../backend/include, so keep its SDK whole
make -C "$L" -f Makefile.libnix -j"$JOBS" \
    OGLES2_CFLAGS="$LIBC_INC -I$SDK/include -I$MINIGL_SDK/minigl-shared-library/include" \
    build/libnix/libSDL2.a >"$DEPS/sdl2-make.log" 2>&1 ||
    { grep -E "error|Error" "$DEPS/sdl2-make.log" | head -30; exit 1; }
cp "$L/build/libnix/libSDL2.a" "$SDK/lib/"
mkdir -p "$SDK/include/SDL2"
cp "$L"/include/*.h "$SDK/include/SDL2/"

echo "== libmodplug"
clone libmodplug https://github.com/Konstanty/libmodplug.git
cmake -S "$DEPS/libmodplug" -B "$DEPS/libmodplug/build-libnix" \
    -DCMAKE_TOOLCHAIN_FILE="$HERE/../cmake/m68k-amigaos.cmake" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_INSTALL_PREFIX="$SDK"
cmake --build "$DEPS/libmodplug/build-libnix" -j "$JOBS"
cmake --install "$DEPS/libmodplug/build-libnix"

echo "== SDL2_image 2 (PNG, BMP)"
clone SDL2_image https://github.com/libsdl-org/SDL_image.git release-2.8.x
build_static "$DEPS/SDL2_image/src" libSDL2_image.a "-DLOAD_PNG -DLOAD_BMP -I$DEPS/SDL2_image/include" \
    IMG.c IMG_avif.c IMG_bmp.c IMG_gif.c IMG_jpg.c IMG_jxl.c IMG_lbm.c IMG_pcx.c \
    IMG_png.c IMG_pnm.c IMG_qoi.c IMG_svg.c IMG_tga.c IMG_tif.c IMG_webp.c \
    IMG_xcf.c IMG_xpm.c IMG_xv.c
cp "$DEPS/SDL2_image/include/SDL_image.h" "$SDK/include/SDL2/"

echo "== SDL2_mixer 2 (WAV, modplug)"
clone SDL2_mixer https://github.com/libsdl-org/SDL_mixer.git release-2.8.x
build_static "$DEPS/SDL2_mixer/src" libSDL2_mixer.a \
    "-DMUSIC_WAV -DMUSIC_MOD_MODPLUG -I$DEPS/SDL2_mixer/include -I$DEPS/SDL2_mixer/src -I$DEPS/SDL2_mixer/src/codecs -I$SDK/include/libmodplug" \
    effect_position.c effect_stereoreverse.c effects_internal.c mixer.c music.c \
    utils.c codecs/load_aiff.c codecs/load_voc.c codecs/mp3utils.c \
    codecs/music_wav.c codecs/music_modplug.c
cp "$DEPS/SDL2_mixer/include/SDL_mixer.h" "$SDK/include/SDL2/"

echo "== done, SDK in $SDK"
ls -l "$SDK/lib"

#!/bin/bash
# Builds the static 68k libraries for the ogles2 (OpenGL ES 2.0) build of
# Hurrican, all with clib2, into $SDK:
#   ogles2 SDK (headers, libogles2.a), SDL2 with the ogles2 backend and the
#   minigl.library import library (both from the ogles2 SDL archive), zlib,
#   libpng, libmodplug, SDL2_image 2 (PNG/BMP) and SDL2_mixer 2 (WAV + modplug)
#
# SDL_68k's prebuilt SDL2_mixer has modplug switched off, so the mixer is
# built here.
#
# Requires an installed AmigaPorts m68k-amigaos-gcc toolchain with clib2 and
# the unpacked ogles2 archives ogles2-<v>-sdk and ogles2-<v>-sdl.
# Usage: build-deps-ogles2.sh <ogles2 sdk dir> <ogles2 sdl dir> [toolchain-source-dir]
#   e.g. .../ogles2-1.3.1-sdk/ogles2/SDK .../ogles2-1.3.1-sdl/ogles2/SDK

set -euo pipefail

OGLES2_SDK=$1
OGLES2_SDL=$2
TOOLCHAIN_SRC=${3:-$HOME/m68k-amigaos-gcc}
PREFIX=${PREFIX:-/opt/amiga}
SDK=${SDK:-$PREFIX/hurrican-ogles2-sdk}
DEPS=${DEPS:-$HOME/amiga-deps-ogles2}
JOBS=${JOBS:-$(nproc)}

export PATH=$PREFIX/bin:$PATH
CC=m68k-amigaos-gcc
AR=m68k-amigaos-ar
CPU="-m68040 -mhard-float -mcrt=clib2 -D__AMIGAOS3__"
OPT="-O2 -fomit-frame-pointer"
HERE=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$DEPS" "$SDK/include" "$SDK/lib"

clone() { # dir url [branch]
    [ -d "$DEPS/$1" ] && return
    git clone --depth 1 ${3:+-b $3} "$2" "$DEPS/$1"
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

echo "== ogles2 SDK, SDL2 (ogles2 backend), minigl.library import library"
cp -r "$OGLES2_SDK/include/." "$SDK/include/"
cp "$OGLES2_SDK/lib/libogles2.a" "$SDK/lib/"
cp -r "$OGLES2_SDL/SDL2/include/." "$SDK/include/"
cp "$OGLES2_SDL/SDL2/lib/libSDL2.a" "$SDK/lib/"
cp "$OGLES2_SDL/MiniGL/lib/libminigl.a" "$SDK/lib/"

echo "== zlib"
Z=$(ls -d "$TOOLCHAIN_SRC"/projects/zlib-* | head -1)
build_static "$Z" libz.a "" adler32.c compress.c crc32.c deflate.c gzclose.c \
    gzlib.c gzread.c gzwrite.c infback.c inffast.c inflate.c inftrees.c trees.c \
    uncompr.c zutil.c
cp "$Z/zlib.h" "$Z/zconf.h" "$SDK/include/"

echo "== libpng"
P=$(ls -d "$TOOLCHAIN_SRC"/projects/libpng-* | head -1)
cp "$P/scripts/pnglibconf.h.prebuilt" "$P/pnglibconf.h"
build_static "$P" libpng.a "-DPNG_ARM_NEON_OPT=0" png.c pngerror.c pngget.c \
    pngmem.c pngpread.c pngread.c pngrio.c pngrtran.c pngrutil.c pngset.c \
    pngtrans.c pngwio.c pngwrite.c pngwtran.c pngwutil.c
cp "$P/png.h" "$P/pngconf.h" "$P/pnglibconf.h" "$SDK/include/"

echo "== libmodplug"
clone libmodplug https://github.com/Konstanty/libmodplug.git
# clib2's unistd.h pulls in exec/types.h, whose WORD/BYTE/BOOL clash with
# modplug's own; the MIDI/ABC/PAT loaders only want sleep() from it
sed -i 's|^#include <unistd.h>.*|extern "C" unsigned int sleep(unsigned int);|' \
    "$DEPS"/libmodplug/src/load_{mid,abc,pat}.cpp
cmake -S "$DEPS/libmodplug" -B "$DEPS/libmodplug/build-clib2" \
    -DCMAKE_TOOLCHAIN_FILE="$HERE/../cmake/m68k-amigaos.cmake" -DAMIGA_CRT=clib2 \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_INSTALL_PREFIX="$SDK"
cmake --build "$DEPS/libmodplug/build-clib2" -j "$JOBS"
cmake --install "$DEPS/libmodplug/build-clib2"

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

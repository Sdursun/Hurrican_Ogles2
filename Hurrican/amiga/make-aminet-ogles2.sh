#!/bin/bash
# Packs the Aminet release of the ogles2 build: Hurrican_ogles2.lha and
# Hurrican_ogles2.readme in $OUT.
#
# Usage: make-aminet-ogles2.sh <stripped hurrican executable> <ogles2 dir> [out dir]
#   <ogles2 dir>: the unpacked ogles2 SDK archive's ogles2/ drawer (LICENSE)
# Needs lha, Python 3 with Pillow (for the icon), and the sources fetched by
# build-deps-ogles2.sh in $DEPS (their license files go into the archive).

set -euo pipefail
LHA=${LHA:-lha}

EXE=$1
OGLES2_DIR=$2
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
OUT=${3:-$ROOT/dist-aminet}
DEPS=${DEPS:-$HOME/amiga-deps-ogles2}
TOOLCHAIN_SRC=${TOOLCHAIN_SRC:-$HOME/m68k-amigaos-gcc}
MINIGL_SDK=${MINIGL_SDK:-$ROOT/PiStorm3D}
NAME=Hurrican_ogles2

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
GAME=$STAGE/Hurrican
DOCS=$GAME/Docs
LIC=$DOCS/Licenses
mkdir -p "$LIC"

cp "$EXE" "$GAME/Hurrican"
chmod +x "$GAME/Hurrican"
python3 -W ignore "$HERE/make-icon.py" "$ROOT/Hurrican/Hurrican.ico" "$GAME/Hurrican.info"
# the GLES2 renderer's shaders are shaders/100; 320 is for desktop GL 3,
# pvr textures for PowerVR GPUs
rsync -a --exclude pvr --exclude 'shaders/320' "$ROOT/Hurrican/data" "$GAME/"
rsync -a "$ROOT/Hurrican/lang" "$GAME/"

cp "$HERE/aminet/$NAME.readme" "$DOCS/$NAME.readme"
cp "$ROOT/Hurrican/readme.txt" "$DOCS/readme.txt"
cp "$ROOT/README.txt" "$DOCS/README-source.txt"
cp "$HERE/LICENSE" "$DOCS/LICENSE-port.txt"

L=$DEPS/SDL2_68k/libSDL2-amigaos3-main
cp "$L/LICENSE" "$LIC/SDL2.txt"
cp "$DEPS/SDL2_image/LICENSE.txt" "$LIC/SDL2_image.txt"
cp "$DEPS/SDL2_mixer/LICENSE.txt" "$LIC/SDL2_mixer.txt"
cp "$DEPS/libmodplug/COPYING" "$LIC/libmodplug.txt"
cp "$TOOLCHAIN_SRC"/projects/zlib-*/LICENSE "$LIC/zlib.txt"
cp "$TOOLCHAIN_SRC"/projects/libpng-*/LICENSE "$LIC/libpng.txt"
cp "$OGLES2_DIR/LICENSE" "$LIC/ogles2.txt"
cp "$MINIGL_SDK/licences/License_MiniGL_Library.txt" "$LIC/MiniGL.txt"
cp "$ROOT/Hurrican/3rdparty/glm/copying.txt" "$LIC/glm.txt"

# Amiga text: LF line ends
find "$DOCS" -name '*.txt' -o -name '*.readme' | xargs sed -i 's/\r$//'

mkdir -p "$OUT"
rm -f "$OUT/$NAME.lha"
(cd "$STAGE" && "$LHA" aq "$OUT/$NAME.lha" Hurrican)
cp "$HERE/aminet/$NAME.readme" "$OUT/$NAME.readme"
sed -i 's/\r$//' "$OUT/$NAME.readme"
ls -l "$OUT"

# Hurrican for AmigaOS 3.x / PiStorm3D

Port target: AmigaOS 3.x on 68k, primarily PiStorm (Emu68) with a
Raspberry Pi 4 / CM4 and the PiStorm3D `minigl.library` (VideoCore V3D).

Stack: SDL 1.2 with the MiniGL backend
([SDL1_MiniGL_Library](https://github.com/SteffenHaeuser/SDL1_MiniGL_Library)),
SDL_image 1.2 (PNG), SDL_mixer 1.2 (WAV + libmodplug for the `.it` music)
and Hurrican's fixed-function `GL1` renderer.

## Building (Linux / WSL)

1. Build the cross compiler (GCC 16.2, installs to `/opt/amiga`):

       git clone https://github.com/AmigaPorts/m68k-amigaos-gcc
       cd m68k-amigaos-gcc && make update && make all -j$(nproc)

2. Build the 68k libraries into `/opt/amiga/hurrican-sdk`:

       Hurrican/amiga/build-deps.sh ~/m68k-amigaos-gcc

3. Build the game:

       mkdir build-amiga && cd build-amiga
       cmake ../Hurrican -DCMAKE_TOOLCHAIN_FILE=../Hurrican/cmake/m68k-amigaos.cmake \
             -DPLATFORM=AMIGA -DCMAKE_BUILD_TYPE=Release -DUSE_PRECOMPILED_HEADERS=OFF
       make -j$(nproc)
       m68k-amigaos-strip hurrican

### Classic variant (Warp3D / Wazp3D / QuarkTex)

Non-PiStorm systems use the Classic `minigl.library`. Its SDK headers are
the same, only the `libminigl.a` import library differs, so the same
sources and libraries are linked against that stub into `hurrican-classic`:

    cmake ../Hurrican -DCMAKE_TOOLCHAIN_FILE=../Hurrican/cmake/m68k-amigaos.cmake \
          -DPLATFORM=AMIGA -DCMAKE_BUILD_TYPE=Release -DUSE_PRECOMPILED_HEADERS=OFF \
          -DAMIGA_MINIGL_LIB=<MiniGL_Library_Classic>/dev/lib/libminigl.a \
          -DAMIGA_OUTPUT_NAME=hurrican-classic

On the Amiga install the Classic `minigl.library` (from its `bin/`) in `LIBS:`
instead of the PiStorm3D one, plus Warp3D or Wazp3D.

### ogles2 variant (OpenGL ES 2.0, SDL2)

A second build draws with OpenGL ES 2.0 through
[ogles2.library](https://github.com/ladislawv/ogles2) (PiStorm with a Pi 4 /
CM4 only) and uses SDL2 with ogles2's backend and Hurrican's `GLES2`
renderer. That SDL2 is built with clib2, so everything in this variant is
built with clib2 too:

1. Unpack `ogles2-<v>-sdk.lha` and `ogles2-<v>-sdl.lha` (or their `.zip`)
   and build the libraries into `/opt/amiga/hurrican-ogles2-sdk`:

       Hurrican/amiga/build-deps-ogles2.sh <ogles2-sdk>/ogles2/SDK <ogles2-sdl>/ogles2/SDK

2. Build the game:

       cmake ../Hurrican -DCMAKE_TOOLCHAIN_FILE=../Hurrican/cmake/m68k-amigaos.cmake \
             -DAMIGA_CRT=clib2 -DPLATFORM=AMIGA_OGLES2 -DCMAKE_BUILD_TYPE=Release \
             -DUSE_PRECOMPILED_HEADERS=OFF
       make -j$(nproc)

On the Amiga it needs `ogles2.library` and its shader compiler `v3dglslc`
(ogles2's `Install-ogles2`, or both in `PROGDIR:libs/`). Hurrican's shaders
in `data/shaders/100` are compiled on the first start and kept in
`OGLES2Cache:` (or `T:`).

## Running

Requirements on the Amiga:

* AmigaOS 3.x with RTG (Picasso96 or CyberGraphX)
* `minigl.library` in `LIBS:` (PiStorm3D for Pi4/CM4 PiStorm systems)
* AHI for sound

Copy the executable next to the `data` and `lang` folders. Data, settings,
save games and `Game_Log.txt` are all found through `PROGDIR:`, so it can be
started from any directory (or from Workbench); temporary files go to `T:`.
`-PD <dir>` / `-PS <dir>` override the data / save directory.

    Work:Hurrican/Hurrican

Useful options if it runs slowly or textures do not fit: `-D 16` (16-bit
screen), `-TF 2` (halve texture size), `-L` (320x240), `-W` (window mode),
`-F` (show FPS). `Hurrican --help` lists everything.

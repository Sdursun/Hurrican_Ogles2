# CMake toolchain file for AmigaOS 3.x 68k (AmigaPorts/bebbo m68k-amigaos-gcc)
#
#   cmake -DCMAKE_TOOLCHAIN_FILE=../cmake/m68k-amigaos.cmake -DPLATFORM=AMIGA ..

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR m68k)

set(AMIGA_TOOLCHAIN_PREFIX "/opt/amiga" CACHE PATH "m68k-amigaos-gcc install prefix")

set(CMAKE_C_COMPILER   ${AMIGA_TOOLCHAIN_PREFIX}/bin/m68k-amigaos-gcc)
set(CMAKE_CXX_COMPILER ${AMIGA_TOOLCHAIN_PREFIX}/bin/m68k-amigaos-g++)
set(CMAKE_AR           ${AMIGA_TOOLCHAIN_PREFIX}/bin/m68k-amigaos-ar)
set(CMAKE_RANLIB       ${AMIGA_TOOLCHAIN_PREFIX}/bin/m68k-amigaos-ranlib)

# PiStorm/Emu68 presents a 68040 with FPU. C runtime: libnix (MiniGL build)
# or clib2 (-DAMIGA_CRT=clib2, the ogles2 build: its SDL2 is built on clib2)
set(AMIGA_CRT "libnix" CACHE STRING "C runtime: libnix or clib2")
if(AMIGA_CRT STREQUAL "clib2")
    set(AMIGA_CPU_FLAGS "-m68040 -mhard-float -mcrt=clib2 -D__AMIGAOS3__")
else()
    set(AMIGA_CPU_FLAGS "-m68040 -mhard-float -noixemul")
endif()
set(CMAKE_C_FLAGS_INIT   "${AMIGA_CPU_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${AMIGA_CPU_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${AMIGA_CPU_FLAGS}")

set(CMAKE_FIND_ROOT_PATH ${AMIGA_TOOLCHAIN_PREFIX}/m68k-amigaos)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Linking a test executable needs the full runtime, a static library is enough
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

ExternalProject_Add(mpv
    DEPENDS
        angle-headers
        ffmpeg
        fribidi
        lcms2
        libarchive
        libass
        libdvdnav
        libdvdread
        libiconv
        libjpeg
        libpng
        luajit
        rubberband
        uchardet
        openal-soft
        mujs
        vulkan
        shaderc
        libplacebo
        spirv-cross
        vapoursynth
        libsdl2
        subrandr
        libsixel
        curl
    GIT_REPOSITORY https://github.com/mpv-player/mpv.git
    GIT_TAG e76a35ec95b27f5cf2d27b043b5e2e0d90e468ae # pinned: VideoPlayerGold patches are made against this commit
    # The patch step rewinds the tree ITSELF rather than relying on force_rebuild_git().
    #
    # Two builds failed here with conflicts in filters/user_filters.c, user_filters.h and
    # meson.build. The patches were never the problem - the cached source was simply never
    # rewound, so `git am` kept re-applying them onto a tree that already had them. Worse, a
    # failed `git am` leaves a half-applied rebase-apply session behind, and THAT state is what
    # the CI cache then stored and restored, so every later run started already broken.
    #
    # force_rebuild_git() cannot fix this for mpv: it chooses its reset target as
    #     GIT_REMOTE_NAME empty AND GIT_TAG set  ->  reset = ""
    # which is exactly mpv's shape, so it runs `git reset --hard` with no target and rewinds to
    # HEAD, i.e. to wherever the last build left things. Adding GIT_RESET did not help either,
    # because the leftover am session survives the reset.
    #
    # So: abort any in-progress am, hard-reset to the pin, remove untracked files, then apply.
    # Idempotent from ANY starting state, including a poisoned cache.
    PATCH_COMMAND ${EXEC} bash -c "cd <SOURCE_DIR> && (git am --abort >/dev/null 2>&1 || true) && git reset --hard e76a35ec95b27f5cf2d27b043b5e2e0d90e468ae -q && git clean -fdq"
    COMMAND ${EXEC} git am --3way ${CMAKE_CURRENT_SOURCE_DIR}/mpv-*.patch
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    CONFIGURE_COMMAND ${EXEC} CONF=1 meson setup <BINARY_DIR> <SOURCE_DIR>
        --prefix=${MINGW_INSTALL_PREFIX}
        --libdir=${MINGW_INSTALL_PREFIX}/lib
        --cross-file=${MESON_CROSS}
        --default-library=shared
        --prefer-static
        -Ddebug=true
        -Db_ndebug=true
        -Doptimization=3
        -Db_lto=true
        ${mpv_lto_mode}
        -Dlibmpv=true
        -Dpdf-build=enabled
        -Dlua=enabled
        -Djavascript=enabled
        -Dsdl2-gamepad=enabled
        -Dlibarchive=enabled
        -Dlibbluray=enabled
        -Ddvdnav=enabled
        -Duchardet=enabled
        -Drubberband=enabled
        -Dlcms2=enabled
        -Dopenal=enabled
        -Dspirv-cross=enabled
        -Dvulkan=enabled
        -Dvapoursynth=enabled
        -Dsubrandr=enabled
        -Dsixel=enabled
        ${mpv_gl}
        -Dlibcurl=enabled
        -Dc_args='-Wno-error=int-conversion'
    BUILD_COMMAND ${EXEC} LTO_JOB=1 PDB=1 ninja -C <BINARY_DIR>
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

ExternalProject_Add_Step(mpv strip-binary
    DEPENDEES build
    ${mpv_add_debuglink}
    COMMENT "Stripping mpv binaries"
)

ExternalProject_Add_Step(mpv copy-binary
    DEPENDEES strip-binary
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.exe                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv.exe
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.com                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv.com
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/etc/mpv-register.bat              ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv-register.bat
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/etc/mpv-unregister.bat            ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv-unregister.bat
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.pdf                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/doc/manual.pdf
    COMMAND ${CMAKE_COMMAND} -E copy ${MINGW_INSTALL_PREFIX}/etc/fonts/fonts.conf   ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv/fonts.conf
    ${mpv_copy_debug}
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libmpv-2.dll          ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/libmpv-2.dll
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libmpv.dll.a          ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/libmpv.dll.a
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/client.h       ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/client.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/stream_cb.h    ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/stream_cb.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/render.h       ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/render.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/render_gl.h    ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/render_gl.h
    COMMENT "Copying mpv binaries and manual"
)

set(RENAME ${CMAKE_CURRENT_BINARY_DIR}/mpv-prefix/src/rename.sh)
file(WRITE ${RENAME}
"#!/bin/bash
cd $1
GIT=$(git rev-parse --short=10 HEAD)
mv $2 $2-git-\${GIT}")

ExternalProject_Add_Step(mpv copy-package-dir
    DEPENDEES copy-binary
    COMMAND chmod 755 ${RENAME}
    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-package ${CMAKE_BINARY_DIR}/mpv-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}

    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-debug ${CMAKE_BINARY_DIR}/mpv-debug-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-debug-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}

    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev ${CMAKE_BINARY_DIR}/mpv-dev-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-dev-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMENT "Moving mpv package folder"
    LOG 1
)

force_rebuild_git(mpv)
force_meson_configure(mpv)
cleanup(mpv copy-package-dir)

ExternalProject_Add(openal-soft
    DEPENDS
        libsdl2
    GIT_REPOSITORY https://github.com/kcat/openal-soft.git
    GIT_REMOTE_NAME origin
    GIT_TAG master
    # Pinned 2026-09-23. openal-soft master broke the SAME DAY: commits "Move the OpenAL EAX API
    # declarations to their own header" and "Move eax_log_exception to where it's used" left
    # al/eax.cpp including "logging.h" without the include path, so clang-scan-deps fails with
    # 'logging.h' file not found while generating the C++ module dependency file. Nothing to do
    # with this branch's Dolby Vision work - it simply landed between builds.
    # 8d2d2e2e is 2026-09-14, before the breakage and before the last known-good build.
    # Remove this pin once upstream fixes it; shinchiro has a standing habit of
    # "openal-soft: fix build" commits, so it will not stay broken for long.
    GIT_RESET 8d2d2e2ed1f51df960e7eb4bb26b64625c873c0d
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    CONFIGURE_COMMAND ${EXEC} CONF=1 cmake -H<SOURCE_DIR> -B<BINARY_DIR>
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}
        -DCMAKE_INSTALL_PREFIX=${MINGW_INSTALL_PREFIX}
        -DCMAKE_FIND_ROOT_PATH=${MINGW_INSTALL_PREFIX}
        -DBUILD_SHARED_LIBS=OFF
        -DLIBTYPE=STATIC
        -DALSOFT_ENABLE_MODULES=OFF
        -DALSOFT_UTILS=OFF
        -DALSOFT_EXAMPLES=OFF
        -DALSOFT_TESTS=OFF
        -DALSOFT_BACKEND_PIPEWIRE=OFF
        -DCMAKE_C_FLAGS='-include stdlib.h'
        -DCMAKE_CXX_FLAGS='-I<SOURCE_DIR>/gsl/include -include cstdlib'
    BUILD_COMMAND ${EXEC} ninja -C <BINARY_DIR>
          COMMAND bash -c "echo 'Libs.private: -lole32 -luuid -lshlwapi' >> <BINARY_DIR>/openal.pc"
    INSTALL_COMMAND ${EXEC} ninja -C <BINARY_DIR> install
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(openal-soft)
cleanup(openal-soft install)

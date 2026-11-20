get_property(src_glad TARGET glad PROPERTY _EP_SOURCE_DIR)
get_property(src_fast_float TARGET fast_float PROPERTY _EP_SOURCE_DIR)
ExternalProject_Add(libplacebo
    DEPENDS
        vulkan
        shaderc
        spirv-cross
        lcms2
        glad
        fast_float
        xxhash
        libdovi
    GIT_REPOSITORY https://github.com/haasn/libplacebo.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_CLONE_FLAGS "--filter=tree:0"
    GIT_SUBMODULES ""
    UPDATE_COMMAND ""
    # VideoPlayerGold patches (2026-11-20): libplacebo-0001 asks the driver only for the queues
    # that are used (31 -> 5 on NVIDIA, ~0.45 s off every player start; FINDINGS F-R1204).
    # Same idempotent shape as mpv.cmake: abort any half-applied am, rewind to the commit the
    # patches were made against (= packages/LOCK.txt), clean, apply. Nothing here watches the
    # recipe, so a run that changes a patch must be dispatched with the custom command
    # `ninja -C build_x86_64_v3 libplacebo-fullclean mpv-fullclean` (FINDINGS line ~9035).
    PATCH_COMMAND ${EXEC} bash -c "cd <SOURCE_DIR> && (git am --abort >/dev/null 2>&1 || true) && git reset --hard 92b5ac6db79f4d680eb656692f7bf51e9606f42a -q && git clean -fdq"
    COMMAND ${EXEC} git am --3way ${CMAKE_CURRENT_SOURCE_DIR}/libplacebo-*.patch
    CONFIGURE_COMMAND ""
    COMMAND bash -c "rm -rf <SOURCE_DIR>/3rdparty/glad"
    COMMAND bash -c "rm -rf <SOURCE_DIR>/3rdparty/fast_float"
    COMMAND bash -c "ln -s ${src_glad} <SOURCE_DIR>/3rdparty/glad"
    COMMAND bash -c "ln -s ${src_fast_float} <SOURCE_DIR>/3rdparty/fast_float"
    COMMAND ${EXEC} CONF=1 meson setup <BINARY_DIR> <SOURCE_DIR>
        --prefix=${MINGW_INSTALL_PREFIX}
        --libdir=${MINGW_INSTALL_PREFIX}/lib
        --cross-file=${MESON_CROSS}
        --default-library=static
        -Dd3d11=enabled
        -Ddebug=true
        -Db_ndebug=true
        -Doptimization=3
        -Dvulkan-registry='${MINGW_INSTALL_PREFIX}/share/vulkan/registry/vk.xml'
        -Ddovi=enabled
        -Dlibdovi=enabled
        -Ddemos=false
    BUILD_COMMAND ${EXEC} ninja -C <BINARY_DIR>
    INSTALL_COMMAND ${EXEC} ninja -C <BINARY_DIR> install
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(libplacebo)
force_meson_configure(libplacebo)
cleanup(libplacebo install)

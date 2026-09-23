# libdovi - the Dolby Vision RPU parser, from quietvoid/dovi_tool.
#
# WHY IT IS HERE
#   libplacebo advertises "Native support for Dolby Vision HDR, including Profile 5 conversion to
#   HDR/PQ or SDR, reading DV side data, and reshaping" - but only when built against libdovi.
#   Its meson option `libdovi` defaults to `auto`, so libplacebo silently builds WITHOUT Dolby
#   Vision whenever the library is simply absent. That is what happened to the shipping mpv.exe:
#   a symbol scan found libplacebo 50 times and libdovi zero times, so every DV file has been
#   playing as its HDR10 base layer with the per-frame metadata discarded.
#
#   For the 63 profile-7/8 files in this library that costs only the dynamic metadata. For the
#   4 profile-5 files it is a correctness bug: profile 5 carries no colour tags at all and its
#   base layer is IPT-PQ-C2, so mpv guesses bt.2020/pq and decodes the wrong colour space.
#
# WHY cargo-c AND NOT THE subrandr PATTERN
#   subrandr ships its own `xtask install`. libdovi does not - its documented build is
#   "cargo install cargo-c; cargo cinstall --release", which is what produces the C header,
#   the static library and the dovi.pc that meson needs in order to find it. cargo-c is
#   installed here rather than in the toolchain because this is the only package that needs it,
#   and `cargo install` is already used in this tree (packages/CMakeLists.txt installs
#   cargo-cache the same way).
#
#   --library-type staticlib matches --default-library=static everywhere else in this toolchain.
ExternalProject_Add(libdovi
    GIT_REPOSITORY https://github.com/quietvoid/dovi_tool.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_CLONE_FLAGS "--filter=tree:0"
    GIT_REMOTE_NAME origin
    GIT_TAG main
    UPDATE_COMMAND ""
    PATCH_COMMAND ""
    # cargo-c pulls in openssl-sys, which needs HOST OpenSSL development headers. The build
    # container has none: "Could not find directory of OpenSSL installation... Make sure you
    # also have the development packages of openssl installed", cargo exit 101. cargo-c ships a
    # vendored-openssl feature for exactly this - it compiles OpenSSL from source instead of
    # looking for a system one. Costs time on the first build only; the result is cached.
    CONFIGURE_COMMAND ${EXEC} LD_PRELOAD= cargo install cargo-c --locked --features=vendored-openssl
    BUILD_COMMAND ${EXEC}
        LD_PRELOAD=
        CARGO_BUILD_TARGET_DIR=<BINARY_DIR>
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
        ${cargo_lto_rustflags}
        cargo cinstall
        --manifest-path <SOURCE_DIR>/dolby_vision/Cargo.toml
        --prefix ${MINGW_INSTALL_PREFIX}
        --libdir ${MINGW_INSTALL_PREFIX}/lib
        --target ${TARGET_CPU}-pc-windows-${rust_target}
        --library-type staticlib
        --release
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(libdovi)
cleanup(libdovi install)

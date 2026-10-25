# ARMv7 build recipe

Pinned source versions: Shairport Sync 5.6.1, NQPTP 1.2.9, and libplist 2.3.0. The container uses a Debian 9 ARMv7 userspace as a compatibility baseline.

Run `./build.sh` from this directory with Docker and ARM emulation available. The build output is written under `build-output/`.

The recipe checks that the executables are ARM ELF files, resolves shared libraries in the build container, and records version output. These checks do **not** prove that every library exists in HTP-1 firmware, that NQPTP and Shairport Sync complete their runtime timing handshake, or that audio routes correctly on physical hardware. Review the generated report before making a release.

# ARMv7 build recipe

Pinned source versions: Shairport Sync 5.6.1, NQPTP 1.2.9, and libplist 2.3.0. The container uses a Debian 9 ARMv7 userspace as a compatibility baseline.

From the repository root, run:

```sh
./addons/airplay/build/build.sh
```

The script builds the binaries, stages them in the canonical `addons/airplay/bin/` and `addons/airplay/lib/` tree, then invokes `tools/pack.sh`. Output and diagnostics are written to `dist/`. You can also run `./tools/pack.sh` after staging binaries manually.

The recipe checks that executables are ARM ELF files, resolves shared libraries in the build container, and records version output. These checks do **not** prove every library exists in HTP-1 firmware, that NQPTP and Shairport Sync complete their runtime timing handshake, or that audio routes correctly on physical hardware. Review the generated report before making a release.

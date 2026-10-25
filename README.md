# htp1-sound

An Olympia add-on repository for the HTP-1. The AirPlay add-on is experimental; a successful CI build does not establish compatibility with physical HTP-1 hardware.

## Repository layout

- `addons/airplay/` is the canonical add-on source tree.
- `addons/airplay/build/` contains the ARMv7/Debian 9 build recipe. Build outputs are generated, not committed.
- `tools/pack.sh` packages and validates the canonical tree into `dist/htp1-addon-airplay-VERSION.tar.gz`.
- `tools/index.sh` updates the root `index.json` using the manifest and a locally available release archive.
- `.github/workflows/build-airplay.yml` uses those same packaging/catalog tools in CI rather than maintaining a second package assembly implementation.

The firmware archive contains one top-level `airplay/` directory with `addon.json`, `bin/`, `etc/`, `units/`, and optional bundled `lib/`. Development build recipes and CI files are not included.

## Local build

Requirements: Docker with ARM emulation, `jq`, `tar`, and `sha256sum` on the host.

```sh
./addons/airplay/build/build.sh
```

This builds the ARMv7 executables, stages them into `addons/airplay/bin/` and `addons/airplay/lib/`, and invokes `tools/pack.sh`. The package and diagnostic reports are written to `dist/`.

To package already-built binaries without rebuilding:

```sh
./tools/pack.sh
```

The packer checks the manifest, required runtime files, executable permissions, expected archive paths, and development-path leakage. It cannot prove runtime library availability on the HTP-1 or test audio playback.

## Build and publish with GitHub Actions

1. Push source to GitHub with Actions enabled.
2. Run **Actions → Build HTP-1 AirPlay addon** or push a commit. CI builds and uploads a diagnostic artifact; ordinary branch builds do not publish a release.
3. Review the package and `BUILD-REPORT.txt` artifact.
4. Update `addons/airplay/addon.json` to the intended SemVer version and commit it to `main`.
5. Create and push the matching tag, for example `v0.1.0` when the manifest says `0.1.0`:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

6. The tag workflow rebuilds the package, verifies that the tag matches the manifest, creates a GitHub Release, then downloads the published archive and runs `tools/index.sh` on `main` to update the catalog checksum and size.

Do not create a release tag until the CI artifact and diagnostic report have been reviewed. A CI build does not establish that firmware libraries, ALSA routing, addon install/remove/upgrade behavior, the Shairport/NQPTP timing handshake, or playback work on an actual HTP-1.

## Catalog generation

After the versioned archive is present in `dist/`, set the repository and release tag and run:

```sh
GITHUB_REPOSITORY=saurus8119/htp1-sound RELEASE_TAG=v0.1.0 ./tools/index.sh
```

This updates the `airplay` entry in `index.json`, preserving other add-on entries, and computes the archive's actual SHA-256 and byte size. The URL is constructed from the repository and release tag. For local testing, use a copy of `index.json` via `INDEX=/path/to/index.json` to avoid overwriting the live catalog file.

## Runtime and release limitations

The build recipe pins Shairport Sync 5.6.1, NQPTP 1.2.9, and libplist 2.3.0. It verifies architecture, dependency resolution inside the build container, and version output. It does not verify every shared library against the installed firmware, the runtime SMI handshake, or physical playback. Test install, enable/disable, source selection, volume/mute, standby, upgrade/rollback, and removal on hardware before treating a release as production-ready.

If this repository remains **private**, the HTP-1 cannot fetch its catalog or release assets anonymously. The catalog and release assets must be accessible to the unit without GitHub authentication, or hosted at another supported public location.

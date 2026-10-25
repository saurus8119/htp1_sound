# htp1-sound

An Olympia addon repository for the HTP-1. The AirPlay addon is experimental and has not yet been tested on physical HTP-1 hardware.

## AirPlay build

The source tree is under `addons/airplay/`. GitHub Actions builds Shairport Sync and NQPTP for ARMv7 in a Debian 9 userspace, checks the resulting executables and shared-library dependencies, then packages the runtime addon as `htp1-addon-airplay-VERSION.tar.gz` with the required single top-level `airplay/` directory.

### Build and publish

1. Push the repository to GitHub with Actions enabled.
2. Open **Actions → Build HTP-1 AirPlay addon** and run the workflow, or push a commit. This creates a diagnostic package artifact; it does not publish a release.
3. To publish, update `addons/airplay/addon.json` to the intended SemVer version and commit it to `main`.
4. Create and push a matching tag, for example `v0.1.0` when the manifest says `0.1.0`:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

5. The tag workflow rebuilds the package through `tools/pack.sh`, creates a GitHub Release with the add-on tarball and checksum, and regenerates `index.json` with `tools/index.sh` from the exact archive metadata.

For a local build, run `addons/airplay/build/build.sh`; it builds the ARM binaries and calls the same `tools/pack.sh airplay` used by CI. To regenerate a catalog from release archives in `dist/`, run `tools/index.sh v0.1.0` with a matching manifest version and archive present.

Do not create a release tag until the build workflow succeeds and its diagnostic artifact has been reviewed. A CI build does not establish that the firmware's runtime libraries, ALSA routing, addon lifecycle, or playback are correct on an actual HTP-1.

## Important repository visibility note

If this repository remains **private**, the HTP-1 cannot fetch its `index.json` or release assets anonymously. For installation through the HTP-1's addon catalog, publish the catalog and release assets at a URL the unit can access without GitHub authentication, or arrange another supported public hosting location.

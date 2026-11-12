# HTPlex release workflow

This describes the two release lanes for the HTP-1 Caldera add-on (user-facing name: HTPlex).

## Package-only release lane

Workflow: `.github/workflows/package-caldera.yml`

Runs for changes under `addons/caldera/**`, `tools/pack.sh`, or versioned HTPlex release notes, unless the same push also changes runtime/build inputs.

For a source/configuration-only change it:

1. Validates the add-on ID, version, and matching release-notes file before packaging.
2. Finds the newest published HTPlex release older than the target version.
3. Downloads that release's installable archive and verifies its published SHA256.
4. Extracts the prior package and overlays the repository-controlled manifest, README, launcher scripts, units, and web files.
5. Preserves the already-built `caldera-music.bin` and `lib/` runtime payload.
6. Calculates fingerprints for the player binary and every regular library/symlink before and after overlay, then checks the packaged archive has the identical fingerprint.
7. Creates the new installable archive and checksum without Docker, QEMU, or the official Caldera installer.
8. Publishes the release, downloads its published assets again, verifies the checksum, updates the HTP-1 catalog, and verifies the catalog URL/checksum/size.

A config or wrapper change therefore repackages the add-on; it does not rebuild Caldera.

## Full ARMv7 runtime rebuild lane

Workflow: `.github/workflows/build-caldera.yml`

Runs on pushes that change any of:

- `addons/caldera/build/**`
- `addons/caldera/bin/caldera-music.bin`
- `addons/caldera/lib/**`

It can also be started manually with `workflow_dispatch`. This is the only lane that builds the ARMv7 installer environment and runs the official Caldera installer under emulation. It then assembles, packages, publishes, and verifies the new runtime package.

If a push changes both runtime inputs and ordinary add-on files, the package-only workflow detects the runtime paths and skips; the full rebuild lane owns that release.

## Release safeguards

- Both lanes use the same concurrency group and do not cancel an active release during publication.
- The versioned release-notes file is checked before an expensive build or package operation.
- The workflow fails if the base archive or checksum is missing or invalid.
- The package-only lane proves the Caldera executable and library payload are unchanged.
- A successful package step alone is not a release. GitHub assets must be published and downloaded again with a valid checksum.
- The catalog is updated only after release-asset verification and is then read back from `origin/main` to verify version, URL, checksum, and size.
- Successful CI verifies the package and publication only. It does not prove installation or playback on the physical HTP-1.

## When to use each lane

| Change | Expected lane |
|---|---|
| Preference/configuration in the launcher | Package-only |
| Service unit, auth script, web page, README, add-on manifest | Package-only |
| Add-on release notes | Package-only |
| Caldera build Dockerfile or installer build script | Full ARMv7 rebuild |
| Replacement Caldera executable or bundled runtime libraries | Full ARMv7 rebuild |
| Deliberate full runtime refresh | Manually run Build HTPlex ARMv7 |

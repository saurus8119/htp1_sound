# Caldera Music — ARMv7 build stage

This directory builds Caldera Music Headless in a Debian 9 ARMv7 environment
matching the HTP-1's 32-bit ARM userspace baseline (glibc 2.24).

The build does not reimplement Caldera's architecture detection. It runs the
official installer unchanged:

```sh
curl -fsSL https://releases.caldera.homes/music/headless/install.sh | bash
```

GitHub Actions uses QEMU and Docker Buildx to execute that installer as ARMv7.
The workflow captures the installer's `~/caldera-music` directory as an
artifact for inspection before wiring it into an HTP-1 service.

This is an initial build-validation stage, not yet an installable HTP-1 addon.
The runtime service and addon manifest will be added after the installer output
and startup requirements have been verified.

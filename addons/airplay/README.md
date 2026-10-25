# HTP-1 AirPlay add-on (experimental)

This add-on packages Shairport Sync 5.6.1 and NQPTP 1.2.9 for the HTP-1's ARMv7 / Debian 9 baseline. The manifest declares `source/1`, the `airplay.service` switch, and the AirPlay input routed to I2S.

## Package

The canonical runtime tree is this directory. Build executables into `bin/shairport-sync`, `bin/nqptp`, and any required bundled shared libraries into `lib/`, then run the repository-level `../../tools/pack.sh` from the repository root (or use `build/build.sh`, which stages and packages automatically).

The firmware archive must have exactly one top-level directory named `airplay/`. Build recipes, CI files, and reports are not part of the firmware archive.

## Audio callbacks

- `bin/start` synchronously calls `/opt/olympia/addon-source start airplay` before playback opens the audio device.
- `bin/volume` translates Shairport's decibel callback to the firmware's normalized volume command and maps the `-144 dB` mute sentinel to the firmware mute command.

These callback assumptions and the complete audio path still require testing against the target firmware and Shairport runtime behavior.

## Test boundary

CI checks source build success, ARM architecture, shared-library resolution in the build container, and version output. It does not prove firmware shared-library compatibility, the NQPTP/Shairport timing handshake, I2S routing, install/remove/upgrade lifecycle, or playback on physical HTP-1 hardware.

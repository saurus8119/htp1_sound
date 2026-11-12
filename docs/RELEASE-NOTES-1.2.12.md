# HTPlex 1.2.12

## Changes

- Restore the Caldera service's real-time FIFO scheduling priority from 60 to 45.

## Preserved behavior

- Keep `CPUSchedulingPolicy=fifo`.
- Keep the existing cgroup placement command unchanged.
- Keep all Caldera launcher preferences unchanged, including `audio.audioBufferMs=100` and `cache.precacheCount=1`.
- Keep the existing ALSA configuration and period behavior unchanged.
- Reuse the existing Caldera ARMv7 executable and bundled libraries.

## Packaging scope

- This is a service-unit and add-on metadata change.
- Use the package-only workflow; do not run Docker, QEMU, or the official Caldera installer.
- The package-only workflow must verify that the Caldera executable and bundled library fingerprints are unchanged.

## Verification

- This change reverts only the 1.2.11 FIFO priority increase for a controlled playback comparison.
- A successful package and release do not prove playback behavior on the physical HTP-1.

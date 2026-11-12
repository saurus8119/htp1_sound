# HTPlex 1.2.11

## Changes

- Increase the Caldera service's real-time FIFO scheduling priority from 45 to 60.

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

- The higher FIFO priority is a test change intended to evaluate startup and track-change stuttering.
- A successful package and release do not prove playback behavior on the physical HTP-1. Test the device before concluding whether priority 60 improves playback.

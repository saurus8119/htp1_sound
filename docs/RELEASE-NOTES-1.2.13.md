# HTPlex 1.2.13

## Changes

- Restore the Caldera service's real-time FIFO scheduling priority from 45 to 60.
- This is a controlled comparison against 1.2.12, following the reported return of playback stuttering and connection interruptions at priority 45.

## Preserved behavior

- Keep `CPUSchedulingPolicy=fifo` and the existing cgroup placement command.
- Keep all Caldera launcher preferences unchanged, including audio buffer and precache settings.
- Keep ALSA configuration unchanged.
- Reuse the existing Caldera ARMv7 executable and bundled libraries; do not run Docker, QEMU, or the official Caldera installer.

## Verification

- Package-only workflow must verify the Caldera executable and bundled library fingerprints are unchanged.
- A successful package and release do not prove playback behavior on the physical HTP-1.

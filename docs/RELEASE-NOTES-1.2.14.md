# HTPlex 1.2.14

## Changes

- Increase Caldera's application-level audio buffer from 100 ms to 200 ms.
- Keep prefetch limited to one upcoming track.

## Preserved behavior

- Keep source-matching sample-rate and channel selection.
- Keep the existing default ALSA device discovery; no ALSA system configuration or period-size settings are changed.
- Keep the service scheduling policy and priority unchanged from 1.2.13.
- Reuse the existing Caldera ARMv7 executable and bundled libraries through the package-only workflow.

## Purpose

This is a focused playback-buffer test intended to reduce startup and track-transition underruns. A larger application buffer can also increase the time before playback begins; the actual result must be checked on the HTP-1.

## Verification

- The package-only workflow must verify the Caldera executable and bundled library fingerprints are unchanged.
- A successful package and release do not prove playback behavior on the physical HTP-1.

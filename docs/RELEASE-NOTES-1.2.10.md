# HTPlex 1.2.10

## Changes

- Remove the explicit `streaming.maxBitrateWiFi=0` preference.
- Remove the explicit `streaming.maxBitrateCellular=0` preference.
- Neither preference is replaced with another value; Caldera's own defaults apply.

## Preserved behavior

- Keep `audio.audioBufferMs=100`.
- Keep `cache.precacheCount=1`.
- Keep automatic/source-matching sample rate and channel selection (`audio.sampleRate=0`, `audio.channels=0`).
- Keep master volume at 100.
- Keep loudness leveling and sweet fades disabled.
- Keep stereo downmix disabled.
- Keep Caldera's default ALSA device discovery and existing service scheduling.

## Packaging scope

- This launcher-preference update reuses the previously published Caldera ARMv7 executable and bundled libraries; it does not rebuild or replace the player runtime.

## Scope

No ALSA system configuration, ALSA period size, disk-cache size limit, service scheduling, input integration, or Caldera binary version is changed.

## Verification

This release is intended to remove the two explicit bitrate overrides from the packaged launcher. Successful ARMv7 build and release checks do not prove playback behavior on the physical HTP-1.

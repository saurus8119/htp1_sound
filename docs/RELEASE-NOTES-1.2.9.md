# HTPlex 1.2.9

## Changes

- **Audio buffering:** set Caldera's `audio.audioBufferMs` preference to `100` (100 ms) as a targeted test for the brief stutter reported when starting a track.
- **Conservative prefetch:** set `cache.precacheCount=1` so Caldera prefetches one upcoming track.

## Preserved behavior

- Keep automatic/source-matching sample rate and channel selection (`audio.sampleRate=0`, `audio.channels=0`).
- Keep master volume at 100.
- Keep loudness leveling and sweet fades disabled.
- Keep Wi-Fi and cellular bitrate limits at 0 and stereo downmix disabled.
- Keep Caldera's default ALSA device discovery and existing service scheduling.

## Storage and ALSA scope

- No disk-cache size limit is changed; Caldera retains its existing default/configured limit.
- No system-wide ALSA configuration, ALSA period size, or HTP-1 storage configuration is changed.
- The HTP-1's available free storage has not been measured.

## Verification scope

This is a player-configuration change packaged for the HTP-1 ARMv7 add-on. Successful build and release checks do not prove playback behavior on the physical HTP-1; track-start behavior and audio stability still require device testing.

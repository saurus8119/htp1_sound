# HTPlex — HTP-1 add-on

This add-on packages the official Caldera ARMv7 headless player under the HTPlex name. The
HTP-1 add-on manager controls the system service lifecycle.

## Plex authorization

On first start, the add-on checks whether Caldera already has a Plex token.
If not, it runs Caldera's built-in `--login` flow and captures its terminal
output in the add-on state directory. The HTPlex add-on page displays that
actual output, including the PIN provided by Caldera. Open
[plex.tv/link](https://plex.tv/link), enter the displayed PIN, and approve
the sign-in.

After authorization, the bundled player saves its token in its normal configuration
file and starts the player. The login flow supplies the network player name `HTPlex` and accepts Caldera's
first output choice, System Default, so the add-on does not pin a specific
ALSA device.

## Audio output and buffering

HTPlex uses Caldera's built-in default ALSA device discovery. It does not force a
device name or override Caldera's audio-device selection.

The launcher sets `audio.audioBufferMs=100` to request a 100 ms player audio
buffer. This is a player preference; it does not change the HTP-1's system-wide
ALSA configuration or force ALSA period sizes.

The existing source-matching preferences remain:
- `audio.sampleRate=0`
- `audio.channels=0`

HTPlex runs as root and has direct access to the HTP-1 ALSA device nodes.

## Music prefetch and disk cache

The launcher sets `cache.precacheCount=1`, asking Caldera to prefetch one
upcoming track. The disk-cache size limit is not overridden; Caldera retains
its own default/configured cache limit. This release does not set a new cache
size or estimate the HTP-1's available storage.

## HTP-1 input integration

The manifest registers HTPlex as a `source/1` input routed to I2S. The
firmware's `addon-source start caldera` command must run synchronously just
before Caldera opens the output for playback. It must not run merely when
the daemon starts, because the daemon remains available while idle.

The playback handoff, volume, and mute integration have not yet been
implemented.

## Persistent configuration

HTPlex's configuration and login state are stored under:

`/var/lib/olympia/addons/caldera/state/.config/caldera-music`

The player binary and its bundled runtime libraries are installed inside the HTPlex add-on
package. The GitHub Actions build obtains those files by running the official
Caldera headless installer in the ARMv7 build environment.

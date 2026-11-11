# Caldera Music — HTP-1 add-on

This add-on packages the official Caldera Music ARMv7 headless player. The
HTP-1 add-on manager controls the system service lifecycle.

## Plex authorization

On first start, the add-on checks whether Caldera already has a Plex token.
If not, it runs Caldera's built-in `--login` flow and captures its terminal
output in the add-on state directory. The Caldera add-on page displays that
actual output, including the PIN provided by Caldera. Open
[plex.tv/link](https://plex.tv/link), enter the displayed PIN, and approve
the sign-in.

After authorization, Caldera saves its token in its normal configuration
file and starts the player. The login flow supplies the player name `Caldera Music` and accepts Caldera's
first output choice, System Default, so the add-on does not pin a specific
ALSA device.

## Audio output

Caldera is left to discover and select its default ALSA output device using
its built-in device discovery. The add-on does not force a device name or
override Caldera's audio-device selection.

Caldera runs as root and has direct access to the HTP-1 ALSA device nodes.

## HTP-1 input integration

The manifest registers Caldera as a `source/1` input routed to I2S. The
firmware's `addon-source start caldera` command must run synchronously just
before Caldera opens the output for playback. It must not run merely when the
daemon starts, because the daemon remains available while idle.

The playback handoff, volume, and mute integration have not yet been
implemented.

## Persistent configuration

Caldera's configuration and login state are stored under:

`/var/lib/olympia/addons/caldera/state/.config/caldera-music`

The binary and its bundled runtime libraries are installed inside the add-on
package. The GitHub Actions build obtains those files by running the official
Caldera headless installer in the ARMv7 build environment.


# Caldera Music — HTP-1 add-on

This add-on packages the official Caldera Music ARMv7 headless player for the
HTP-1. The HTP-1 add-on manager controls the system service lifecycle.

## Audio output

Caldera runs as root, giving it direct access to the HTP-1 ALSA device nodes.
The add-on does not declare an HTP-1 source/input route and does not set an ALSA
device such as `hw:I2S,0`. Caldera is left to enumerate ALSA devices and use its
automatic/System Default output selection.

No AirPlay configuration, routing, or service is shared with this add-on.

## Persistent configuration

Caldera's configuration and login state are stored under:

`/var/lib/olympia/addons/caldera/state/.config/caldera-music`

The binary and its bundled runtime libraries are installed inside the add-on
package. The GitHub Actions build obtains those files by running the official
Caldera headless installer in the ARMv7 build environment.

The add-on package build does not claim successful playback on physical HTP-1
hardware. Audio output and Caldera account authorization still require device
validation.

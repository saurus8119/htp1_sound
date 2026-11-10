# Caldera Music — HTP-1 add-on

This add-on packages the official Caldera Music ARMv7 headless player. The
HTP-1 add-on manager controls the system service lifecycle.

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

The official Caldera Headless 1.1.0 interface currently verified for this
project does not document a playback-start hook or a supported event callback
that can invoke that command. Therefore the input registration is in place,
but the playback handoff is not yet complete. Do not treat the add-on as
playback-ready until a supported Caldera callback is identified and tested.
Volume and mute handoff are also not implemented.

## Persistent configuration

Caldera's configuration and login state are stored under:

`/var/lib/olympia/addons/caldera/state/.config/caldera-music`

The binary and its bundled runtime libraries are installed inside the add-on
package. The GitHub Actions build obtains those files by running the official
Caldera headless installer in the ARMv7 build environment.

A successful package build does not establish successful playback or
authorization on physical HTP-1 hardware.

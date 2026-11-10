# Caldera Music — HTP-1 add-on

This add-on packages the official Caldera Music ARMv7 headless player. The
HTP-1 add-on manager controls the system service lifecycle.

## Audio output

Caldera runs as root and has direct access to the HTP-1 ALSA device nodes.
It is not forced to `hw:I2S,0`; Caldera performs its own ALSA enumeration and
uses its automatic output selection.

The HTP-1's shared DSP playback sink is `default:I2S`. The official HTP-1
receiver add-ons open that PCM explicitly. Caldera's automatic selection must
be checked on the actual HTP-1 to confirm that it selects the shared sink;
the add-on must not silently substitute a different device.

## HTP-1 input integration

The manifest now registers Caldera as a `source/1` input routed to I2S. The
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

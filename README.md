# HTP - Airplay2 

HTP-1 add-on repository for AirPlay 2, using Shairport Sync 5.6.1 and NQPTP 1.2.9 (SMI11). The AirPlay package follows the upstream
`htp1-app/htp1-addons` runtime layout and ALSA/I2S configuration. Hardware
playback still needs testing on the target processor.

## Build and publish

A normal push runs the build and creates two Actions artifacts: `htp1-airplay-package`
(only the installable `.tar.gz` and its checksum) and `htp1-airplay-diagnostics`
(text reports for developers). The Actions artifact itself is a ZIP wrapper;
**the HTP-1 downloads the `.tar.gz` release asset**, never the Actions ZIP.

To publish a corrected release, commit the source with `addons/airplay/addon.json`
set to `0.1.1`, then push tag `v0.1.1`. The tag workflow builds the tarball,
creates a GitHub Release with the tarball and checksum, then updates `index.json`
with the direct release URL, SHA-256, and byte size. It updates the catalog only
after the release exists, avoiding a temporary broken download URL.

The repository and release assets must be public for the HTP-1 to fetch them
without GitHub authentication.

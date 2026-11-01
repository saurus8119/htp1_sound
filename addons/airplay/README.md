# HTP-1 AirPlay addon

AirPlay 2 receiver based on Shairport Sync 5.6.1 and NQPTP 1.2.9 (SMI11), aligned with the
upstream `htp1-app/htp1-addons` implementation. The receiver routes to
`default:I2S`; AirPlay 2 discovery requires Avahi, so the package carries the
Debian 9 ARMHF `avahi-daemon` and `libavahi-core7` packages for offline install.

The CI artifact separates the installable `.tar.gz` and checksum from diagnostic
reports. Only the `.tar.gz` is attached as the release package asset. CI cannot
prove runtime library compatibility or physical playback; hardware validation is
still required.

Release 2.0.34: build and publish the installable HTP-1 addon package.


## Uploading HTPlay-1 diagnostic logs

Run `bin/upload-logs.sh` as root on the HTP-1. It collects only this add-on's
`airplay2.service` (Shairport Sync) and `nqptp-airplay2.service` (NQPTP)
journals from the previous 24 hours, their systemd status, the add-on manifest,
and the active Shairport configuration with credential-like settings redacted.

It deliberately excludes HTP-1 platform logs, kernel messages, general system
inventory, and Avahi logs. The script creates a timestamped archive and uploads
it to `//truenas.local/mnt/Apps`.

The build bundles the Debian 9 ARMHF `smbclient` package and its resolved
runtime dependencies. The install hook installs those packages with the add-on.
The uploader prompts for an SMB username and password, or accepts a blank
username for guest access; credentials are not saved.

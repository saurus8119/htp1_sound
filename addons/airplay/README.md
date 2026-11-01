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


## Uploading diagnostic logs

The package includes `bin/upload-logs.sh`. Run it as root on the HTP-1 to
collect the previous 24 hours of Shairport Sync, NQPTP, and Avahi journal
entries, service status, kernel messages, and basic system information. It
creates a timestamped archive and uploads it to
`//truenas.local/mnt/Apps`.

The script does not change audio configuration or restart services. It prompts
for an SMB username and password, or accepts a blank username for guest access.
Credentials are used only for that upload and are not saved.

The add-on build bundles the Debian 9 ARMHF `smbclient` package and its resolved
runtime dependencies. The install hook installs those packages with the add-on
and verifies that `smbclient` is available. No separate manual package install
is required.

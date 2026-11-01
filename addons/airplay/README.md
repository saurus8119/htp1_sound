# HTPlay-1 AirPlay addon

AirPlay receiver based on Shairport Sync 5.6.1 and NQPTP 1.2.9 (SMI11), with
FFmpeg decoding and SoXR interpolation. The receiver routes to `default:I2S`.

## HTPlay-1 service logs

The add-on captures only these two systemd services to persistent local files:

- `/var/lib/olympia/addons/airplay2/logs/airplay2.log` — Shairport Sync
- `/var/lib/olympia/addons/airplay2/logs/nqptp-airplay2.log` — NQPTP

A dedicated service starts the capture and uploads any logs already present
when HTPlay-1 starts. While it is running, it checks every 60 seconds and
uploads only newly appended log data. If there are no new entries, it does not
create an empty periodic upload. Uploaded log data remains in the local files.

There is deliberately **no shutdown upload**. Stopping HTPlay-1 stops capture;
the next startup uploads the local logs accumulated since the last successful
upload. The upload cursor advances only after the NAS confirms the archive
upload, so a failed upload is retried at the next interval or startup.

Archives are timestamped and uploaded to `//truenas.local/mnt/Apps`. They
contain only HTPlay-1 service logs, the two service status reports, the add-on
manifest, and the active Shairport configuration with credential-like settings
redacted. HTP-1 platform logs, kernel logs, Avahi logs, and general system
inventory are excluded.

The add-on bundles the Debian 9 ARMHF `smbclient` package and its resolved
runtime dependencies. For uploads, set `audio` to the TrueNAS SMB username and
`video` to the SMB password in `etc/htplay1.conf`. The installer restricts
that file to root-only access. The credentials file is never included in a
diagnostic archive.

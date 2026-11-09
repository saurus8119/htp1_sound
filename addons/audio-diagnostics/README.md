# Audio Diagnostics

Standalone HTP-1 addon. Installs independently at `/var/lib/olympia/addons/audio-diagnostics/` and serves its own page at `/addons/audio-diagnostics/`.

Read-only status for HTPlay-1 AirPlay, NQPTP, HTPlay-1 control, log timer, and DLNA UPnP units; reads the last 30 minutes of Shairport Sync and NQPTP journal logs; counts heuristic XRUN/underrun, ALSA recovery, and other error matches; exports a JSON report. API listens on TCP 17823 and accepts private IPv4 LAN peers only.

Does not depend on HTPlay-1, modify Shairport configuration, change ALSA settings, restart services, or change audio routing. Event counts are log-pattern matches, not proof of audible dropouts. Actual target log availability and systemd unit names need confirmation on the HTP-1.

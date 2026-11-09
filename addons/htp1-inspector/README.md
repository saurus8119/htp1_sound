# HTP-1 Inspector

A standalone HTP-1 addon in the documented HTP-1 addon package format. It installs independently of HTPlay-1 and provides two read-only tools:

- **System Monitor:** uptime, aggregate CPU usage, load average, memory, swap, disk capacity, network byte/error counters, and thermal sensors exposed by sysfs.
- **Audio Diagnostics:** AirPlay/NQPTP service state, recent journal entries, and counts of XRUN/underrun, ALSA recovery, and other matched errors. Exports a JSON report.

## Installation model

- Addon ID: `htp1-inspector`.
- Web page: `/addons/htp1-inspector/`.
- Background service: `htp1-inspector.service`, installed and enabled at install/boot.
- Runtime files: `/var/lib/olympia/addons/htp1-inspector/`.
- It does not depend on, modify, or install inside HTPlay-1.

## Safety and limitations

- Does not write audio configuration, restart audio services, change routing, or alter ALSA settings.
- Uses Python 3 standard library and avoids syntax newer than Python 3.5; the HTP-1's actual Python runtime still needs on-device verification.
- API listens on TCP 17822 and rejects non-private/non-loopback IPv4 peers. Browser requests with an Origin header must match the request hostname.
- Log availability depends on journald and the HTP-1's configured logging. Event counts are heuristic matches, not proof of audible dropouts.
- CPU temperature is shown only if the kernel exports a thermal-zone sensor.
- Network counters are cumulative since interface initialization; this version does not infer bitrate.
- The systemd unit and API have passed source/package checks, but have not yet been started on a physical HTP-1. Confirm systemd sandbox support, addon page serving, and actual readings on the target before general release.

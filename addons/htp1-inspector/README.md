# HTP-1 Inspector

A read-only HTP-1 addon with two tools:

- **System Monitor:** uptime, load average, memory, swap, disk capacity, network byte/error counters, and thermal sensors exposed by sysfs.
- **Audio Diagnostics:** AirPlay/NQPTP service state, recent journal entries, and counts of XRUN/underrun, ALSA recovery, and other matched errors. Exports a JSON report.

## Safety and limitations

- Does not write audio configuration, restart services, change routing, or alter ALSA settings.
- Uses Python 3 standard library; intended for the HTP-1 Debian 9 ARMHF image.
- API listens on TCP 17822 and rejects non-private/non-loopback peers. Browser requests with an Origin header must match the request Host.
- Log availability depends on journald and the HTP-1's configured logging. Event counts are heuristic matches, not proof of audible dropouts.
- CPU temperature is shown only if the kernel exports a thermal-zone sensor.
- Network counters are cumulative since interface initialization; this first version does not infer bitrate.

## Build / install

This source tree is a development implementation. Package installation metadata and a target-device validation pass are still required before release.

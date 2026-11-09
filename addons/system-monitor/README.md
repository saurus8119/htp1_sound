# System Monitor

Standalone HTP-1 addon. Installs independently at `/var/lib/olympia/addons/system-monitor/` and serves its own page at `/addons/system-monitor/`.

Read-only metrics: aggregate CPU utilization, load average, uptime, kernel, memory/swap, disk usage, network byte/error counters, and thermal zones exposed by sysfs. API listens on TCP 17822 and accepts private IPv4 LAN peers only.

Does not depend on HTPlay-1, modify audio settings, or control services. Network counters are cumulative, not throughput. CPU temperature is shown only if the kernel exposes a thermal zone. Actual Debian 9 hardware/service startup and UI serving still require HTP-1 validation.

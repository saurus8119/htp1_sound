#!/usr/bin/python3
# HTP-1 Inspector: read-only API for Debian 9 / Python 3.5.
from __future__ import print_function
import json
import os
import re
import shutil
import socket
import subprocess
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

PORT = 17822
MAX_LOG = 120000
UNITS = [
    "airplay2.service", "nqptp-airplay2.service", "htplay1-control.service",
    "minidlna.service", "minissdpd.service", "olympia.service"
]
ERROR_RE = re.compile(r"(xrun|underrun|overrun|alsa:|broken pipe|underrun|recovering|failed|failure|error|timed out|timeout)", re.I)
_LAST_CPU = None

def cpu_usage():
    global _LAST_CPU
    fields = read("/proc/stat").splitlines()[0].split()[1:]
    values = [int(x) for x in fields]
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    total = sum(values)
    result = None
    if _LAST_CPU is not None:
        old_total, old_idle = _LAST_CPU
        delta = total - old_total
        if delta > 0:
            result = round(100.0 * (delta - (idle - old_idle)) / delta, 1)
    _LAST_CPU = (total, idle)
    return result

def run(args, timeout=4):
    try:
        p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.communicate(timeout=timeout)[0]
        return out.decode("utf-8", "replace").strip()
    except Exception as exc:
        try:
            p.kill()
        except Exception:
            pass
        return "unavailable: " + str(exc)

def read(path, default=""):
    try:
        with open(path, "r") as f:
            return f.read()
    except Exception:
        return default

def number(value):
    try:
        return int(value)
    except Exception:
        return None

def system_status():
    mem = {}
    for line in read("/proc/meminfo").splitlines():
        m = re.match(r"([^:]+):\s+(\d+)", line)
        if m:
            mem[m.group(1)] = int(m.group(2)) * 1024
    total = mem.get("MemTotal")
    available = mem.get("MemAvailable", mem.get("MemFree", 0) + mem.get("Buffers", 0) + mem.get("Cached", 0))
    disks = []
    for path in ("/", "/var", "/var/log"):
        try:
            d = shutil.disk_usage(path)
            disks.append({"path": path, "total": d.total, "used": d.used, "free": d.free, "percent": round(100.0*d.used/d.total, 1) if d.total else None})
        except Exception:
            pass
    nets = []
    for line in read("/proc/net/dev").splitlines()[2:]:
        if ":" not in line:
            continue
        name, vals = line.split(":", 1)
        v = vals.split()
        if len(v) >= 9:
            nets.append({"interface": name.strip(), "rx_bytes": number(v[0]), "rx_errors": number(v[2]), "tx_bytes": number(v[8]), "tx_errors": number(v[10]) if len(v)>10 else None})
    temps = []
    for root, dirs, names in os.walk("/sys/class/thermal"):
        for name in names:
            if name == "temp":
                raw = number(read(os.path.join(root, name)).strip())
                if raw is not None:
                    temps.append({"sensor": os.path.basename(root), "celsius": round(raw/1000.0, 1)})
        dirs[:] = []
    load = read("/proc/loadavg").split()
    uptime = read("/proc/uptime").split()
    return {
        "hostname": socket.gethostname(),
        "kernel": run(["uname", "-srmo"]),
        "uptime_seconds": float(uptime[0]) if uptime else None,
        "load_average": load[:3], "cpu_percent": cpu_usage(),
        "memory": {"total": total, "available": available, "used": total-available if total else None,
                   "percent": round(100.0*(total-available)/total, 1) if total else None},
        "swap": {"total": mem.get("SwapTotal", 0), "free": mem.get("SwapFree", 0)},
        "disks": disks, "network": nets, "temperatures": temps,
        "sampled_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

def service_status():
    result = []
    for unit in UNITS:
        state = run(["systemctl", "is-active", unit], 2) or "unknown"
        result.append({"unit": unit, "state": state})
    return result

def journal():
    units = []
    for unit in ("airplay2.service", "nqptp-airplay2.service"):
        units.extend(["-u", unit])
    text = run(["journalctl"] + units + ["--since", "30 minutes ago", "--no-pager", "-o", "short-iso"], 8)
    if text.startswith("unavailable:"):
        text = run(["tail", "-n", "500", "/var/log/syslog"], 4)
    return text[-MAX_LOG:]

def audio_status():
    logs = journal()
    lines = logs.splitlines()
    matches = [line for line in lines if ERROR_RE.search(line)]
    counts = {"xrun": 0, "alsa_recovery": 0, "other_errors": 0}
    for line in matches:
        low = line.lower()
        if "xrun" in low or "underrun" in low or "overrun" in low:
            counts["xrun"] += 1
        elif "alsa:" in low and ("recover" in low or "unexpected state" in low):
            counts["alsa_recovery"] += 1
        else:
            counts["other_errors"] += 1
    return {"services": service_status(), "window": "last 30 minutes",
            "log_lines": len(lines), "matched_events": len(matches),
            "event_counts": counts, "events": matches[-150:], "log": logs}

def private_peer(addr):
    try:
        ip = addr[0]
        return (ip.startswith("10.") or ip.startswith("192.168.") or
                ip.startswith("127.") or
                (ip.startswith("172.") and 16 <= int(ip.split(".")[1]) <= 31) or
                ip.startswith("169.254."))
    except Exception:
        return False

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return
    def send_json(self, data, code=200):
        body = json.dumps(data, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        origin = self.headers.get("Origin")
        if origin and self.origin_allowed(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.end_headers()
        self.wfile.write(body)
    def origin_allowed(self, origin):
        try:
            from urllib.parse import urlparse
            a = urlparse(origin)
            return a.hostname == self.headers.get("Host", "").split(":")[0]
        except Exception:
            return False
    def do_OPTIONS(self):
        if not private_peer(self.client_address) or not self.origin_allowed(self.headers.get("Origin", "")):
            return self.send_json({"error": "forbidden"}, 403)
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", self.headers.get("Origin"))
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
    def do_GET(self):
        if not private_peer(self.client_address):
            return self.send_json({"error": "LAN access only"}, 403)
        if self.headers.get("Origin") and not self.origin_allowed(self.headers.get("Origin")):
            return self.send_json({"error": "origin rejected"}, 403)
        path = self.path.split("?", 1)[0]
        if path == "/api/system":
            return self.send_json(system_status())
        if path == "/api/audio":
            return self.send_json(audio_status())
        if path == "/api/services":
            return self.send_json({"services": service_status()})
        if path == "/api/report":
            return self.send_json({"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                   "system": system_status(), "audio": audio_status()})
        return self.send_json({"error": "not found"}, 404)

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

if __name__ == "__main__":
    server = ThreadedHTTPServer(("0.0.0.0", PORT), Handler)
    server.serve_forever()

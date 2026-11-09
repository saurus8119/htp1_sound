#!/usr/bin/python3
# HTP-1 System Monitor: read-only API; Python 3.5 standard library.
from __future__ import print_function
import json, os, re, shutil, socket, subprocess, time
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

PORT = 17822
_LAST_CPU = None

def read(path, default=""):
    try:
        with open(path, "r") as f: return f.read()
    except Exception: return default

def run(args, timeout=4):
    p = None
    try:
        p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.communicate(timeout=timeout)[0]
        return out.decode("utf-8", "replace").strip()
    except Exception as exc:
        if p:
            try: p.kill()
            except Exception: pass
        return "unavailable: " + str(exc)

def number(value):
    try: return int(value)
    except Exception: return None

def cpu_usage():
    global _LAST_CPU
    lines = read("/proc/stat").splitlines()
    if not lines: return None
    values = [int(x) for x in lines[0].split()[1:]]
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    total = sum(values)
    result = None
    if _LAST_CPU is not None:
        dt, di = _LAST_CPU
        delta = total - dt
        if delta > 0: result = round(100.0 * (delta - (idle-di)) / delta, 1)
    _LAST_CPU = (total, idle)
    return result

def system_status():
    mem = {}
    for line in read("/proc/meminfo").splitlines():
        m = re.match(r"([^:]+):\\s+(\\d+)", line)
        if m: mem[m.group(1)] = int(m.group(2)) * 1024
    total = mem.get("MemTotal")
    available = mem.get("MemAvailable", mem.get("MemFree",0)+mem.get("Buffers",0)+mem.get("Cached",0))
    disks = []
    for path in ("/", "/var", "/var/log"):
        try:
            d = shutil.disk_usage(path)
            disks.append({"path":path,"total":d.total,"used":d.used,"free":d.free,
                          "percent":round(100.0*d.used/d.total,1) if d.total else None})
        except Exception: pass
    nets = []
    for line in read("/proc/net/dev").splitlines()[2:]:
        if ":" not in line: continue
        name, vals = line.split(":",1); v=vals.split()
        if len(v)>=11:
            nets.append({"interface":name.strip(),"rx_bytes":number(v[0]),"rx_errors":number(v[2]),
                         "tx_bytes":number(v[8]),"tx_errors":number(v[10])})
    temps=[]
    root="/sys/class/thermal"
    if os.path.isdir(root):
        for zone in os.listdir(root):
            path=os.path.join(root,zone,"temp")
            raw=number(read(path).strip())
            if raw is not None: temps.append({"sensor":zone,"celsius":round(raw/1000.0,1)})
    load=read("/proc/loadavg").split(); up=read("/proc/uptime").split()
    used=total-available if total is not None else None
    return {"hostname":socket.gethostname(),"kernel":run(["uname","-srmo"]),
      "uptime_seconds":float(up[0]) if up else None,"load_average":load[:3],"cpu_percent":cpu_usage(),
      "memory":{"total":total,"available":available,"used":used,
        "percent":round(100.0*used/total,1) if total and used is not None else None},
      "swap":{"total":mem.get("SwapTotal",0),"free":mem.get("SwapFree",0)},
      "disks":disks,"network":nets,"temperatures":temps,
      "sampled_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())}

def private_peer(addr):
    try:
        ip=addr[0]; p=ip.split(".")
        return (ip.startswith("10.") or ip.startswith("192.168.") or ip.startswith("127.") or
          (ip.startswith("172.") and 16<=int(p[1])<=31) or ip.startswith("169.254."))
    except Exception: return False

class Handler(BaseHTTPRequestHandler):
    def log_message(self,fmt,*args): return
    def send_json(self,data,code=200):
        body=json.dumps(data,separators=(",",":")).encode("utf-8")
        self.send_response(code); self.send_header("Content-Type","application/json; charset=utf-8")
        self.send_header("Content-Length",str(len(body))); self.send_header("Cache-Control","no-store")
        self.send_header("X-Content-Type-Options","nosniff"); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if not private_peer(self.client_address): return self.send_json({"error":"LAN access only"},403)
        path=self.path.split("?",1)[0]
        if path=="/api/system": return self.send_json(system_status())
        if path=="/api/report": return self.send_json({"generated_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"system":system_status()})
        return self.send_json({"error":"not found"},404)

class ThreadedHTTPServer(ThreadingMixIn,HTTPServer):
    daemon_threads=True
    allow_reuse_address=True

if __name__=="__main__":
    ThreadedHTTPServer(("0.0.0.0",PORT),Handler).serve_forever()

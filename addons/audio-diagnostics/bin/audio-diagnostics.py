#!/usr/bin/python3
# HTP-1 Audio Diagnostics: read-only API; Python 3.5 standard library.
from __future__ import print_function
import json, re, socket, subprocess, time
from urllib.parse import urlparse
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

PORT=17823
MAX_LOG=120000
UNITS=["airplay2.service","nqptp-airplay2.service","htplay1-control.service","airplay2-logs.timer","upnp.service"]
ERROR_RE=re.compile(r"(xrun|underrun|overrun|alsa:|broken pipe|recovering|failed|failure|error|timed out|timeout)",re.I)

def run(args,timeout=5):
    p=None
    try:
        p=subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        return p.communicate(timeout=timeout)[0].decode("utf-8","replace").strip()
    except Exception as exc:
        if p:
            try:p.kill()
            except Exception:pass
        return "unavailable: "+str(exc)

def service_status():
    return [{"unit":u,"state":run(["systemctl","is-active",u],2) or "unknown"} for u in UNITS]

def journal():
    args=["journalctl","-u","airplay2.service","-u","nqptp-airplay2.service",
          "--since","30 minutes ago","--no-pager","-o","short-iso"]
    out=run(args,8)
    if out.startswith("unavailable:"): out=run(["tail","-n","500","/var/log/syslog"],4)
    return out[-MAX_LOG:]

def audio_status():
    logs=journal(); lines=logs.splitlines(); matches=[x for x in lines if ERROR_RE.search(x)]
    counts={"xrun":0,"alsa_recovery":0,"other_errors":0}
    for line in matches:
        low=line.lower()
        if "xrun" in low or "underrun" in low or "overrun" in low: counts["xrun"]+=1
        elif "alsa:" in low and ("recover" in low or "unexpected state" in low): counts["alsa_recovery"]+=1
        else: counts["other_errors"]+=1
    return {"services":service_status(),"window":"last 30 minutes","log_lines":len(lines),
      "matched_events":len(matches),"event_counts":counts,"events":matches[-150:],"log":logs}

def private_peer(addr):
    try:
        ip=addr[0]; p=ip.split(".")
        return (ip.startswith("10.") or ip.startswith("192.168.") or ip.startswith("127.") or
          (ip.startswith("172.") and 16<=int(p[1])<=31) or ip.startswith("169.254."))
    except Exception:return False

class Handler(BaseHTTPRequestHandler):
    def log_message(self,fmt,*args):return
    def send_json(self,data,code=200):
        body=json.dumps(data,separators=(",",":")).encode("utf-8")
        self.send_response(code);self.send_header("Content-Type","application/json; charset=utf-8")
        self.send_header("Content-Length",str(len(body)));self.send_header("Cache-Control","no-store")
        self.send_header("X-Content-Type-Options","nosniff")
        origin=self.headers.get("Origin")
        if origin and urlparse(origin).hostname == self.headers.get("Host","").split(":")[0]:
            self.send_header("Access-Control-Allow-Origin",origin)
            self.send_header("Vary","Origin")
        self.end_headers();self.wfile.write(body)
    def do_GET(self):
        if not private_peer(self.client_address):return self.send_json({"error":"LAN access only"},403)
        origin=self.headers.get("Origin")
        if origin and urlparse(origin).hostname != self.headers.get("Host","").split(":")[0]:return self.send_json({"error":"origin rejected"},403)
        path=self.path.split("?",1)[0]
        if path=="/api/audio":return self.send_json(audio_status())
        if path=="/api/services":return self.send_json({"services":service_status()})
        if path=="/api/report":return self.send_json({"generated_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"audio":audio_status()})
        return self.send_json({"error":"not found"},404)

class ThreadedHTTPServer(ThreadingMixIn,HTTPServer):
    daemon_threads=True
    allow_reuse_address=True

if __name__=="__main__":ThreadedHTTPServer(("0.0.0.0",PORT),Handler).serve_forever()

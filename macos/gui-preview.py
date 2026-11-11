#!/usr/bin/env python3
"""WFS macOS GUI Mirror: authenticated, consent-aware manual screen snapshots.

This does not bypass macOS Screen Recording, Accessibility, TCC, SIP, or GUI
login requirements. It uses macOS's own screencapture CLI if allowed.
"""
import argparse
import base64
import hmac
import http.server
import ipaddress
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time

HTML = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>WFS macOS Screen Preview</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#080c14;color:#e5eaf5;font:15px system-ui,-apple-system,sans-serif}
header{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;padding:15px 22px;border-bottom:1px solid #202b3d;background:#111725}
h1{font-size:18px;margin:0}.sub{color:#92a0b9;font-size:12px;margin-top:4px}.status{color:#79dda8;font-size:12px}button{background:#2563eb;color:white;border:0;border-radius:8px;padding:9px 15px;cursor:pointer;font:inherit}button:disabled{opacity:.45;cursor:not-allowed}.actions{display:flex;gap:14px;align-items:center;flex-wrap:wrap}
main{padding:22px;max-width:1480px;margin:auto}.stage{border:1px solid #28374d;background:#020306;border-radius:14px;min-height:350px;display:flex;align-items:center;justify-content:center;overflow:hidden}
img{max-width:100%;max-height:78vh;object-fit:contain}.hint{line-height:1.55;color:#99a9c3;font-size:13px;margin:14px 0}
</style></head><body>
<header><div><h1>WFS macOS · Screen Preview</h1><div class="sub">Private Tailscale · Manual capture · Read-only</div></div><div class="actions"><button id="capture" type="button">Capture one frame</button><span id="status" class="status">Paused · no recording requests</span></div></header>
<main><div class="stage"><img id="frame" alt="Current macOS display screenshot" /></div>
<p class="hint">Capture is paused by default to prevent repeated macOS Screen Recording consent dialogs. Click once only after reviewing any macOS consent request. Captures are limited to one new image per minute. View-only: mouse and keyboard control is NOT supported. Keep this service private to your Tailscale network.</p>
</main>
<script>
const img=document.getElementById('frame'),status=document.getElementById('status');
const button=document.getElementById('capture');
let busy=false;
async function captureOne(){
 if(busy)return;
 busy=true;button.disabled=true;
 status.textContent='Requesting one screenshot…';
 try {
  const result=await fetch('/frame.png?seq='+Date.now(),{cache:'no-store'});
  if(!result.ok)throw new Error('HTTP '+result.status);
  const blob=await result.blob();
  const url=URL.createObjectURL(blob),old=img.dataset.url;
  img.onload=()=>{if(old)URL.revokeObjectURL(old)};
  img.src=url;img.dataset.url=url;
  status.textContent='Frame received · '+new Date().toLocaleTimeString()+' · paused';
 }catch(e){status.textContent='Capture unavailable: '+e.message+' · paused'}
 finally{busy=false;button.disabled=false}
}
button.addEventListener('click',captureOne);
</script></body></html>"""

class Mirror(http.server.ThreadingHTTPServer):
    daemon_threads = True
    def __init__(self, address, handler, username, password, min_interval, frame_file=None):
        super().__init__(address, handler)
        self.username = username
        self.password = password
        self.min_interval = min_interval
        self.frame_file = frame_file
        self.image = None
        self.last_time = 0
        self.lock = threading.Lock()
        self.last_error = "No successful frames yet"
        self.frame_count = 0

    def capture(self):
        with self.lock:
            if self.frame_file is not None:
                try:
                    data = self.frame_file.read_bytes()
                    if not (data.startswith(b"\x89PNG\r\n\x1a\n") and 100 <= len(data) <= 16*1024*1024):
                        raise RuntimeError("Native ScreenCaptureKit frame is not a valid PNG")
                    if self.image != data:
                        self.image = data
                        self.frame_count += 1
                    self.last_error = ""
                    return data
                except (OSError, RuntimeError) as exc:
                    self.last_error = str(exc)
                    raise RuntimeError("Waiting for native ScreenCaptureKit frame and user Screen Recording approval")
            now = time.monotonic()
            if self.image is not None and now - self.last_time < self.min_interval:
                return self.image
            fd, filename = tempfile.mkstemp(prefix="wfs-frame-", suffix=".png")
            os.close(fd)
            os.chmod(filename, 0o600)
            try:
                proc = subprocess.run(
                    ["/usr/sbin/screencapture", "-x", filename],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                    timeout=12, check=False,
                )
                if proc.returncode != 0:
                    raise RuntimeError("macOS screenshot command failed (check session/permissions)")
                data = Path(filename).read_bytes()
                if not (data.startswith(b"\x89PNG\r\n\x1a\n") and 100 <= len(data) <= 16*1024*1024):
                    raise RuntimeError("Screenshot was empty, invalid, or too large")
                self.image = data
                self.last_time = now
                self.frame_count += 1
                self.last_error = ""
                return data
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
                self.last_error = str(exc)
                if self.image is not None and time.monotonic() - self.last_time < 15:
                    return self.image
                raise
            finally:
                try: os.unlink(filename)
                except OSError: pass

class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "WFS-Preview"
    sys_version = ""
    def log_message(self, fmt, *args):
        # Avoid URL tokens or credentials in logs, even if a client misbehaves.
        if self.path.split("?")[0] in ("/", "/health", "/frame.png"):
            pass

    def reply(self, code, body, mime):
        self.send_response(code)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src 'self' blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'")
        self.end_headers()
        self.wfile.write(body)

    def authenticated(self):
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic ") or len(header) > 512:
            return False
        try:
            raw = base64.b64decode(header[6:], validate=True).decode("utf-8")
            user, sep, supplied = raw.partition(":")
            return bool(sep) and hmac.compare_digest(user, self.server.username) and hmac.compare_digest(supplied, self.server.password)
        except (ValueError, UnicodeDecodeError):
            return False

    def do_GET(self):
        if not self.authenticated():
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="WFS macOS Private Preview", charset="UTF-8"')
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        path = self.path.split("?",1)[0]
        if path == "/":
            self.reply(200, HTML.encode(), "text/html; charset=utf-8")
        elif path == "/health":
            status = {"mode":"read_only","frames":self.server.frame_count,"screenshot_ok":self.server.frame_count > 0 and not self.server.last_error,"last_error":self.server.last_error}
            self.reply(200, json.dumps(status).encode(), "application/json")
        elif path == "/frame.png":
            try:
                image = self.server.capture()
                self.reply(200,image,"image/png")
            except (OSError, RuntimeError, subprocess.TimeoutExpired):
                self.reply(503,b"macOS screenshot unavailable or blocked; verify display and GUI session.","text/plain; charset=utf-8")
        else:
            self.reply(404,b"Not found","text/plain")
    def do_POST(self):
        self.reply(405,b"Read-only service. No remote input actions supported.","text/plain")

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host",required=True,help="Tailnet 100.64.0.0/10 IPv4; 127.0.0.1 for smoke test")
    parser.add_argument("--port",type=int,default=6081)
    parser.add_argument("--username",default="wfsremote")
    parser.add_argument("--password-file",required=True,help="0600 file; never expose password in arguments or logs")
    parser.add_argument("--min-interval",type=float,default=60.0)
    parser.add_argument("--frame-file",default=None,help="Private PNG written by persistent ScreenCaptureKit helper; never invokes screencapture")
    args=parser.parse_args()
    host=ipaddress.ip_address(args.host)
    if host.version != 4 or not (host in ipaddress.ip_network("100.64.0.0/10") or host == ipaddress.ip_address("127.0.0.1")):
        parser.error("Mirror can only bind a Tailscale IPv4 or loopback")
    if not 1024<=args.port<=65535 or not 60<=args.min_interval<=3600:
        parser.error("Unsafe port or screenshot interval; at least 60 seconds required to avoid TCC prompt storms")
    file=Path(args.password_file)
    if (file.stat().st_mode & 0o077) != 0:
        parser.error("Password file must not be group/other-readable")
    password=file.read_text(encoding="utf-8").strip()
    if len(password)<12 or ":" in args.username or not args.username:
        parser.error("Password must be 12+ characters; valid username required")
    frame_file = None
    if args.frame_file:
        frame_file = Path(args.frame_file).expanduser().resolve()
        # Private snapshot path is not served as a static directory.
        if (frame_file.parent.stat().st_mode & 0o077) != 0:
            parser.error("Native frame directory must be private (0700)")
    server=Mirror((str(host),args.port),Handler,args.username,password,args.min_interval,frame_file=frame_file)
    print(f"[WFS macOS Preview] Bound {host}:{args.port} as {args.username}; source={'persistent ScreenCaptureKit' if frame_file else 'manual screenshot'}; read-only",flush=True)
    try: server.serve_forever(poll_interval=.4)
    except KeyboardInterrupt: pass
    finally: server.server_close()

if __name__=="__main__":
    main()

#!/usr/bin/env python3
"""WFS macOS Controller (Windows) — Apple VNC control + private WFS preview.

Run only against a Mac you administer, reachable through your Tailscale tailnet.
This tool intentionally DOES NOT inject input on the Mac over SSH, bypass TCC,
disable SIP, or grant permissions. Apple VNC may still refuse control.
Third-party dependency 'macvnc' implements Apple's SetMode(control) handshake.
"""
from __future__ import annotations

import argparse
import base64
import ipaddress
import math
import queue
import struct
import threading
import urllib.error
import urllib.request


def validate_tailnet_ip(value: str) -> str:
    try:
        ip = ipaddress.ip_address(value)
    except ValueError as exc:
        raise ValueError("Use the numeric macOS Tailscale IPv4 address from Actions Summary.") from exc
    if ip not in ipaddress.ip_network("100.64.0.0/10"):
        raise ValueError("Refusing to send credentials outside the private Tailscale IPv4 range.")
    return str(ip)


def display_factor(width: int, height: int, limit_width: int = 920, limit_height: int = 560) -> int:
    if min(width, height, limit_width, limit_height) <= 0:
        raise ValueError("Invalid framebuffer geometry.")
    return max(1, math.ceil(width / limit_width), math.ceil(height / limit_height))


def map_click(
    click_x: int, click_y: int, subsample: int,
    image_width: int, image_height: int, framebuffer_width: int, framebuffer_height: int
) -> tuple[int, int]:
    if subsample < 1 or min(image_width, image_height, framebuffer_width, framebuffer_height) <= 0:
        raise ValueError("Invalid display geometry.")
    # PNG preview and the RFB framebuffer might have different scaling factors.
    px = min(image_width - 1, max(0, click_x * subsample))
    py = min(image_height - 1, max(0, click_y * subsample))
    x = min(framebuffer_width - 1, (px * framebuffer_width) // image_width)
    y = min(framebuffer_height - 1, (py * framebuffer_height) // image_height)
    return x, y


def png_dimensions(image: bytes) -> tuple[int, int]:
    """Validate dimensions of a received screenshot before decoding it in Tk."""
    if (len(image) < 24 or image[:8] != bytes((137, 80, 78, 71, 13, 10, 26, 10))
            or image[12:16] != b"IHDR"):
        raise ValueError("Missing PNG signature/IHDR.")
    width, height = struct.unpack(">II", image[16:24])
    if not (1 <= width <= 8192 and 1 <= height <= 8192 and width * height <= 20_000_000):
        raise ValueError("Unsafe PNG framebuffer dimensions.")
    return width, height


def fetch_frame(ip: str, username: str, password: str, port: int) -> bytes:
    address = f"http://{ip}:{port}/frame.png"
    token = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
    request = urllib.request.Request(
        address,
        headers={"Authorization": "Basic " + token, "Cache-Control": "no-store"}
    )
    # IP is Tailscale-only. No HTTP proxy or credential-forwarding redirects.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with opener.open(request, timeout=18) as response:
        if response.status != 200:
            raise RuntimeError(f"Preview HTTP {response.status}")
        data = response.read(16 * 1024 * 1024 + 1)
    if not (data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) < 16 * 1024 * 1024):
        raise ValueError("Preview returned invalid or oversized PNG.")
    return data


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        raise RuntimeError("Preview redirected: refusing to forward credentials.")


def launch(args: argparse.Namespace) -> None:
    import tkinter as tk
    from tkinter import messagebox, simpledialog, ttk

    try:
        import macvnc  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "Apple VNC client library is missing. Follow macos/WINDOWS_CONTROL.md "
            "to install the pinned, optional third-party dependency."
        ) from exc

    root = tk.Tk()
    root.title("WFS macOS Controller · Apple VNC + Tailscale")
    root.geometry("1080x790")
    root.configure(bg="#111725")

    events: queue.Queue[tuple] = queue.Queue()
    answers: queue.Queue[tuple] = queue.Queue()
    stop = threading.Event()
    state = {
        "width": 0, "height": 0, "fb_width": 0, "fb_height": 0,
        "factor": 1, "connected": False, "connecting": False, "preview_ok": False, "source": ""
    }

    bar = ttk.Frame(root, padding=10)
    bar.pack(fill="x")
    status = tk.StringVar(value="Disconnected. Click Connect to authenticate Apple Screen Sharing.")
    ttk.Label(bar, text="WFS macOS", font=("Segoe UI", 15, "bold")).pack(side="left", padx=(0, 14))
    ttk.Label(bar, textvariable=status).pack(side="left", padx=6)
    body = ttk.Frame(root, padding=(8, 0, 8, 4))
    body.pack(fill="both", expand=True)
    canvas = tk.Canvas(body, width=920, height=560, bg="black", highlightthickness=0)
    canvas.pack(pady=4)
    canvas.create_text(460, 270, text="Use Connect, then Capture one frame.\n"
                       "The captured image is used for coordinate-aligned VNC control.",
                       fill="#d2d7e4", font=("Segoe UI", 12), justify="center")
    canvas.photo = None  # Keep Tk photo alive.
    tools = ttk.Frame(root, padding=10)
    tools.pack(fill="x")
    ttk.Label(tools, text="Keys:").pack(side="left")
    keycombo = tk.StringVar(value="cmd+tab")
    keybox = ttk.Combobox(
        tools, textvariable=keycombo, width=17, state="readonly",
        values=["cmd+tab", "cmd+space", "cmd+c", "escape", "return", "tab", "backspace"]
    )
    keybox.pack(side="left", padx=5)
    ttk.Button(tools, text="Send key", command=lambda: enqueue("key", keycombo.get())).pack(side="left", padx=5)
    input_text = tk.StringVar()
    ttk.Entry(tools, textvariable=input_text, width=36, show="").pack(side="left", padx=(18, 4))
    ttk.Button(tools, text="Type text", command=lambda: enqueue("text", input_text.get())).pack(side="left")
    note = tk.StringVar(value="No input is sent until Connect succeeds and you click/choose an action. "
                                     "A VNC SetMode request is not proof that macOS accepts input.")
    ttk.Label(root, textvariable=note, wraplength=1040, padding=9).pack(fill="x")

    def enqueue(kind: str, *values) -> None:
        if not state["connected"]:
            status.set("Not connected to Apple VNC. Click Connect first.")
            return
        if kind == "text" and (len(values[0]) > 256 or "\n" in values[0]):
            status.set("Text entry is limited to 256 characters and no newlines.")
            return
        events.put((kind, *values))
        if kind == "text":
            input_text.set("")
        status.set("VNC input queued; click Capture one frame to verify it was applied.")

    def on_click(event) -> None:
        if not state["connected"] or not state["preview_ok"]:
            status.set("Connect and capture a preview image before clicking.")
            return
        x, y = map_click(
            event.x, event.y, state["factor"], state["width"], state["height"],
            state["fb_width"], state["fb_height"]
        )
        # A single click is deliberately issued only after the user clicks.
        enqueue("click", x, y)

    canvas.bind("<Button-1>", on_click)

    def background(mac_password: str, preview_password: str):
        try:
            with macvnc.connect(args.ip, args.user, mac_password, args.vnc_port, timeout=15) as client:
                answers.put(("connected", client.width, client.height))
                # libmacvnc sends Apple's SetMode(control). This only requests
                # input rights and does not guarantee that a Mac grants them.
                while not stop.is_set():
                    try:
                        action = events.get(timeout=0.2)
                    except queue.Empty:
                        continue
                    kind = action[0]
                    try:
                        if kind == "quit":
                            return
                        if kind == "frame":
                            image = fetch_frame(args.ip, args.user, preview_password, args.preview_port)
                            answers.put(("frame", "preview", image))
                        elif kind == "vnc_frame":
                            # Same RFB connection as click/key input: diagnose session split.
                            answers.put(("frame", "vnc", client.screenshot()))
                        elif kind == "click":
                            client.click(action[1], action[2])
                            answers.put(("sent", "Click event transmitted, not yet verified by macOS."))
                        elif kind == "key":
                            client.press(action[1])
                            answers.put(("sent", "Key event transmitted, not yet verified by macOS."))
                        elif kind == "text":
                            if action[1]:
                                client.type(action[1])
                                answers.put(("sent", "Text event transmitted; verify on screen."))
                    except Exception as exc:
                        answers.put(("error", type(exc).__name__ + ": " + str(exc)))
        except Exception as exc:
            answers.put(("disconnected", type(exc).__name__ + ": " + str(exc)))

    def connect():
        if state["connected"] or state["connecting"]:
            return
        pwd = simpledialog.askstring("Apple VNC", f"macOS password for {args.user}:", show="*", parent=root)
        if not pwd:
            return
        vpwd = pwd
        if not messagebox.askyesno(
            "WFS Preview password",
            "Does the :6081 browser preview use the SAME password as macOS login?\n\n"
            "Choose No if you started the preview via the SSH launcher with a separate browser password.",
            parent=root
        ):
            vpwd = simpledialog.askstring("Private Preview", "Browser preview password:", show="*", parent=root)
            if not vpwd:
                return
        state["connecting"] = True
        status.set("Connecting via Apple RFB security type 30; requesting control mode…")
        threading.Thread(target=background, args=(pwd, vpwd), daemon=True).start()

    def capture():
        enqueue("frame")

    ttk.Button(bar, text="Connect", command=connect).pack(side="right", padx=6)
    ttk.Button(bar, text="Capture one frame", command=capture).pack(side="right")
    ttk.Button(bar, text="Capture Apple VNC", command=lambda: enqueue("vnc_frame")).pack(side="right", padx=6)

    def poll():
        try:
            while True:
                item = answers.get_nowait()
                if item[0] == "connected":
                    state["connecting"] = False
                    state["connected"] = True
                    state["fb_width"], state["fb_height"] = item[1:3]
                    status.set(f"Apple VNC authenticated ({item[1]}×{item[2]}). "
                               "Control requested; verify with a safe click.")
                elif item[0] == "frame":
                    source, payload = item[1:3]
                    try:
                        width, height = png_dimensions(payload)
                        if source == "vnc" and (width, height) != (state["fb_width"], state["fb_height"]):
                            raise ValueError("VNC framebuffer dimensions changed: reconnect before clicking.")
                        photo = tk.PhotoImage(data=base64.b64encode(payload).decode("ascii"), format="png")
                        if (photo.width(), photo.height()) != (width, height):
                            raise ValueError("Unexpected decoded PNG dimensions.")
                        factor = display_factor(width, height)
                        display = photo.subsample(factor, factor)
                    except (ValueError, tk.TclError) as exc:
                        status.set("Invalid frame: " + str(exc))
                        continue
                    state["width"], state["height"] = width, height
                    state["factor"] = factor
                    state["source"] = source
                    canvas.configure(width=display.width(), height=display.height())
                    canvas.delete("all")
                    canvas.create_image(0, 0, image=display, anchor="nw")
                    canvas.photo = display
                    state["preview_ok"] = True
                    label = "Apple VNC" if source == "vnc" else "Private preview"
                    status.set(f"{label} frame {width}×{height}; click to send one VNC event.")
                    if source == "vnc":
                        note.set("Image and input share one authenticated Apple VNC session. "
                                 "If black while Private preview works, VNC does not see that GUI. "
                                 "Sent input is NOT evidence of control.")
                    else:
                        note.set("Private preview can show a DIFFERENT macOS GUI session than Apple VNC. "
                                 "Images may be cached for 60 seconds. Compare using Capture Apple VNC.")
                elif item[0] == "sent":
                    status.set(item[1])
                elif item[0] == "error":
                    status.set("Operation error: " + item[1])
                elif item[0] == "disconnected":
                    state["connected"] = False
                    state["connecting"] = False
                    state["preview_ok"] = False
                    state["source"] = ""
                    status.set("Apple VNC disconnected: " + item[1])
        except queue.Empty:
            pass
        if not stop.is_set():
            root.after(120, poll)

    def close():
        stop.set()
        events.put(("quit",))
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", close)
    root.after(120, poll)
    root.mainloop()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ip", required=True, help="Current private Tailscale IPv4 of macOS runner")
    parser.add_argument("--user", default="wfsremote", help="macOS account allowed in Remote Management")
    parser.add_argument("--vnc-port", type=int, default=5900)
    parser.add_argument("--preview-port", type=int, default=6081)
    args = parser.parse_args()
    args.ip = validate_tailnet_ip(args.ip)
    if not args.user or ":" in args.user or not 1 <= args.vnc_port <= 65535 or not 1 <= args.preview_port <= 65535:
        parser.error("Invalid user or port.")
    launch(args)


if __name__ == "__main__":
    main()

# Windows controller for WFS macOS — Option A

**Status: experimental.** Screenshot preview has worked on a genuine macOS GitHub Actions runner. Mouse and keyboard input have NOT yet been proven to work on the user's machine.

## Why this controller?

The existing WFS browser screen preview at port 6081 shows Finder and Dock, but Apple Screen Sharing via TigerVNC still shows black. Apple's VNC extension has a control request (SetMode with bytes 0a 00 00 01). A generic viewer might remain in observe-only mode.

The Windows application at [windows/wfs-macos-controller.py](../windows/wfs-macos-controller.py) pairs the private screenshot source on port 6081 with an Apple-specific VNC client on port 5900. It only sends actions that the user explicitly clicks or types, with no SSH command injection or macOS TCC/SIP modifications.

An optional third-party component [bouk/macvnc](https://github.com/bouk/macvnc) supplies Apple RFB security type 30 and SetMode. WFS does not redistribute its source. The upstream repository did not expose a LICENSE at review time; evaluate the code and dependencies before using it. Installation below pins Git commit 7385d6c6105b9565889d95d2cf3a5e606e70ee9d.

## Install on Windows 10/11

Prerequisites: Tailscale, Git for Windows, Python 3.10 or later with tkinter, current macOS runner IP, and working macOS login credentials.

Run these commands in PowerShell. You must explicitly install the optional dependency:

```powershell
py -3 --version
git --version
tailscale status
git clone https://github.com/wawanwfs/RDP.git
cd RDP
py -3 -m venv .wfs-macos-venv
$Python = (Resolve-Path .\.wfs-macos-venv\Scripts\python.exe).Path
& $Python -m pip install --upgrade pip
& $Python -m pip install 'git+https://github.com/bouk/macvnc.git@7385d6c6105b9565889d95d2cf3a5e606e70ee9d'
```

Then run the WFS controller, replacing the IP with the one in the most recent macOS GitHub Actions Summary:

```powershell
$Python = (Resolve-Path .\.wfs-macos-venv\Scripts\python.exe).Path
& $Python .\windows\wfs-macos-controller.py --ip 100.x.x.x --user wfsremote
```

## Actual input acceptance

1. Click **Connect**. Enter the macOS login password for wfsremote. The tool requests Apple type-30 authentication and SetMode(control); macOS could still reject control.
2. Say whether port 6081 uses the same password. If preview was started manually from SSH and has a separate password, select **No** and provide that browser-only password.
3. Click **Capture one frame**. The image appears in the Windows controller with coordinates scaled to the macOS VNC framebuffer.
4. Click **Capture Apple VNC** to request an image from the same authenticated VNC session that carries input. If its framebuffer shows a usable desktop, leave that image selected. The new **Auto-refresh Apple VNC after click/key** option is on by default.
5. Click a harmless item such as **Finder** in the Dock or send **cmd+tab**. In Apple VNC view, the controller automatically fetches another frame after the input and shows whether anything visibly changed. A refreshed image is not proof of authorized input unless the requested desktop change appears.
6. If **Capture Apple VNC** is black but **Capture one frame** shows Finder, the private browser preview and Apple VNC are not equivalent. The private preview is a **static screenshot**, potentially cached for 60 seconds; its visible UI **does not imply that the VNC channel can control it**. After at least 60 seconds, you can recapture and compare, but a lack of control usually points to authorization/GUI-session limits.

**Accept success only when the Finder click causes a visible change.** A connected VNC socket, mouse pointer, or status 'event sent' alone is not sufficient.

**Apple policy limitation:** [Apple's Remote Desktop documentation](https://support.apple.com/en-me/guide/remote-desktop/apd8b1c65bd/mac) explains that Remote Management enabled by `kickstart` on macOS 10.14+ can result in **view-only** Screen Sharing. On macOS 12.1+, `kickstart` cannot enable Screen Sharing. Sending Apple `SetMode(control)` cannot override macOS consent or management policy. Without interactive GUI authorization or approved MDM on a Mac, a GitHub-hosted ephemeral runner might remain view-only. Do not attempt SIP/TCC bypasses.

## Security and limitations

- Both addresses are restricted by the WFS controller to Tailscale IPv4 space 100.64.0.0/10. Do not expose ports 5900 or 6081 publicly.
- Credentials are entered locally in masked dialogs, held in Windows app process memory and not passed to shell commands or GitHub Actions.
- The separate Type text control is unmasked; do not enter private passwords in that field.
- The program refuses HTTP redirects from the preview to avoid forwarding Basic credentials.
- macOS authorization/GUI session restrictions still apply. Neither SetMode nor this tool bypasses Apple privacy permissions.
- This is not yet a fully smooth RDP replacement. Private-preview PNG capture can be cached for 60 seconds; Apple VNC capture is manual but is not limited by the private-preview cache.

On auth error, collect the Windows controller status, the current Mac console account, and Apple Screen Sharing diagnostic logs. See [macOS README](README.md).

## When the screenshot is visible but input is ignored

The known GitHub Actions setup starts Screen Sharing using `macos/workspace.sh` → `kickstart`. This is a significant policy limitation, **not a missing Python click handler**. Apple's documentation explicitly says remote management enabled by this method on modern macOS may grant **view-only**. A Python/VNC client cannot grant macOS permission by itself.

For read-only diagnostics from the **existing macOS SSH connection**, run:

```bash
curl -fsSLo /tmp/wfs-diagnose-vnc.sh https://raw.githubusercontent.com/wawanwfs/RDP/main/macos/diagnose-vnc.sh
bash /tmp/wfs-diagnose-vnc.sh wfsremote
```

The script reports the console account, RFB security negotiation, Remote Management privilege attributes, and summarized recent Screen Sharing key-denial messages. **No password is needed for diagnostics.** A zero denial count does not prove permission: macOS may not log every blocked click.

If both Apple VNC screenshots and previews show Finder, but a `cmd+tab` or Finder click does not change the VNC framebuffer, consider control **not verified / likely view-only**. Do not repeatedly change SIP, TCC databases, or run privileged input-injection scripts: they cannot replace user approval.

### What can actually enable interactive control?

- On a Mac you own with access to its authorized local graphical session: use **System Settings → General → Sharing**, explicitly configure Screen Sharing or Remote Management for the designated account and its control rights. Restart the connection.
- On an organization-managed Mac: use the approved **MDM Enable Remote Desktop** configuration granting the appropriate user rights.
- On a short-lived **GitHub-hosted macOS runner**, neither interactive system-setting approval nor MDM enrollment is generally available through the workflow. Interactive control is therefore **not guaranteed and may be impossible with Option A**. SSH/CLI and read-only screen preview remain workable without misrepresenting them as interactive desktop access.

# WFS Remote Workspaces — Acceptance & Verification Matrix

> Current branch: `main`. Environments: GitHub-hosted temporary runners, not persistent VPS. This document separates **automated tests**, **unattended installation**, **desktop-visible results**, and **external-device acceptance**. Do not call a component production-ready based only on opening a port or downloading an installer.

## 1. Two supported entry points

| System | Run workflow | Default | Remote |
|:--|:--|:--|:--|
| Windows | [Windows Remote Workspace](../.github/workflows/windows-remote-workspace-with-apps.yml) | `windows-2025` | Native `rdp`, user `RDP` |
| Linux | [Linux Remote Workspace](../.github/workflows/linux-remote-workspace.yml) | `ubuntu` + `kde` | Native `xrdp`, user `RDP` |

Both use Tailscale (private tailnet only), `rdp-runner` as default hostname, 1/3/6-hour selected sessions, and GitHub's **360-minute total job cap**. A selected six-hour session can have less than six hours remaining after setup.

## 2. Tested GitHub Actions evidence

| Acceptance area | Evidence | What it proves | What it does not |
|:--|:--|:--|:--|
| Windows MT4 (Exness) | [native Windows install acceptance](https://github.com/wawanwfs/RDP/actions/runs/42924327969) | Official Exness download signed, `MetaTrader 4 EXNESS\terminal.exe` found, hashed | RDP user login, broker login, charts, EA |
| Windows MT5 | [same native Windows run](https://github.com/wawanwfs/RDP/actions/runs/42924327969) | Official MetaQuotes download signed, `MetaTrader 5\terminal64.exe` found, hashed | RDP user login, broker login, charts, EA |
| Windows scripted fallback | [Windows acceptance workflow](../.github/workflows/windows-workspace-checks.yml) | Installer staging and Public Desktop shortcut paths are checked when silent installation fails | A user clicked the installer or accepted the license |
| Linux MT5 Wine | [Linux binary acceptance](https://github.com/wawanwfs/RDP/actions/runs/42844537445) | Wine installed, terminal64.exe and launcher created from MetaQuotes installer | GUI may fail with false debugger dialog on current MT5 builds. Separate X11 smoke test available |
| Linux MT4 Wine | [Linux fallback acceptance](https://github.com/wawanwfs/RDP/actions/runs/42925180890) | Exact state `PENDING_INTERACTIVE`, original setup and desktop shortcut were checked after headless timeout | Does **not** prove MT4 terminal is installed |
| Linux KDE XRDP | [Linux runtime acceptance](https://github.com/wawanwfs/RDP/actions/runs/42925180890) | FreeRDP GUI login starts KDE Plasma/X11 instead of silently falling back to Xfce | External client connection remains unverified |
| Linux KDE/Xfce / Tailscale | [Linux CI](../.github/workflows/linux-workspace-checks.yml) | Test-only native GUI session, HTTPS authentication, Tailscale port forwarding, SSH-free RDP handshake | Successful connection from a separate user's device |

**Linux CI (latest completed integration: 8/8 jobs passed):** [run 42925180890](https://github.com/wawanwfs/RDP/actions/runs/42925180890). Windows native MT4/MT5 tests also passed [run 42924327969](https://github.com/wawanwfs/RDP/actions/runs/42924327969). Both results are installer/runtime evidence, not broker acceptance.

**Linux MT4 status:** the installer offers a **`PENDING_INTERACTIVE`** fallback with a visible `Install MetaTrader 4 (WFS)` desktop icon if Wine's unattended Exness setup does not produce the correct executable. This is **not** equivalent to `INSTALLED`. The isolated GUI installer should be completed only inside the authorized user's remote desktop. A pending result must never be marketed as unattended success.

**Browser precedence:** Linux setup now reuses preinstalled **Chromium** (including KDE Webtop); both extensions are configured under `/etc/chromium/policies/managed/`. Chrome is downloaded only if neither browser exists. [Chromium reuse CI](https://github.com/wawanwfs/RDP/actions/runs/42927094664) shows bundled Chromium selected without Chrome installation. Existing sessions require a new workflow run to pick up the change.

**Current MT5 Linux limitation:** Exness `exness5setup.exe` was tried as unattended alternative but stalled under Wine and did not install. The proven generic MetaQuotes installer remains in place; runtime Wine false debugger alerts cannot be declared fixed by a successful binary check. Open the **MetaTrader WebTerminal (WFS fallback)** menu entry in Chromium for browser-only functionality (no EA/scripts), or choose Windows native RDP for desktop MT5/EA.

## 3. Windows acceptance checklist

- [ ] Start a new [Windows workflow run](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml), `remote_access=rdp`, `metatrader_choice=both`,  `windows_version=windows-2025`.
- [ ] Confirm setup completes. Record real Actions Summary IP, hostname, and app status; do not share any secret.
- [ ] Connect your Windows PC to the same Tailscale tailnet. Run `mstsc`, use run's `100.x.x.x:3389`, username `RDP` and your `RDP_PASSWORD` secret.
- [ ] Verify desktop is not black and both MT4 and MT5 shortcuts appear only when appropriate.
- [ ] Open MT4 and MT5. Verify each program's Help → About identifies the **correct version** (MT4 ≠ MT5).
- [ ] If Summary says **Pending Interactive**, double-click the signed **Install MetaTrader 4/5 (WFS)** shortcut and follow the GUI. Do not call the program installed until the terminal opens.
- [ ] Open Chrome and `chrome://policy`. Verify Cookie-Editor and GoFullPage actual extension presence, not just policy configuration.
- [ ] If selected, verify editor, IDE, AI router, agents, and ArtCraft executables. Check **each** application status in Summary.
- [ ] Stop by cancelling the workflow. Verify the temporary runner terminates; do not assume files persist.

## 4. Linux acceptance checklist

- [ ] Start a new [Linux workflow run](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml) with `distro=ubuntu`, `desktop=kde`, `remote_access=rdp`, `metatrader_choice=both`.
- [ ] Open Actions Summary. Verify selected Webtop image is `lscr.io/linuxserver/webtop:ubuntu-kde` and RDP desktop is KDE X11, **not Xfce**.
- [ ] Connect via Tailscale and `mstsc` as case-sensitive user `RDP`; verify Plasma desktop, panel, window manager, normal mouse/keyboard behavior.
- [ ] In MT5, verify the installed `wfs-mt5` launcher opens the proper terminal.
- [ ] For MT4: if `INSTALLED`, verify `wfs-mt4`; if `PENDING_INTERACTIVE`, use `Install MetaTrader 4 (WFS)` and finish in Wine GUI. `PENDING_INTERACTIVE` is not a pass for unattended install.
- [ ] Test `remote_access=both` separately if needed. XRDP X11 and Selkies web sessions **will be different desktops**, even in one container.
- [ ] Check Chrome/Chromium extension installation after first Chrome profile launch. Browser policy existence alone is insufficient.
- [ ] Do not test live orders/EAs as part of CI. If trading is desired, independently validate the broker in a demo account first.
- [ ] Cancel workflow to stop the session. Back up all work before it ends.

## 5. Commands on a Windows client

```powershell
# Copy the real tailnet IP from the current workflow run; never paste credentials into public logs.
tailscale status
Test-NetConnection 100.x.x.x -Port 3389
mstsc /v:100.x.x.x:3389

# Browser transport is only available for novnc or both.
Test-NetConnection 100.x.x.x -Port 6082
```

## 6. Security, reliability, and limitations

- Only host RDP/web ports bound to loopback or the Tailscale interface, not `0.0.0.0`/public internet; no Funnel/public tunnels for these desktops.
- Windows installer packages require valid Authenticode signatures. Linux MT4 fallback validates a PE header, known official HTTPS source, size and stores a SHA256; this does **not** provide Windows-equivalent Authenticode verification.
- Keep GitHub Secrets (`RDP_PASSWORD`, `VNC_PASSWORD`, `TAILSCALE_AUTH_KEY`) in Actions repository secrets; do not commit or echo them.
- A success code or installer download alone is not a verified application. Check the correct binary for the requested platform and create the shortcut only after verification, except explicitly named **Install ...** fallback shortcuts.
- All installs, extensions, updates, data and login sessions are ephemeral. This setup is unsuitable as a permanent host for unattended real-money trading.
- The Linux ISO guest option is experimental, separate from native non-QEMU desktops, and does not imply verified graphical boot.
- **Current acceptance boundary:** workflow CI can prove installation and server-side graphical checks. Full external-device RDP/noVNC connection, trading GUI, broker authentication and actual EA operation require the authorized user's independent device/session testing.

---

[Root README](../README.md) · [Linux guide](../linux/README.md) · [Windows CI](../.github/workflows/windows-workspace-checks.yml) · [Linux CI](../.github/workflows/linux-workspace-checks.yml)

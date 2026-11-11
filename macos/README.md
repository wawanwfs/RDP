<div align="center">

# 🍎 WFS macOS Remote Workspace

**Native Apple-backed macOS · Tailscale Private Network · SSH · Experimental Screen Sharing**

[![macOS CI](https://img.shields.io/github/actions/workflow/status/wawanwfs/RDP/macos-workspace-checks.yml?branch=main&style=for-the-badge&logo=apple&label=macOS%20CI)](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml)
[![Platform](https://img.shields.io/badge/Platform-macOS%2015%20%2F%2026-111111?style=for-the-badge&logo=apple)](https://github.com/actions/runner-images)
[![Private Network](https://img.shields.io/badge/Network-Tailscale%20Private-242424?style=for-the-badge)](https://tailscale.com)

[**▶ Run WFS macOS Workspace**](https://github.com/wawanwfs/RDP/actions/workflows/macos-remote-workspace.yml) · [**View CI**](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml) · [**Root README**](../README.md)

</div>

---

## 1. What this provides

WFS Remote Workspaces mempunyai **tiga** workflow utama: [Windows RDP](../.github/workflows/windows-remote-workspace-with-apps.yml), [Linux XRDP](../.github/workflows/linux-remote-workspace.yml), dan [macOS native](../.github/workflows/macos-remote-workspace.yml). macOS menggunakan **runner macOS asli dari GitHub** yang di-host di infrastruktur perangkat Apple, **bukan** Docker/Linux yang menyamar sebagai macOS, bukan QEMU, dan bukan instalasi Hackintosh.

| Capability | Supported / limitation |
|:--|:--|
| Genuine macOS | ✅ GitHub-hosted macOS 15/26 pada Apple Silicon / Intel |
| Private Tailnet access | ✅ Tailscale GitHub Action v4 |
| Shell login | ✅ **SSH** pada private Tailscale IPv4 port **2222**, setelah listener diverifikasi |
| macOS desktop | 🧪 **Apple Screen Sharing / VNC** pada port **5900**; GUI interaktif belum dijamin |
| Microsoft RDP / mstsc server | ❌ macOS tidak menyediakan Windows RDP server native |
| Browser noVNC | ❌ Tidak diaktifkan: kompatibilitas macOS Screen Sharing VNC & izin screen recording belum terbukti |
| Docker/QEMU Hackintosh | ❌ Tidak diklaim; bukan mode yang dibangun |
| Safari | ✅ Browser macOS bawaan |
| Chrome | ✅ Hanya gunakan yang sudah tersedia jika ada, tidak diinstal otomatis tanpa perlu |
| VS Code, Codex CLI, Claude Code | ⚙️ Pilihan pemasangan, diperiksa per aplikasi; login AI tetap manual |
| Native MT4/MT5 | ❌ Tidak diklaim — installer Windows/Wine tidak sama dengan aplikasi macOS native |
| MetaTrader WebTerminal | ✅ Browser-only jika dipilih; **tidak** mendukung desktop Expert Advisors |
| Persistent storage/GUI | ❌ Runner sementara; semua data hilang setelah job selesai |
| Apple account / Apple ID | ❌ Tidak diatur; App Store dan login Apple tetap pribadi |

### Why VNC is experimental

### Tested Apple Silicon and Intel SSH login

Pengujian [macOS 15 ARM64 + Intel](https://github.com/wawanwfs/RDP/actions/runs/42965871428) sekarang **3/3 job lulus** (validasi workflow, akun terisolasi, dan login SSH dengan password sebenarnya pada alamat loopback untuk kedua arsitektur). Pembuktian ini belum mencakup koneksi ke Tailscale IP dari perangkat Windows ataupun interaksi grafis VNC. Run [Intel VNC lebih lama](https://github.com/wawanwfs/RDP/actions/runs/42965256465) sempat gagal saat mencoba mereset password akun sistem `runner`; mekanisme itu telah diganti dengan akun baru `wfsremote` dan login lokalnya berhasil diuji.

Pada macOS 12.1 dan lebih baru, Apple membatasi pengaktifan Screen Sharing lewat alat command-line. **Remote Management yang diaktifkan via kickstart dapat hanya view-only**, dan runner GitHub-hosted dapat beroperasi tanpa desktop login grafis yang dapat dikendalikan. Membuka port **5900** atau mengaktifkan service **bukan bukti** layar interaktif. Workflow sekarang memeriksa **header protokol RFB** dari port tersebut, tetapi itu pun bukan bukti login atau kendali grafis. WFS menampilkan status aktual di Actions Summary: `RFB_READY_GUI_CONTROL_UNVERIFIED` atau `UNAVAILABLE`, tidak pernah menjanjikan “VNC READY & fully controllable” berdasarkan TCP saja. **Mode `vnc` akan dihentikan lebih awal** jika layanan tidak menyediakan header RFB, agar waktu runner tidak terbuang. Mode `both` tetap dapat dipakai lewat SSH ketika VNC gagal.

Sumber: [Apple — Remote Management](https://support.apple.com/guide/remote-desktop/enable-remote-management-apd8b1c65bd/mac) · [GitHub macOS runner images](https://github.com/actions/runner-images) · [GitHub macOS runner limits](https://docs.github.com/en/actions/reference/runners/larger-runners).

## 2. Select macOS version

| Input | Default | Choices |
|:--|:--|:--|
| `runner_label` | **macos-15** | macos-15, macos-26, macos-15-intel, macos-26-intel |
| `remote_username` | **wfsremote** | Custom new lowercase macOS account (does not modify `runner`) |
| `remote_access` | **both** | both / ssh / vnc |
| `duration_hours` | **1** | 1, 3, 6 |
| `tailscale_hostname` | **rdp-runner** | Custom lowercase/digits/hyphen |
| `hostname_mode` | **same_each_run** | same_each_run / unique_each_run |
| `password_mode` | **same_from_secret** | same_from_secret / random_each_run |
| `ide_choice` | none | vscode |
| `coding_agent_choice` | none | codex / claude / both |
| `apps_bundle` | none | developer / media / all |
| `trading_choice` | none | webterminal |

**Version guidance:** `macos-15` (Apple Silicon ARM64) adalah baseline. `macos-26` (Apple Silicon ARM64) menggunakan fitur OS lebih baru. Versi `-intel` memakai image Intel yang sah dan dapat diperlukan untuk perangkat lunak x64 lama. Jangan lagi memilih `macos-14`: GitHub Actions telah menghentikan macOS 14 pada 2 November 2026.

**Cost note:** menit runner macOS GitHub Actions bisa memakai tarif/multiplier yang lebih mahal dibanding Linux, tergantung status repository dan paket akun. Pilih 1 jam untuk pengujian awal. Tidak ada proses yang mempertahankan runner melewati batas GitHub Actions.

## 3. Secrets, safety and first-time setup

Anda dapat **menggunakan dua secret yang sudah ada** pada repo Windows/Linux, tanpa membuat password baru:

| GitHub Actions repository secret | Usage |
|:--|:--|
| `TAILSCALE_AUTH_KEY` | Join ephemeral macOS runner ke tailnet yang sama |
| `RDP_PASSWORD` | Password login **akun macOS sementara** dan SSH/VNC (nama secret dipakai ulang, bukan protokol RDP) |

Buka [**Repository → Settings → Secrets and variables → Actions**](https://github.com/wawanwfs/RDP/settings/secrets/actions). `RDP_PASSWORD` minimal **12 byte** tanpa baris baru. Jangan taruh password, API key, Apple ID, atau token di workflow input, issue, dan log publik.

**Security model:** akses SSH memakai port custom **2222** dan konfigurasi `ListenAddress` mengikat hanya pada Tailscale IPv4; login root dimatikan, password authentication hanya untuk akun sementara **`wfsremote`** (atau username pilihan), dan percobaan login dibatasi. Workflow membuat **akun non-admin terpisah** hanya ketika `RUNNER_ENVIRONMENT=github-hosted` serta **tidak mereset password akun sistem `runner`**. Tidak ada pembukaan Funnel, publikasi IP publik, edit database TCC, pelemahan SIP, atau perubahan hak akses sistem yang menyiasati izin Apple.

Jika memilih `password_mode=random_each_run`, password diturunkan dengan **HMAC-SHA256** dari secret asli dan GitHub Run ID, bukan dicetak ke log. Di komputer Windows Anda, hitung dengan Python lokal (yang sudah terpasang) sebagai berikut:

```python
import hmac, hashlib, getpass
secret = getpass.getpass("RDP_PASSWORD secret: ")
run_id = input("GitHub Actions Run ID: ").strip()
password = hmac.new(secret.encode(), f"wfs-macos:{run_id}:remote".encode(), hashlib.sha256).hexdigest()[:24]
print("Temporary macOS login password:", password)
```

Untuk mode `same_from_secret`, gunakan nilai `RDP_PASSWORD` seperti biasa. Ini lebih sederhana untuk percobaan pertama.

## 4. Launch workflow

1. Buka [**WFS macOS Workspace → Run workflow**](https://github.com/wawanwfs/RDP/actions/workflows/macos-remote-workspace.yml) dan pilih branch `main`.
2. Untuk uji awal pilih **macos-15**, **both**, **1 hour**, username **`wfsremote`**, hostname **rdp-runner**, `same_from_secret`, aplikasi `none`. **Jalankan workflow baru dari `main`**, jangan gunakan *Re-run jobs* pada run lama: GitHub memakai SHA lama ketika mengulang run.
3. Baca langkah **Connect macOS runner to private Tailscale** dan **Setup isolated tailnet SSH and/or best-effort Screen Sharing**. Jangan menyimpulkan GUI berhasil hanya karena workflow masuk Keep Alive.
4. Lihat **Actions Summary**: IP Tailscale, username macOS sebenarnya, status SSH, status VNC, dan petunjuk koneksi.
5. Hubungkan perangkat klien ke Tailscale yang sama, lalu uji SSH terlebih dahulu. Jika status VNC menunjukkan port terbuka, uji dengan aplikasi VNC viewer.
6. Klik **Cancel workflow** ketika selesai. File dan aplikasi pada runner akan hilang.

## 5. Connect from Windows 10/11

### A. SSH (recommended / testable)

Buka PowerShell di komputer Windows yang juga tersambung Tailscale:

```powershell
tailscale status
Test-NetConnection 100.x.x.x -Port 2222
ssh -p 2222 wfsremote@100.x.x.x
```

Ganti `100.x.x.x` dan username `wfsremote` dengan yang **benar-benar ada pada Actions Summary**. Password = `RDP_PASSWORD` (atau hasil HMAC per-run). Prompt verifikasi fingerprint host saat pertama kali connect harus diperiksa sebelum disetujui.

SSH bukan desktop. Anda dapat menggunakan shell macOS, git, Homebrew, build tool, dan program terminal dari sini.

### B. Apple Screen Sharing / VNC (experimental)

Dari Windows pasang aplikasi **RealVNC Viewer** atau **TigerVNC Viewer** (klien desktop), lalu buka `100.x.x.x:5900` dari Summary. Dari Mac, gunakan **Finder → Go → Connect to Server** dengan `vnc://100.x.x.x`. Gunakan kredensial akun macOS jika server menawarkan autentikasi tersebut.

Pada macOS modern, VNC viewer pihak ketiga dan Screen Sharing Apple tidak selalu menggunakan mekanisme login yang sama. **Jangan mengira password VNC legacy 8 karakter aktif** karena WFS sengaja tidak memaksakan autentikasi lemah semacam itu. Jika VNC meminta jenis autentikasi yang tidak didukung, menampilkan layar hitam, atau hanya view-only, layanan grafis belum memenuhi acceptance.

### C. Why mstsc, xrdp and noVNC are different

`mstsc` menghubungi RDP (3389). macOS memakai Screen Sharing (5900) dan SSH (2222). **RDP Windows tidak dapat mengakses macOS VNC** tanpa jembatan protokol terpisah, dan tidak ada jembatan tersebut yang diklaim di sini.

## 6. Applications

Aplikasi asli macOS berbeda dari image Windows/Linux. File aplikasi dan CLI bisa dipasang; **jendela GUI aplikasi** tidak dianggap terbukti sebelum sesi grafis yang dapat dikendalikan terverifikasi.

- **Safari** sudah disertakan di macOS, bukan dipasang ulang. Google Chrome boleh tersedia pada runner images; WFS tidak menambah Chrome kedua hanya untuk memenuhi logo browser. Kebijakan ekstensi Chrome di macOS memerlukan pengelolaan enterprise/MDM agar pemaksaan instalasi dapat diandalkan; opsi Cookie-Editor/GoFullPage tidak diklaim otomatis terpasang.
- **VS Code** dipasang opsional dari Homebrew Cask dan harus ditemukan sebagai `Visual Studio Code.app`.
- **Codex/Claude Code** dipasang melalui npm jika dipilih, lalu dicek executable-nya; akun API dan autentikasi tetap diatur sendiri.
- **Xcode, Swift, clang, Python, Git, ffmpeg** hanya diinventarisasi jika bundle diminta. Versi dan ketersediaan tergantung runner image.
- **MetaTrader WebTerminal** tersedia lewat browser di <https://web.metatrader.app/>. WebTerminal **bukan MetaTrader desktop** dan tidak menyediakan EA/script desktop. MT4/MT5 Windows tidak dipasang sebagai aplikasi macOS native.

## 7. Hackintosh vs genuine macOS

Istilah *Hackintosh* biasanya berarti macOS berjalan pada PC non-Apple. **Workflow ini tidak mencoba menjalankan macOS di runner Linux/Windows, tidak menyediakan image, ISO, OpenCore, atau VM yang menyaru sebagai mesin Apple**, karena lisensi macOS membatasi penggunaan pada perangkat Apple. Jika tujuan Anda adalah mencoba antarmuka macOS dari PC Windows, gunakan **runner macOS resmi** melalui SSH/VNC yang memang mendukungnya, atau Mac fisik/hosted Apple Mac yang Anda sewa dan konfigurasikan secara sah.

Sumber: [Apple Software License Agreement for macOS Tahoe](https://www.apple.com/legal/sla/docs/macOSTahoe.pdf).

### Fixed: SSH ready but workflow falsely reports unavailable

[Manual macOS 15 Intel run #43028097147](https://github.com/wawanwfs/RDP/actions/runs/43028097147) revealed a separate **status propagation bug**: Tailscale, temporary user authentication, SSH listener `100.x.x.x:2222`, and a VNC RFB banner all succeeded, yet the workflow ended with `Private SSH unavailable; VNC alone is not a verified login path.` The problem was not the SSH server; the Bash function wrote `WFS_MAC_SSH_STATUS=TCP_READY_LOGIN_NOT_TESTED` to GitHub's `GITHUB_ENV`, which only updates **subsequent steps**, while its `both` availability check still read the old `SKIPPED` value **in the same process**.

**Fix:** `macos/workspace.sh` now updates and exports status variables immediately **and** writes `GITHUB_ENV`. The exact failure mode has a dedicated `status-smoke` test, and [regression CI #43028698293](https://github.com/wawanwfs/RDP/actions/runs/43028698293) passed **3/3 jobs**, including both Apple Silicon and Intel. Full external client SSH and interactive VNC login still require a new manual workflow run.

**After fixing:** start a **new** [macOS workflow](https://github.com/wawanwfs/RDP/actions/workflows/macos-remote-workspace.yml) from the current `main` branch, choose `macos-15-intel`, remote `both`, username `wfsremote`, duration `1`. Do **not** use *Re-run jobs* on the old failure because GitHub reruns the original commit.

### Run #43029810843 — macOS Tailscale step stayed active

[Run #43029810843](https://github.com/wawanwfs/RDP/actions/runs/43029810843) uses **macOS 15 ARM64**, remote `both`, and commit `4a50d2b`. GitHub reports its **Tailscale action is in progress**, while checkout and initial secret/runner validation completed. SSH and Screen Sharing have **not started** in that run. Logs may be unavailable via the GitHub job-log endpoint until the job finishes; do not claim an auth-key, SSH, or VNC failure without those logs.

A separate upstream issue, [tailscale/github-action#315](https://github.com/tailscale/github-action/issues/315), documents the action's macOS-specific `networksetup -setdnsservers Ethernet 100.100.100.100` behavior. It can interfere with the GitHub runner's DNS resolution and cause stalled/cancelled jobs. **This is a plausible risk, not proven to be the precise cause of run #43029810843.**

Mitigations implemented for **new runs**:

1. `macos/tailscale-dns-guard.sh backup` records the existing macOS Ethernet DNS mode before the action. A matching `restore` runs immediately after the action and prints non-sensitive backend/DNS diagnostics. It runs only on ephemeral GitHub-hosted macOS.
2. Tailscale v4 action is limited to a 7-minute step, `tailscale up` to 90 seconds with 1 retry; the client version is pinned to stable `1.104.5` instead of the special `latest` value.
3. The action receives `--accept-dns=false`. The upstream issue notes **this flag alone does not disable the action's macOS DNS override**, so the backup/restore is still necessary.
4. If the step fails or times out, the workflow publishes an explicit unavailable status. No public SSH/VNC ports are opened as a workaround, and there is **no guarantee** the DNS restore runs if the underlying macOS runner loses connection to GitHub entirely.
5. [macOS CI](https://github.com/wawanwfs/RDP/actions/runs/43032166865) passes **3/3 jobs** (static syntax/security + native ARM64/Intel DNS-backup and local SSH-auth checks). It **does not authenticate to the user's Tailscale account**, because CI intentionally has no production tailnet secrets.

**Usage:** cancel the stuck manual run if it remains in progress, then start **a new** [macOS workflow](https://github.com/wawanwfs/RDP/actions/workflows/macos-remote-workspace.yml) from `main`. Do **not** use *Re-run jobs* on a workflow that points to an older commit, as that reruns the old code.

### RealVNC/1Remote: macOS offers Apple authentication but refuses login

A real external SSH + VNC test showed `RFB 003.889` and security types `[30, 33, 36, 35]`, with console user `runner` and remote SSH account `wfsremote`. These are **Apple authentication methods**, including Diffie-Hellman type 30; classic VNC password type `2` is **not offered**. Thus a VNC client supporting only classic password authentication cannot connect, and a valid SSH password does not by itself prove macOS Remote Management authorization. <https://www.iana.org/assignments/rfb>

**Changes for new runs:** The installer now configures Remote Management in separate scoped commands: allow **only specified accounts**, grant `wfsremote` Observe/Control permissions, attempt Screen Sharing group membership if present, restart ARD, and check the account's `dsAttrTypeNative:naprivs` attribute. The Actions Summary includes `Remote Management user grant` and `Console session user`. A recorded privilege attribute is **not** a successful remote login or proof of screen control.

**From Windows:** connect using the current private Tailscale IPv4 and port `5900`, with **Apple username/password authentication**, ideally first in TigerVNC. Test SSH separately on port `2222`. If RealVNC reports an authentication error, try TigerVNC and check the grant status in the *new* run's Summary; do not assume the password is incorrect or enable weak classic 8-character VNC authentication.

**Mac limitation:** Apple states that on macOS 12.1+ full Screen Sharing cannot be enabled through `kickstart`; Remote Management enabled by command line can be restricted to view-only. On GitHub-hosted machines without an authorized GUI/MDM configuration, fully controllable desktop access is **not guaranteed** even if SSH works, the RFB banner is present, and a user permission attribute exists. See [Apple official Remote Management guidance](https://support.apple.com/en-bw/guide/remote-desktop/apd8b1c65bd/mac). To operate macOS GUI reliably, use a managed Apple Mac with Screen Sharing enabled via System Settings or appropriate MDM.

### SSH works but VNC authentication fails — use the read-only diagnostic

If SSH as `wfsremote` works but RealVNC or 1Remote reports **authentication failed**, don't change the working SSH password or open port 5900 on the public internet. SSH and Apple Remote Management use different access rules. The user reported protocol `RFB 003.889`, server security methods `[30,33,36,35]`, and console owner `runner`; classic VNC method 2 was not advertised. A client that supports only legacy VNC password mode cannot authenticate.

**From the currently active macOS SSH session**, download and inspect the repository's [read-only diagnostic](diagnose-vnc.sh), then run it:

```bash
curl -fsSLo /tmp/wfs-diagnose-vnc.sh https://raw.githubusercontent.com/wawanwfs/RDP/main/macos/diagnose-vnc.sh
less /tmp/wfs-diagnose-vnc.sh
bash /tmp/wfs-diagnose-vnc.sh wfsremote
```

It displays the real console owner, ARD `naprivs` attribute, `com.apple.access_screensharing`/SSH group membership, available RFB security methods and Screen Sharing service status. It **never changes permissions, requests a password, or authenticates to VNC**. You can send its output back without sharing any password, SSH key, token or account secret.

Try [TigerVNC Viewer](https://github.com/TigerVNC/tigervnc/releases) from Windows against the current **Tailscale IP** and `::5900` using Apple-compatible username/password mode, not a legacy type-2-only profile. If VNC still refuses access even with an ARD grant, note the Apple-supported limitation: on macOS 12.1+ the `kickstart` command does not enable fully interactive Screen Sharing. Genuine screen control may require authorized configuration through **System Settings** or MDM on a manageable Mac. Do not disable SIP/TCC or enable weaker 8-character legacy VNC passwords as a workaround. See [Apple Remote Desktop guidance](https://support.apple.com/en-bw/guide/remote-desktop/apd8b1c65bd/mac).

### TigerVNC connects but shows a completely black macOS desktop

A real session with **macOS 26.6.1 (Intel)** showed the Apple RFB handshake (`RFB 003.889`, authentication types `30,33,36,35`) and successful SSH, with **console owner `runner` and SSH user `wfsremote`**. TigerVNC no longer showed an authentication error but rendered an entirely **black framebuffer**. This is **not a confirmed working GUI** and may indicate an inactive/locked console session, missing graphical display, or Screen Sharing capture restrictions on a headless hosted runner. See the [GitHub runner display discussion](https://github.com/actions/runner-images/discussions/5730) and [macOS VNC black-screen guidance](https://www.scivision.dev/vncserver-setup-macos/).

The following diagnostic is safe to run **during the same live SSH session**; it does not change the working SSH credentials or any Screen Sharing policy:

```bash
curl -fsSLo /tmp/wfs-diagnose-display.sh https://raw.githubusercontent.com/wawanwfs/RDP/main/macos/diagnose-display.sh
bash -n /tmp/wfs-diagnose-display.sh
bash /tmp/wfs-diagnose-display.sh wfsremote
```

It reports the active console user, WindowServer/Finder/loginwindow process presence, number of CoreGraphics displays, and whether a temporary private screencapture returns image bytes. The private screenshot is deleted immediately; pixel contents are **not** uploaded, retained, or analyzed. A successful capture does **not** prove a non-black VNC framebuffer. A failed capture from `wfsremote` may simply reflect macOS TCC privacy restrictions.

**Low-risk display wake test:** Move the mouse in TigerVNC and wait briefly. From SSH, `caffeinate -u -t 120` requests two minutes of display activity (does not change persistent power settings). If the framebuffer remains black, do not run password-reset, SIP/TCC bypass, `tccutil reset`, or internet scripts that change the system sharing permissions.

If no usable console desktop exists on the GitHub-hosted runner, **a listener on port 5900 and correct ARD group grants cannot create one**. For repeatable controllable GUI access use a genuine Apple-hosted Mac with a logged-in graphical session and System Settings/MDM-approved Screen Sharing. For terminal and development work, keep using SSH or VS Code Remote SSH.

### Console owner is wfsremote but TigerVNC stays black

A live macOS 15.8.2 ARM64 session reported:
- `/dev/console` owner **`wfsremote`** after VNC login
- 1 active CoreGraphics display at **1024×768**; SSH `screencapture` returned PNG bytes
- `WindowServer` and `loginwindow` processes present; **Finder was only running as `runner`, not as `wfsremote`**
- TigerVNC showed only a black screen and pointer

**Therefore the display is not missing**, but its contents and the remote user's GUI bootstrap are not yet verified. VNC can create/show a second virtual session for the authenticated account; this can differ from the original `runner` Finder session. Apple lets Remote Desktop users select whether they see the logged-in user's physical display or their own virtual desktop. [Apple's session-selection explanation](https://support.apple.com/guide/remote-desktop/choose-how-to-control-and-observe-apd4f46319e/mac).

Run the safe [desktop session diagnostic](diagnose-desktop-session.sh) **through the current working SSH**. It checks the GUI bootstrap for `wfsremote`, checks Finder/Dock/SystemUIServer ownership, takes a private temporary screenshot and reports whether sampled pixels are nearly all black, then deletes the screenshot automatically:

```bash
curl -fsSLo /tmp/wfs-session.sh https://raw.githubusercontent.com/wawanwfs/RDP/main/macos/diagnose-desktop-session.sh
bash -n /tmp/wfs-session.sh
bash /tmp/wfs-session.sh wfsremote
```

If the output confirms **`launchctl gui/UID: EXISTS`**, the **console belongs to `wfsremote`**, and **`Finder: NOT RUNNING`**, optionally try to start **only Finder** in the existing user session:

```bash
bash /tmp/wfs-session.sh wfsremote --open-finder
```

Disconnect and reconnect TigerVNC. This command does **not** log the user in, create a GUI bootstrap, reset permissions, restart WindowServer, or alter `runner`'s session; macOS may reject it if the GUI context is incomplete. It is a **diagnostic/remediation experiment, not a guaranteed GUI fix**.

If the screenshot samples are nearly 100% black despite a live GUI session, or Finder exists but VNC remains black, the likely obstacle is an unavailable screen surface or **macOS Remote Management screen-capture permission**. On macOS 12.1+, `kickstart` alone does not guarantee interactive Screen Sharing. Using `launchctl` to start the service does not grant TCC capture permissions. For approved access, configure Screen Sharing via System Settings or device MDM on a genuine Apple host rather than hacking TCC databases. See [Screens black-display troubleshooting](https://help.edovia.com/en-GB/screens-5/troubleshooting/blank-screen) and [Apple Remote Management](https://support.apple.com/guide/remote-desktop/enable-remote-management-apd8b1c65bd/mac).

## 8. Troubleshooting and acceptance gates

| Symptom | Diagnose |
|:--|:--|
| Workflow fails before tailnet | Missing `TAILSCALE_AUTH_KEY` or `RDP_PASSWORD`, disabled hosted runner, unsupported runner label |
| No SSH port 2222 | Check summary SSH status, `tailscale ip -4`, interface binding and tailnet ACLs; do not switch listener to public IP |
| SSH password rejected | Gunakan user `wfsremote` atau nilai `remote_username` dari Summary; periksa mode password/ACL Tailscale, jangan gunakan `runner` atau `RDP` kecuali memang dibuat |
| VNC port open but black screen | macOS GUI is headless/no console login; Screen Sharing can't be made fully interactive by TCP test |
| VNC view-only | Modern Apple Screen Sharing permission restrictions, not necessarily a workflow bug |
| VNC viewer asks incompatible auth | Different native Apple ARD vs legacy VNC login; no legacy authentication forced |
| GUI apps installed but invisible | No usable GUI session; run terminal tools via SSH or use an approved Apple-managed Mac |
| Tailscale connection fails | Key, tags, tailnet ACL, device approval and outbound connectivity |
| Session ended early | GitHub job 360-minute cap includes setup, runner preemption, manual cancel, or billing/runner quota |

**Acceptance levels:** `SSH TCP_READY_AUTH_UNTESTED` confirms a private socket, **not client authentication**. `VNC RFB_READY_GUI_CONTROL_UNVERIFIED` confirms only a listening port, **not a usable interactive macOS desktop**. Full acceptance requires the authorized user to connect from a second tailnet device, log in, open Finder and verify interaction. Avoid entering personal credentials until you trust the session.

## 9. Verification and changes

The [macOS verification workflow](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml) runs Bash/YAML checks on Linux and a **read-only Apple-hosted macOS 15 capability audit**. The audit records real OS/CPU, console user, WindowServer processes and whether screen capture is available. It does not modify TCC/Privacy, enable a public tunnel, or pretend that Screen Sharing was authenticated externally.

For a reliable always-on, fully interactive macOS workstation, use an Apple Mac (local or cloud-hosted) with GUI sharing enabled through authorized Settings/MDM and a persistent network identity. The disposable Actions runner is primarily for temporary builds, CLI tasks, and GUI experiments.

---

[⬅ Main README](../README.md) · [Windows workspace](../.github/workflows/windows-remote-workspace-with-apps.yml) · [Linux workspace](../.github/workflows/linux-remote-workspace.yml) · [GitHub macOS runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

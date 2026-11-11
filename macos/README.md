<div align="center">

# 🍎 WFS macOS Remote Workspace

**Native Apple-backed macOS · Tailscale Private Network · SSH · Experimental Screen Sharing**

[![macOS CI](https://img.shields.io/github/actions/workflow/status/wawanwfs/RDP/macos-workspace-checks.yml?branch=main&style=for-the-badge&logo=apple&label=macOS%20CI)](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml)
[![Platform](https://img.shields.io/badge/Platform-macOS%2015%20%2F%2026-111111?style=for-the-badge&logo=apple)](https://github.com/actions/runner-images)
[![Private Network](https://img.shields.io/badge/Network-Tailscale%20Private-242424?style=for-the-badge)](https://tailscale.com)

[**▶ Run WFS macOS Workspace**](https://github.com/wawanwfs/RDP/actions/workflows/MacOS.yml) · [**View CI**](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml) · [**Root README**](../README.md)

</div>

---

## 1. What this provides

WFS Remote Workspaces mempunyai **tiga** workflow utama: [Windows RDP](../.github/workflows/windows-remote-workspace-with-apps.yml), [Linux XRDP](../.github/workflows/linux-remote-workspace.yml), dan [macOS native](../.github/workflows/MacOS.yml). macOS menggunakan **runner macOS asli dari GitHub** yang di-host di infrastruktur perangkat Apple, **bukan** Docker/Linux yang menyamar sebagai macOS, bukan QEMU, dan bukan instalasi Hackintosh.

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

Pada macOS 12.1 dan lebih baru, Apple membatasi pengaktifan Screen Sharing lewat alat command-line. **Remote Management yang diaktifkan via kickstart dapat hanya view-only**, dan runner GitHub-hosted dapat beroperasi tanpa desktop login grafis yang dapat dikendalikan. Membuka port **5900** atau mengaktifkan service **bukan bukti** layar interaktif. WFS menampilkan status aktual di Actions Summary: `PORT_OPEN_GUI_CONTROL_UNVERIFIED` atau `UNAVAILABLE`, tidak pernah menjanjikan “VNC READY & fully controllable” berdasarkan TCP saja.

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

1. Buka [**WFS macOS Workspace → Run workflow**](https://github.com/wawanwfs/RDP/actions/workflows/MacOS.yml) dan pilih branch `main`.
2. Untuk uji awal pilih **macos-15**, **both**, **1 hour**, hostname **rdp-runner**, `same_from_secret`, aplikasi `none`.
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

**Acceptance levels:** `SSH TCP_READY_AUTH_UNTESTED` confirms a private socket, **not client authentication**. `VNC PORT_OPEN_GUI_CONTROL_UNVERIFIED` confirms only a listening port, **not a usable interactive macOS desktop**. Full acceptance requires the authorized user to connect from a second tailnet device, log in, open Finder and verify interaction. Avoid entering personal credentials until you trust the session.

## 9. Verification and changes

The [macOS verification workflow](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml) runs Bash/YAML checks on Linux and a **read-only Apple-hosted macOS 15 capability audit**. The audit records real OS/CPU, console user, WindowServer processes and whether screen capture is available. It does not modify TCC/Privacy, enable a public tunnel, or pretend that Screen Sharing was authenticated externally.

For a reliable always-on, fully interactive macOS workstation, use an Apple Mac (local or cloud-hosted) with GUI sharing enabled through authorized Settings/MDM and a persistent network identity. The disposable Actions runner is primarily for temporary builds, CLI tasks, and GUI experiments.

---

[⬅ Main README](../README.md) · [Windows workspace](../.github/workflows/windows-remote-workspace-with-apps.yml) · [Linux workspace](../.github/workflows/linux-remote-workspace.yml) · [GitHub macOS runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

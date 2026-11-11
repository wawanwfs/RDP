<div align="center">

# 🖥️ WFS Remote Workspaces

**Windows · Linux · macOS · Private Remote Access · Tailscale · GitHub Actions**

**Deploy a temporary cloud desktop, choose the apps you need, connect privately, and keep the runner alive for the active session.**

[![Windows Workflow](https://img.shields.io/github/actions/workflow/status/wawanwfs/RDP/windows-remote-workspace-with-apps.yml?branch=main&style=for-the-badge&logo=windows&label=Windows)](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml)
[![Windows CI](https://img.shields.io/github/actions/workflow/status/wawanwfs/RDP/windows-workspace-checks.yml?branch=main&style=for-the-badge&logo=windows&label=Windows%20CI)](https://github.com/wawanwfs/RDP/actions/workflows/windows-workspace-checks.yml)
[![Linux CI](https://img.shields.io/github/actions/workflow/status/wawanwfs/RDP/linux-workspace-checks.yml?branch=main&style=for-the-badge&logo=linux&label=Linux%20CI)](https://github.com/wawanwfs/RDP/actions/workflows/linux-workspace-checks.yml)
[![macOS CI](https://img.shields.io/github/actions/workflow/status/wawanwfs/RDP/macos-workspace-checks.yml?branch=main&style=for-the-badge&logo=apple&label=macOS%20CI)](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml)
[![Remote](https://img.shields.io/badge/Remote-RDP%20%7C%20XRDP%20%7C%20SSH%20%7C%20VNC-735DE2?style=for-the-badge)](https://github.com/wawanwfs/RDP/actions)
[![Tailscale](https://img.shields.io/badge/Network-Tailscale%20Private-242424?style=for-the-badge)](https://tailscale.com/)

### ▶️ Choose your remote environment

| 🪟 Windows | 🐧 Linux | 🍎 macOS |
|:---:|:---:|:---:|
| [**▶ Launch Windows**](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml) | [**▶ Launch Linux**](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml) | [**▶ Launch macOS**](https://github.com/wawanwfs/RDP/actions/workflows/MacOS.yml) |
| Windows 2025 | Ubuntu + KDE Plasma | Apple-backed macOS 15 / 26 |
| RDP / noVNC | XRDP / Webtop | SSH + experimental Apple VNC |
| Native Win32 apps | Native Linux apps + Wine | Native macOS tooling |
| [Windows guide ↓](#-windows-remote-workspace) | [Linux guide](linux/README.md) | [**macOS guide**](macos/README.md) |

[**All workflow runs**](https://github.com/wawanwfs/RDP/actions) · [**Repository secrets**](https://github.com/wawanwfs/RDP/settings/secrets/actions) · [**Acceptance matrix**](docs/ACCEPTANCE_MATRIX.md) · [**Linux verification**](https://github.com/wawanwfs/RDP/actions/workflows/linux-workspace-checks.yml) · [**macOS verification**](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml)

</div>

---

## 🧭 Overview

WFS Remote Workspaces menyediakan **tiga workflow utama** yang dikelola dalam satu repository: **Windows, Linux, dan macOS native**. Workflow lama lain masih tersedia di `.github/workflows/` sebagai varian/legacy; gunakan tiga titik masuk resmi di tabel berikut untuk deployment dan pengujian.

| Aspek | 🪟 Windows | 🐧 Linux | 🍎 macOS |
|:--|:--|:--|:--|
| Main workflow | [Windows](.github/workflows/windows-remote-workspace-with-apps.yml) | [Linux](.github/workflows/linux-remote-workspace.yml) | [macOS](.github/workflows/MacOS.yml) |
| Host | GitHub Windows runner | Ubuntu runner + LinuxServer Webtop | **Genuine GitHub Apple macOS runner** |
| Default desktop | Windows | Ubuntu KDE Plasma | macOS 15 / Apple Silicon |
| Access method | **RDP** | **XRDP** | **SSH** + experimental Apple Screen Sharing |
| Browser remote | noVNC option | Selkies Webtop option | No guaranteed browser GUI; native VNC is experimental |
| User default | `RDP` | `RDP` | **`wfsremote`** (isolated non-admin user, independent of `runner`) |
| Tailscale hostname | `rdp-runner` | `rdp-runner` | `rdp-runner` |
| Primary remote port | TCP `3389` | TCP `3389` | SSH TCP `2222`; VNC TCP `5900` |
| Session choice | 1 / 3 / 6 h | 1 / 3 / 6 h | 1 / 3 / 6 h (default **1h** to limit macOS usage cost) |
| Job cap | 360 min total | 360 min total | 360 min total |
| Storage | Ephemeral | Ephemeral | Ephemeral |
| MetaTrader | Native Windows MT4/MT5 | Wine; MT5 GUI compatibility limited | WebTerminal only; no desktop EA |
| CI | [Windows tests](.github/workflows/windows-workspace-checks.yml) | [Linux tests](.github/workflows/linux-workspace-checks.yml) | [Native macOS tests](.github/workflows/macos-workspace-checks.yml) |

> [!IMPORTANT]
> **Runner GitHub bukan VPS permanen.** Ketika job berakhir/dibatalkan, desktop, aplikasi, dan file lokal sementara akan hilang. Jangan menyimpan satu-satunya salinan data, bot, profil browser, akun, atau Expert Advisor di runner. **Jangan gunakan workflow ini untuk trading live tanpa backup dan pengawasan.**

## 🧩 Architecture

```text
                       YOUR DEVICE
        Windows / Android / macOS / Linux
               connected to Tailscale
                          │
                PRIVATE TAILNET
                          │
       ┌──────────────────┼─────────────────┐
       │                  │                 │
  WINDOWS RDP         LINUX XRDP       macOS NATIVE
  Windows runner      Docker Webtop     Apple macOS runner
  :3389 RDP           :3389 XRDP        :2222 SSH
  noVNC optional      Selkies optional  :5900 Screen Sharing*
  native MT4/MT5      Chromium KDE      Safari + CLI tooling
  Windows apps        Wine terminal     WebTerminal browser
       │                  │                 │
       └──────────────────┴─────────────────┘
               GitHub Actions job
            temporary, maximum 360 min
```

* **macOS VNC is not RDP.** A listening VNC port does not prove interactive GUI: modern Apple permissions and GitHub runner headless sessions can prevent screen control. See [macOS limitations and acceptance](macos/README.md). Hackintosh/non-Apple macOS emulation is not offered.

Native Linux Webtop images do not require QEMU; Windows runs natively on its hosted runner, and macOS uses **genuine Apple-backed runners**. Nothing in this diagram represents a persistent VPS.

## 🔐 First-time setup — shared access for all three workflows

1. Pastikan [Tailscale](https://tailscale.com/download) aktif pada PC/HP yang akan digunakan mengakses desktop. Siapkan auth key dari [Tailscale Admin](https://login.tailscale.com/admin/settings/keys) dengan cakupan dan masa berlaku minimum yang diperlukan.
2. Buka **[Settings → Secrets and variables → Actions](https://github.com/wawanwfs/RDP/settings/secrets/actions)** di repository.
3. Tambahkan nama secret **persis** seperti tabel. Simpan **nilai** hanya di GitHub Secrets, jangan di YAML/README.
4. Pilih workflow **Windows / Linux / macOS** → **Run workflow** di branch `main`.
5. Setelah langkah instalasi dan koneksi siap, buka **Actions run → Summary** untuk membaca IP/URL tailnet, port, username, password *mode*, dan status masing-masing aplikasi.
6. Sambungkan melalui klien RDP atau browser. Gunakan **Cancel workflow** untuk mengakhiri sesi lebih cepat.

| GitHub Actions secret | Fungsi | Catatan |
|:--|:--|:--|
| `TAILSCALE_AUTH_KEY` | Menghubungkan runner ke tailnet privat | Dipakai ketiga workflow |
| `RDP_PASSWORD` | Password Windows RDP, Linux XRDP, **dan macOS SSH/VNC user** | macOS mensyaratkan minimal 12 byte; secret dipakai ulang meski protokol bukan RDP |
| `VNC_PASSWORD` | Password remote browser/noVNC Windows/Linux | macOS membuat akun `wfsremote` dengan login dari `RDP_PASSWORD`; VNC legacy password tidak diaktifkan |

**Default akun Windows dan Linux adalah `RDP` kapital.** Linux membedakan `RDP` dan `rdp` sebagai dua akun berbeda. Password tidak diambil dari username, dan nilai secret tidak boleh ditempel di issue, log publik atau screenshot.

**Password mode:** `same_from_secret` mempertahankan password rahasia yang sama pada setiap run. `random_each_run` tersedia di kedua workflow tetapi implementasi pelaporan berbeda; **pada Windows password acak dapat tercetak di Actions log pada repo publik**. Pada Linux password per-run diturunkan dari HMAC-SHA256 secret + Run ID, dan **tidak dicetak**. Untuk Linux, petunjuk perhitungan di PC lokal tersedia di [panduan Linux](linux/README.md).

## 🍎 macOS Workspace — Genuine Apple Silicon / Intel

**Default baru: macOS 15 + akun `wfsremote` + private Tailscale + SSH dan percobaan Screen Sharing (VNC)**. Pilih macOS 26 jika membutuhkan toolchain lebih baru, atau varian Intel jika aplikasi Anda membutuhkan x64. macOS tidak memakai server Microsoft RDP; jangan memakai `mstsc` untuk mengakses port 5900.

| Item | Detail |
|:--|:--|
| **Launch** | [WFS macOS Remote Workspace](https://github.com/wawanwfs/RDP/actions/workflows/MacOS.yml) |
| **Runners** | `macos-15`, `macos-26`, `macos-15-intel`, `macos-26-intel` |
| **Remote mode** | `both` default, atau `ssh`/`vnc`; GUI **eksperimental** |
| **SSH** | `ssh -p 2222 wfsremote@100.x.x.x` di PowerShell Windows, ganti IP/user dari Summary |
| **VNC** | VNC Viewer dari Windows, atau `vnc://100.x.x.x` dari Mac; login/kendali grafis belum dijamin |
| **Apps** | Safari bawaan, opsional VS Code/Codex/Claude, toolchain dan WebTerminal browser |
| **Sesi** | Default **1 jam**, opsi 3/6 jam; total job tetap maksimal 360 menit |
| **Credentials** | Pakai kembali `TAILSCALE_AUTH_KEY` dan `RDP_PASSWORD`; password tidak dicetak |

**Hasil CI macOS:** [3/3 berhasil pada Apple Silicon dan Intel](https://github.com/wawanwfs/RDP/actions/runs/42965871428): workflow, akun remote sementara, dan autentikasi SSH password melalui loopback. Koneksi dari PC Windows tetap perlu diuji di tailnet.

**Batasan penting:** Apple mengendalikan izin Screen Sharing pada macOS modern. GitHub-hosted runner dapat menjalankan proses WindowServer tetapi belum tentu menerima koneksi desktop yang bisa dikendalikan dari VNC viewer. Workflow mencatat **status VNC sebenarnya** dan tidak menonaktifkan SIP, mengubah TCC, atau memaksa autentikasi VNC legacy yang lebih lemah.

Tidak ada opsi Hackintosh VM pada runner Windows/Linux. Mode yang tersedia adalah **macOS resmi di runner Apple**; untuk macOS desktop yang selalu aktif dan bisa dikendalikan penuh, gunakan Apple Mac self-hosted atau penyedia hosted Mac dengan screen sharing yang disetujui.

[Lihat panduan macOS lengkap →](macos/README.md) · [Pengujian native macOS](https://github.com/wawanwfs/RDP/actions/workflows/macos-workspace-checks.yml)

---

## 🐧 Linux Workspace — premium desktop without VM

**Rekomendasi bawaan: Ubuntu Webtop + KDE Plasma + XRDP.** KDE menawarkan tampilan modern; Ubuntu menyediakan jalur paket Wine/MetaTrader dan IDE Linux yang lebih mudah. Browser Webtop dan XRDP KDE menggunakan sesi yang **berbeda**, namun keduanya dapat mengakses container yang sama. Instalasi KDE via X11 berbeda dari desktop Wayland pada browser dan memiliki smoke test tersendiri.

| Distro asli (Webtop container) | KDE Plasma | Xfce | MATE | i3 | LXQt | Catatan XRDP |
|:--|:--:|:--:|:--:|:--:|:--:|:--|
| **Ubuntu — default** | ✅ | ✅ | ✅ | ✅ | ✅ | Desktop X11; direkomendasikan |
| Debian | ✅ | ✅ | ✅ | ✅ | — | Desktop X11 |
| Fedora | ✅ | ✅ | ✅ | ✅ | — | Kebutuhan paket/X11 bervariasi |
| Arch | ✅ | ✅ | ✅ | ✅ | — | Web mode; native XRDP belum diaktifkan |
| Alpine | ✅ | ✅ | ✅ | ✅ | — | KDE Wayland-only untuk browser; XRDP KDE tidak diaktifkan |

Distro native memakai tag [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/), **bukan** VM dan bukan OS Windows yang disamarkan. Opsi ISO eksperimental lama tetap dapat dipilih secara terpisah (`igos-nusantara`) tetapi tidak dijadikan default atau bagian dari matriks native; boot GUI guest belum terverifikasi.

### Default values

| Input Linux | Default | Opsi lain |
|:--|:--|:--|
| `distro` | **`ubuntu`** | debian / fedora / arch / alpine / `igos-nusantara` eksperimen |
| `desktop` | **`kde`** | xfce / mate / i3 / `lxqt` (Ubuntu only) |
| `remote_access` | **`rdp`** | novnc / both |
| `rdp_username` | **`RDP`** | Akun Linux case-sensitive |
| `web_username` | `wfs` | Username web Linux |
| `tailscale_hostname` | `rdp-runner` | Lowercase, digit, tanda `-` |
| `hostname_mode` | `same_each_run` | unique_each_run |
| `duration_hours` | `6` | 1 / 3 |
| `metatrader_choice` | `none` | mt4 / mt5 / both |
| `apps_bundle` | `none` | developer / office / media / all |

### 📈 MetaTrader installation — no fake success status

Saat `metatrader_choice=mt4`, `mt5`, atau `both`, workflow memanggil [`linux/install-metatrader.sh`](linux/install-metatrader.sh) otomatis **setelah XRDP dan browser disiapkan**. Script memakai **MT4 Exness dan MT5 MetaQuotes** pada prefix Wine terpisah. Pemasangan hanya menghitung executable yang benar; **uji jendela MT5** dipisahkan karena build MT5 terbaru dapat memunculkan dialog debugger palsu pada Wine.

- **MT5:** installer `mt5setup.exe /auto` resmi; hanya dinyatakan `INSTALLED` jika `terminal64.exe` yang benar, launcher, dan shortcut ada.
- **MT4:** menggunakan **installer Exness dari tautan resmi**. Pada Wine/Ubuntu, bootstrap MT4 dapat memerlukan GUI sehingga `/auto` bisa berhenti tanpa memasang terminal. Jika demikian, workflow menyimpan installer ke direktori pengguna, membuat shortcut **Install MetaTrader 4 (WFS)** di desktop remote, dan mencatat status **`PENDING_INTERACTIVE`**, bukan `INSTALLED`. Klik shortcut tersebut setelah masuk XRDP dan ikuti wizard. MT4 dinyatakan `INSTALLED` hanya jika `terminal.exe` benar-benar terpasang.
- **Windows:** MT4/MT5 memakai installer Windows native; tidak memerlukan Wine.
- **Linux:** jika Chromium sudah tersedia (termasuk Webtop KDE), workflow **menggunakan Chromium bawaan tanpa mengunduh Chrome**. Cookie-Editor dan GoFullPage dipasang melalui kebijakan Chromium; jika Chrome sudah ada digunakan sebagai alternatif, dan Google Chrome baru diinstal hanya saat tidak ada browser yang didukung. Guest ISO eksperimen tetap menggunakan browser host XRDP, bukan aplikasi di guest.
- **Tidak ada** broker login, password akun trading, EA, atau aktivasi auto-trade yang dilakukan oleh workflow. Pemasangan file bukan bukti terminal benar-benar dapat dipakai trading; buka shortcut dan cek koneksi secara manual.

Installer bisa berstatus `INSTALLED`, `PENDING_INTERACTIVE`, `FAILED`, atau `UNSUPPORTED` per terminal. Bila app opsional gagal, remote tetap disediakan dan penyebabnya tampil di **Actions Summary**. Wine di Alpine tidak didukung oleh tahap ini. Untuk Linux trading terminal terbaik gunakan **Ubuntu**.

### 🪟 Windows MetaTrader — verified installer and interactive recovery

Instalasi Windows sekarang menggunakan **satu script PowerShell yang sama** untuk workflow utama dan CI: [`windows/Install-MetaTrader.ps1`](windows/Install-MetaTrader.ps1). Source MT4 diperoleh dari tautan download Exness, MT5 dari MetaQuotes. Sebelum dieksekusi, **tanda tangan Authenticode** dan sumber installer diverifikasi, lalu installer dijalankan tanpa interaksi jika didukung.

Sukses **hanya** bila terminal yang benar ditemukan di disk: MT4 `terminal.exe` (contoh lokasi CI: `C:\Program Files (x86)\MetaTrader 4 EXNESS\terminal.exe`), MT5 `terminal64.exe` (`C:\Program Files\MetaTrader 5\terminal64.exe`). **Exit code installer bukan satu-satunya penentu hasil**—installer bisa menutup proses induk dengan status nonzero sementara terminal sudah terpasang.

Jika setup otomatis tidak menghasilkan terminal yang benar, script menyalin installer yang sudah diverifikasi ke `C:\ProgramData\WFS-Remote-Workspaces\PendingTrading\` dan membuat shortcut **Install MetaTrader 4 (WFS)** atau **Install MetaTrader 5 (WFS)** di *Public Desktop* untuk dibuka setelah login RDP. Status yang dilaporkan **🟠 Pending Interactive**, **bukan Installed**, sampai pengguna menyelesaikan instalasi. Tidak ada login akun broker atau transaksi otomatis.

**Bukti CI:** [Windows MT4 + MT5 berhasil terpasang dengan file executable terverifikasi](https://github.com/wawanwfs/RDP/actions/runs/42924327969). [Windows verification terbaru](https://github.com/wawanwfs/RDP/actions/workflows/windows-workspace-checks.yml) juga menguji pengamanan fallback. Pengujian ini **tidak** membuktikan keberhasilan logon broker, rendering chart, penggunaan EA, ataupun koneksi dari perangkat eksternal.

### 🧩 MT5 Wine compatibility and reliable browser fallback

Pada pengujian KDE/RDP, **MT5 dapat berhasil terinstal tetapi gagal saat dibuka**, menampilkan `A debugger has been found running in your system`. Laporan MQL5 pada Oktober 2026 menghubungkan gejala ini dengan kompatibilitas **build MT5 terkini dan Wine**, termasuk Wine 9/10. Run pengguna sebelumnya mencatat Wine 10.0. Karena itu penggantian Wine saja **tidak dijadikan klaim perbaikan pasti**.

- Installer Exness MT5 resmi **telah diuji** tetapi mode `/auto` tidak menyelesaikan instalasi di Wine. Jalur otomatis kembali memakai **installer MetaQuotes** yang terbukti menghasilkan executable; **GUI tetap harus diuji terpisah**.
- [`test-metatrader-gui.sh`](linux/test-metatrader-gui.sh) menguji **jendela MT5 sungguhan** di Xvfb. Hasil GUI dipisahkan dari pemeriksaan bahwa `terminal64.exe` ada.
- Jika Wine tidak kompatibel, tersedia menu **MetaTrader WebTerminal (WFS fallback)** yang membuka terminal berbasis browser di Chromium. Ini tidak mendukung EA desktop.
- Untuk kebutuhan **MetaTrader 5/MetaEditor/EA desktop**, workflow **Windows RDP native** tetap jalur dengan kompatibilitas paling baik dan instalasi MT4/MT5 yang sudah terverifikasi; login dan EA harus diuji sebelum penggunaan sungguhan.

**Browser premium Linux:** Chromium bawaan Webtop KDE diprioritaskan. CI telah membuktikan Chromium `156.0.8078.73` digunakan kembali tanpa memasang Chrome tambahan. Status browser terpilih dan tindakan instalasi dicatat dalam Actions Summary.

### 📦 Application selection

| Menu | Windows | Linux |
|:--|:--|:--|
| IDE | VS Code, Antigravity | VS Code / Antigravity Linux (jika tersedia) |
| Video | CapCut, Shotcut | Shotcut; CapCut native **unsupported** |
| Trading | MT4, MT5 | MT4, MT5 lewat Wine + pemeriksaan binary |
| AI Router | 9Router, OmniRoute | 9Router, OmniRoute jika dependensi tersedia |
| Coding | Codex CLI, Claude Code | Codex CLI, Claude Code |
| Agents | Hermes, OpenClaw, OpenCode | Hermes, OpenClaw, OpenCode |
| Creative | ArtCraft Launcher | ArtCraft Launcher dengan dukungan paket distro |
| Bundle | Paket aplikasi opsional | Developer / Office / Media / All |
| Browser wajib | Chrome + extensions | **Chromium bawaan lebih diutamakan**, Cookie-Editor dan GoFullPage; tanpa Chrome ganda |

**Catatan:** memilih aplikasi berarti **meminta** pemasangan, bukan menjamin aplikasi lolos. Periksa status masing-masing aplikasi di Summary. Ekstensi Chromium/Chrome diunduh ketika profil browser pertama dibuka dan jaringan ke Chrome Web Store tersedia; verifikasi di `chrome://extensions`.

### 🔌 How to connect

**RDP/XRDP — Windows PC:** `Win + R` → `mstsc` → alamat `100.x.x.x:3389` dari Summary → pengguna `RDP` → password secret. Pastikan Tailscale PC menyala. Untuk RDP Linux, pilih sesi **Xorg** di menu XRDP bila ditampilkan.

**Browser remote — Windows/Android:** pilih `remote_access=novnc` atau `both`, lalu buka URL **yang benar-benar dicetak di Summary**. Webtop Linux memakai `https://100.x.x.x:6082/` pada fallback TLS self-signed atau domain tailnet HTTPS 443 jika diaktifkan. Windows noVNC memakai jalur `/vnc.html` pada transport yang dipilih. Jangan menganggap port HTTPS/Linux sama dengan Windows HTTP/noVNC.

## 🧪 Quality gates & honest status

| Evidence | Kegunaan | Batasan |
|:--|:--|:--|
| [Windows CI](https://github.com/wawanwfs/RDP/actions/workflows/windows-workspace-checks.yml) | YAML/PowerShell static checks; signed native MT4/MT5 installer execution, terminal or pending-UI verification | Installer acceptance is not broker/GUI acceptance |
| [Linux CI](https://github.com/wawanwfs/RDP/actions/workflows/linux-workspace-checks.yml) | Bash syntax, YAML, security assertions, Webtop HTTPS, RDP/Xorg smoke tests | Per-run results can change; check latest HEAD |
| Default KDE XRDP smoke | Login FreeRDP dan proses KDE X11 | Tidak menjamin setiap GPU/klien remote sama |
| Debian Xfce smoke | Verifikasi baseline dan kompatibilitas | Tidak membuktikan semua distro/desktop |
| Linux MT4 Wine test | Original Exness installer, 32-bit Wine runtime, and pending-GUI verification | No unattended MT4 installation claimed when terminal.exe is missing |
| Wine status per terminal | Pemeriksaan executable MT4 atau MT5 yang terpasang | Tidak membuktikan login broker, chart rendering, EA, atau runtime uptime |
| [Windows workflow](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml) | Full Windows setup, app installs, session dashboard | Lihat log dan Summary run aktual |

Status `Remote READY` berarti layanan pada runner telah diperiksa. **Bukan** jaminan perangkat eksternal berhasil login. Status `INSTALLED` Wine memeriksa file terminal, bukan penyelesaian UI/trading end-to-end.

## 🔒 Networking, session lifecycle, and safety

- RDP dan web diakses **hanya dari tailnet pribadi** sesuai ACL/grants; tidak menggunakan Tailscale Funnel atau akses publik langsung.
- Linux Webtop Docker bind pada loopback runner, dan forwarder hanya pada alamat IPv4 Tailscale. Windows membatasi RDP melalui firewall/Tailscale.
- Hindari password lemah; gunakan auth key Tailscale minimal privilege. Jangan membuka port 3389/5900/6082 ke internet publik atau mengunggah screenshot credential.
- **1/3/6 jam** adalah pilihan durasi sesi. Batas total workflow **360 menit sejak job dimulai**, sehingga setup mengurangi waktu tersisa. Keep Alive bekerja selama runner masih berjalan.
- Klik **Cancel workflow** untuk menutup sesi. Cleanup menghapus container dan file rahasia sementara sebatas yang dapat dibersihkan sebelum job dihentikan.
- Jika run gagal, cek **job yang gagal**, bukan hanya status hasil akhir; paket GUI/Wine besar dapat melebihi waktu setup pada hosted runner.

## 🆘 Quick troubleshooting

| Gejala | Cek |
|:--|:--|
| `RDP` user doesn't exist | Gunakan huruf kapital; periksa langkah XRDP PAM dan kesesuaian `rdp_username` |
| Login sukses tetapi blank/black | Lihat `/home/RDP/.wfs-xrdp-session.log`, hasil smoke desktop terpilih dan paket X11 |
| KDE tidak tampil / malah Xfce | Pastikan run menggunakan commit terbaru; lihat `WFS_RDP_DESKTOP_READY` di Summary |
| MetaTrader tidak tampak | Periksa step **Install selected MetaTrader** dan baris `INSTALLED/FAILED` per terminal |
| MT4 malah MT5 | Verifikasi sumber instalasi broker dan executable `terminal.exe` yang sesuai |
| NoVNC tidak membuka URL | Pastikan memilih `novnc`/`both`, Tailscale terhubung, baca URL aktual |
| Tailscale connect timeout | Cek `TAILSCALE_AUTH_KEY`, ACL/grants, status node serta rute tailnet |
| `RDP`/port tidak terbuka | Uji `Test-NetConnection 100.x.x.x -Port 3389` dari PowerShell |
| Sesi tiba-tiba berhenti | Lihat batas 360 menit, log Keep Alive, Cancel/timeout status |

Untuk panduan Linux yang lebih mendalam, password per-run dan detail paket, baca **[`linux/README.md`](linux/README.md)**. Rincian workflow Windows ada di bagian selanjutnya.

---

## 🪟 Windows Remote Workspace

## ✨ Ringkasan

WFS Windows Remote Workspace menggunakan **GitHub-hosted Windows runner sementara** untuk menyiapkan desktop serta aplikasi pilihan Anda. Sambungkan perangkat ke tailnet yang sama menggunakan **Tailscale**, lalu akses melalui Microsoft Remote Desktop, browser noVNC, atau keduanya.

| Fitur | Detail |
|:--|:--|
| 🖥️ Mode | `rdp`, `novnc`, atau `both` |
| 🔐 Jaringan | Tailscale privat; tanpa tunnel publik |
| 🌐 noVNC | TCP `6082` atau HTTPS `443`; **auto-fit browser** dan auto-connect pada run baru |
| ⏳ Durasi | Pilihan `1`, `3`, atau `6` jam setelah setup, tetap tunduk pada batas job total `360` menit |
| 🔎 Verifikasi | Pemeriksaan HTTP, WebSocket, dan handshake RFB/VNC |
| 🧹 Penutupan | Logout Tailscale saat selesai, dengan penanganan cleanup best-effort |

> [!IMPORTANT]
> **Ini bukan VPS/komputer permanen.** Runner dan isinya dapat hilang ketika Actions selesai, gagal, dibatalkan, atau mencapai batas platform. Simpan pekerjaan penting ke storage/repository terpisah. Status setup `success` belum membuktikan browser dari PC lain dapat terhubung.

## 🧭 Arsitektur dan port

```text
                         GitHub Actions • Windows runner
                                       │
                                Windows desktop
                      ┌────────────────┴────────────────┐
                      │                                 │
                RDP (jika dipilih)               TightVNC Server
                TCP 3389 / tailnet              127.0.0.1:5900
                      │                                 │
                      │                           websockify/noVNC
                      │                           127.0.0.1:6081
                      │                                 │
                      │                      Tailscale Serve (pilih SATU)
                      │                       ├─ TCP 6082 (HTTP)
                      │                       └─ HTTPS 443 (*.ts.net)
                      │                                 │
                      └────────────────┬────────────────┘
                                       │
                             Perangkat di tailnet yang sama
```

| Port | Komponen | Visibilitas |
|:--|:--|:--|
| `3389/TCP` | Windows RDP | Hanya dibuka melalui firewall untuk IP tailnet saat mode `rdp`/`both` |
| `5900/TCP` | TightVNC (RFB) | **Loopback lokal** |
| `6081/TCP` | websockify / noVNC web UI | **Loopback lokal** |
| `6082/TCP` | Tailscale Serve TCP | Pilihan default noVNC, hanya lewat tailnet |
| `443/TCP` | Tailscale Serve HTTPS | Alternatif noVNC, membutuhkan HTTPS/sertifikat tailnet yang sudah tersedia |
| `6080` | HTTP direct lama | **Tidak digunakan lagi** |

**Tidak perlu membuka port 5900/6081 ke internet atau membuat port forwarding router.** Untuk noVNC, workflow hanya mengonfigurasi **salah satu** dari `6082` atau `443` pada satu run. Server websockify dijalankan lewat Windows Scheduled Task agar tetap berjalan setelah langkah instalasi selesai.

## 🔐 Persiapan: Secrets

Buka **[Settings → Secrets and variables → Actions](https://github.com/wawanwfs/RDP/settings/secrets/actions)**, lalu buat repository secrets sesuai mode:

| Secret | Kapan dibutuhkan | Fungsi |
|:--|:--|:--|
| `TAILSCALE_AUTH_KEY` | **Selalu** | Menghubungkan Windows runner ke tailnet |
| `RDP_PASSWORD` | Jika `rdp_password_mode=same_from_secret` (default) | Password akun Windows `RDP` |
| `VNC_PASSWORD` | Jika noVNC digunakan dan `vnc_password_mode=same_from_secret` (default) | Password autentikasi VNC |

> [!WARNING]
> Nama secret Tailscale yang **benar adalah `TAILSCALE_AUTH_KEY`**, bukan `TS_AUTHKEY`. Jangan tempelkan nilai secret ke README, issue, atau log yang dibagikan. Mode `random_each_run` untuk password VNC mencetak password di log Actions; **log repo publik dapat dibaca umum**. Gunakan secret tetap untuk penggunaan yang lebih aman. VNCAuth klasik hanya memakai **8 byte pertama** password.

## 🚀 Menjalankan workflow

1. Instal/login **[Tailscale](https://tailscale.com/download)** pada PC Windows 10/11 Anda, pastikan berada pada tailnet yang sama dengan auth key runner.
2. Buka **[Windows Remote Workspace with Apps](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml)** → **Run workflow** → pilih branch `main`.
3. Pilih `windows_version` (disarankan `windows-2025`), lalu `remote_access`: `rdp`, `novnc`, atau `both`.
4. Pilih `duration_hours`: `1`, `3`, atau `6` (default), serta aplikasi/IDE yang ingin dipasang.
5. Untuk noVNC, pilih `novnc_transport=tailscale_tcp` (default). Mode `tailscale_https` memerlukan HTTPS Certificates dan MagicDNS aktif pada tailnet; jika setup/sertifikat HTTPS gagal, workflow akan mencoba otomatis **fallback ke TCP privat 6082**.
6. Klik **Run workflow**, buka run tersebut, dan lihat **Summary** untuk hostname, IP, URL noVNC aktual, serta petunjuk password. Gunakan **URL dari run yang sedang aktif**, bukan URL sesi sebelumnya.

**Pilihan utama pada formulir Actions**

| Input | Pilihan penting | Default |
|:--|:--|:--|
| `windows_version` | `windows-latest`, `windows-2025`, `windows-2022`, `windows-11-arm`, `windows-2025-vs2026` | `windows-2025` |
| `remote_access` | `rdp` / `novnc` / `both` | `rdp` |
| `duration_hours` | `1` / `3` / `6` | `6` |
| `hostname_mode` | `same_each_run` / `unique_each_run` | `same_each_run` |
| `rdp_password_mode` / `vnc_password_mode` | `same_from_secret` / `random_each_run` | `same_from_secret` |
| `novnc_transport` | `tailscale_tcp` / `tailscale_https` | `tailscale_tcp` |

**Catatan:** mode noVNC tidak didukung pada runner Windows ARM64 dalam workflow ini; pilih runner x64 untuk `novnc` atau `both`. Label `windows-2025-vs2026` mungkin tidak tersedia untuk semua jenis repository.

## 🖥️ Cara masuk ke workspace

<details>
<summary><strong>Opsi A — Microsoft Remote Desktop (RDP)</strong></summary>

Pastikan `remote_access=rdp` atau `both` dan PC Anda tersambung ke Tailscale.

1. Tekan `Win + R` → ketik `mstsc` → Enter.
2. Isi **Computer** dengan hostname Tailscale atau IP `100.x.x.x` yang tercantum pada Actions Summary.
3. Login dengan username `RDP` dan password sesuai `rdp_password_mode`.
4. Port yang digunakan adalah TCP `3389` melalui Tailscale; **bukan** RDP yang dipublikasikan ke internet.

</details>

<details>
<summary><strong>Opsi B — noVNC dari browser (disarankan untuk akses web)</strong></summary>

Pastikan `remote_access=novnc` atau `both`. Buka **alamat aktual yang dicetak pada Summary** dari perangkat yang sudah terhubung ke tailnet:

| Transport | Format URL | Catatan |
|:--|:--|:--|
| `tailscale_tcp` | `http://100.x.x.x:6082/vnc.html#resize=scale&autoconnect=1` | **HTTP** pada port 6082; lalu autentikasi VNC |
| `tailscale_https` | `https://nama-host.tailnet.ts.net/vnc.html#resize=scale&autoconnect=1` | **HTTPS** via Tailscale Serve port 443 jika berhasil diuji; jika gagal gunakan URL HTTP 6082 dari Summary |

Halaman noVNC **mencoba terkoneksi otomatis** ketika dibuka (password VNC tetap diminta jika diperlukan). Jika memilih `tailscale_https` tetapi sertifikat/izin Tailscale Serve belum siap, workflow akan menonaktifkan konfigurasi HTTPS yang gagal, lalu mengaktifkan **TCP 6082**. Summary mencantumkan **Requested transport**, **Active transport**, dan **HTTPS fallback** (bila terjadi), sehingga jangan mengasumsikan HTTPS aktif sebelum melihat URL aktual. **Jangan** mengganti `http://` menjadi `https://` pada port `6082`: layanan HTTP tersebut tetap dilindungi enkripsi antar-node Tailscale, bukan port publik.

noVNC mengakses **sesi console Windows**, yang dapat berbeda dari desktop user pada sesi RDP. Keberhasilan membuka HTML tidak otomatis berarti koneksi WebSocket atau layar VNC sudah berfungsi.

</details>

## 🖼️ Wallpaper dan layar browser otomatis

**Penyebab wallpaper hitam teridentifikasi:** TightVNC memasang `RemoveWallpaper=1` secara default, yang menyembunyikan wallpaper saat VNC tersambung. Workflow sekarang memasang `VALUE_OF_REMOVEWALLPAPER=0` dan memverifikasi registry serta servis setelah instalasi. Tampilan tetap dapat berbeda antara sesi console dan sesi RDP.

Workflow terbaru mencoba menggunakan **wallpaper bawaan Windows** jika wallpaper belum disetel dan tidak lagi memaksakan opsi visual "best performance". Ini *best effort*: wallpaper mungkin tetap gelap jika console yang dilihat berbeda dari profil Windows yang diubah. Jika ingin mengganti secara manual, di desktop remote pilih **klik kanan → Personalize → Background → Picture**.

**Skala tampilan otomatis:** noVNC menggunakan `resize=scale` agar gambar desktop mengikuti ukuran browser. Run terbaru memperbaiki logika resolusi Windows: karena proses Actions tidak memiliki display aktif, workflow **membuat Scheduled Task yang mencoba pengaturan 16:9 setelah login interaktif Windows** (`1920×1080`, `1600×900`, `1366×768`, atau `1280×720` yang tersedia). Jika sudah ada pengguna console aktif, task juga dicoba segera. Hasil perubahan aktual dicatat di `C:\ProgramData\RDP-Setup\wfs-display-resolution.log`. **Ini bukan jaminan driver virtual runner mendukung resolusi tersebut**; jika gagal, resolusi asli tetap digunakan dan menu Windows Display Settings masih dapat dipakai manual. Fullscreen browser tetap memerlukan klik atau F11.

**Layar penuh:** noVNC tidak dapat otomatis mengambil kontrol fullscreen browser tanpa interaksi pengguna. Gunakan **F11** di browser atau ikon **Full screen** pada toolbar noVNC. Untuk mengubah pengaturan secara manual: **noVNC → Settings → Scaling mode → Local scaling**.

Jika ingin mengubahnya pada koneksi yang **sudah berjalan**, cukup tambahkan fragment berikut setelah `vnc.html` di address bar (tanpa membuat ulang runner):

```text
#resize=scale&autoconnect=1
```

Refresh halaman jika perlu; Anda akan diminta autentikasi VNC lagi bila sesi baru memerlukannya. Pengaturan otomatis dari workflow hanya berlaku untuk **run baru** setelah perubahan di GitHub.

## 🔬 Verifikasi di Actions

Untuk mode noVNC, jalur yang diperiksa workflow adalah:

```text
Install noVNC + TightVNC
           ↓
Websockify sebagai Scheduled Task (SYSTEM) di 127.0.0.1:6081
           ↓
Tailscale Serve TCP 6082 atau HTTPS 443
           ↓
Verify noVNC HTTP, WebSocket and RFB
           ↓
Generate Dashboard Summary
           ↓
Remote READY – Keep Alive
```

Di Summary, lihat nilai **noVNC localhost HTTP**, **localhost WebSocket/VNC-RFB**, **Tailscale Serve self-probe HTTP**, dan **self-probe WebSocket/VNC-RFB**.

> [!NOTE]
> Self-probe berjalan **dari dalam runner**, bukan dari PC Anda. Hasil `PASS` membantu memisahkan masalah backend dan Serve, tetapi **belum membuktikan akses eksternal**. Setelah run aktif, uji koneksi dari PC Tailscale Anda sendiri.

## 🛠️ Diagnostik di Windows 10/11

Gunakan **PowerShell** dan **IP Tailscale terbaru** dari Summary run aktif (ganti `100.x.x.x` pada contoh):

```powershell
# Pastikan perangkat runner masih dapat dihubungi di tailnet
tailscale ping 100.x.x.x

# Mode default: Tailscale Serve TCP 6082
Test-NetConnection 100.x.x.x -Port 6082

# Periksa status HTTP, bukan sekadar port TCP
curl.exe --noproxy "*" --max-time 15 -sS -o NUL -w "HTTP %{http_code}\n" "http://100.x.x.x:6082/vnc.html"

# Untuk mode tailscale_https, cek port 443:
# Test-NetConnection <IP-TAILSCALE> -Port 443
# Buka URL https://<hostname>.ts.net/vnc.html dari Actions Summary
```

| Gejala | Pemeriksaan |
|:--|:--|
| Tailscale ping gagal | Runner mungkin sudah berhenti; periksa IP terbaru, perangkat online, dan login tailnet |
| Ping berhasil tetapi TCP 6082 gagal | Periksa mode `novnc_transport`, pemetaan Tailscale Serve, dan ACL/grants tailnet |
| TCP 6082 sukses tetapi `curl` gagal | Periksa langkah verifikasi HTTP dan status Scheduled Task websockify pada log run |
| HTTP 200 tetapi tombol **Connect** gagal | Buka `F12 → Network → WS`, lalu bandingkan log WebSocket/VNC-RFB di Actions |
| Browser mencoba HTTPS pada port 6082 | Gunakan `http://` secara eksplisit, nonaktifkan upgrade HTTPS otomatis untuk alamat tersebut bila diperlukan |
| Halaman lama mati | Runner GitHub Actions bersifat sementara; salin IP/URL dari run baru |
| Password VNC ditolak | Periksa pilihan password mode; VNCAuth hanya memproses delapan byte pertama |
| Ingin HTTPS tanpa port 6082 | Aktifkan MagicDNS dan HTTPS Certificates di pengaturan DNS Tailscale, lalu pilih `tailscale_https` pada run berikutnya |
| HTTPS Serve timeout, runner sebelumnya langsung gagal | Workflow baru melakukan retry/probe HTTPS dan otomatis fallback ke TCP 6082. Gunakan URL **Active transport** dari Summary. Jika tetap menginginkan HTTPS, periksa persetujuan tailnet dan sertifikat Tailscale |

Untuk diagnosis koneksi noVNC lebih detail, tambahkan `&logging=debug` ke URL yang sudah berisi `#resize=scale&autoconnect=1`, lalu lihat Developer Tools di browser.

### 🛡️ Jangan tutup terminal GitHub runner

Log [run #42505446065](https://github.com/wawanwfs/RDP/actions/runs/42505446065) menunjukkan runner menerima shutdown signal **sebelum** Tailscale logout. Karena runner GitHub-hosted bersifat sementara, menutup jendela console yang menjalankan proses runner dapat menghentikan seluruh sesi.

Workflow terbaru mencoba menyembunyikan jendela console proses **Runner.Listener** tanpa mematikan proses tersebut. Ini best effort: jika proses tidak memiliki console yang dapat diakses, langkah tersebut dilewati dengan peringatan.

Untuk meninggalkan desktop, gunakan **Disconnect** pada noVNC atau tutup tab browser—**jangan menutup terminal GitHub runner jika masih terlihat**. Logout dari blok `finally` pada Keep Alive sudah dihapus; logout Tailscale kini ditangani oleh step terpisah **Cleanup Tailscale Logout**. Jika GitHub menghentikan runner, koneksi tetap tidak dapat dipertahankan.
## ⏳ Durasi, Keep Alive, dan cleanup

- `duration_hours` tersedia dengan pilihan **1, 3, atau 6 jam**; penghitung sesi dimulai saat langkah **Remote READY – Keep Alive** berjalan.
- Job GitHub Actions tetap memiliki **`timeout-minutes: 360` (maksimal 6 jam dari awal job)**. Waktu instalasi ikut dihitung, sehingga opsi 6 jam tidak menjamin enam jam penuh *setelah* proses setup.
- Heartbeat Keep Alive tercetak setiap sekitar **60 detik**. Status `in_progress` pada tahap ini **normal**: runner sedang dipertahankan untuk remote access.
- Sesi dapat dihentikan lebih awal dengan **Cancel workflow**. Langkah cleanup mencoba melakukan `tailscale logout`; ketika dibatalkan paksa atau timeout, cleanup bersifat *best effort*.
- Data, aplikasi, dan proses di runner **tidak persist** setelah runner dihentikan.

## 📦 Aplikasi opsional

Form workflow menyediakan pilihan IDE (VS Code/Antigravity), editor video (CapCut/Shotcut), MetaTrader 4/5, AI API router (9Router/OmniRoute), coding agent (Codex CLI/Claude Code), AI agent (Hermes/OpenClaw/OpenCode), dan **ArtCraft Launcher**.

**ArtCraft Launcher terbaru:** workflow tidak lagi menginstal versi lama `v0.3.2`. Saat `install_artcraft=true`, installer membaca [rilis stabil terbaru dari `storytold/craft-launcher`](https://github.com/storytold/craft-launcher/releases/latest), mencari MSI Windows x64 resmi, mengunduhnya, lalu **memverifikasi SHA-256 terhadap digest aset GitHub** sebelum memasang untuk pengguna `RDP`. Versi yang didapat dicatat pada kolom **App Status** di Actions Summary. Rilis terbaru yang tersedia saat pembaruan panduan ini adalah **v0.16.1 (8 November 2026)**; run berikutnya bisa memakai versi yang lebih baru jika sudah diterbitkan. Jika API/rilis tidak dapat diverifikasi, instalasi akan gagal daripada memakai installer yang tidak tepercaya.

**Perbaikan lokasi installer v0.16+:** ArtCraft Launcher kini menggunakan `%LOCALAPPDATA%\Programs\ArtCraft\Launcher\artcraft-launcher.exe`, bukan path lama `%LOCALAPPDATA%\Programs\ArtCraft Launcher\artcraft-launcher.exe`. Workflow membaca path aktual yang dicatat MSI pada registry akun `RDP` (`HKCU\Software\Learning Machines LLC\ArtCraft Launcher`, nilai `InstallDir`), serta memeriksa kedua lokasi agar instalasi baru dan upgrade lama sama-sama dikenali. Jika instalasi masih gagal, lihat log step **Install Apps in Parallel (Skip Existing)** dan `msi.log` pada direktori diagnostik `C:\ProgramData\RDP-Setup\UserTasks\RdpSetup-ArtCraft-*`.

Ketersediaan setiap aplikasi bergantung pada image Windows, installer, dan hasil langkah instalasi. Periksa tabel **App Status** pada Actions Summary; jangan menganggap semua aplikasi berhasil hanya karena workflow mencapai tahap Remote READY.

## 🔒 Keamanan dan batasan

- Akses remote ditujukan ke **tailnet**, bukan tautan publik.
- Jangan membuka port RDP/VNC ke internet atau membagikan auth key/password.
- Untuk akun remote, gunakan password kuat dan hindari mempublikasikan log yang mengandung kredensial acak.
- noVNC dan RDP bisa menampilkan sesi Windows berbeda; tidak ada jaminan semua aplikasi memiliki UI aktif di console session.
- Proyek ini menyediakan **lingkungan pengujian sementara**. Keberhasilan koneksi nyata tetap harus dikonfirmasi pada perangkat klien.

---

<div align="center">

**WFS Tech • Build. Connect. Test.**

[▶ Run Windows Workspace](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml) · [GitHub Actions](https://github.com/wawanwfs/RDP/actions) · [Tailscale Docs](https://tailscale.com/kb) · [noVNC Project](https://github.com/novnc/noVNC)

</div>

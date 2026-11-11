<div align="center">

# 🐧 WFS Linux Remote Workspace

### Ubuntu KDE Plasma (default) · XRDP · Selkies Web · 21 native desktop variants

**Workspace Linux sementara di GitHub Actions: pilihan aplikasi setara menu Windows, koneksi privat Tailscale, dan konfigurasi akun/password yang sama.**

[![Linux CI](https://img.shields.io/github/actions/workflow/status/wawanwfs/RDP/linux-workspace-checks.yml?branch=main&style=for-the-badge&logo=githubactions&label=Linux%20Tests)](https://github.com/wawanwfs/RDP/actions/workflows/linux-workspace-checks.yml)
[![Tailscale](https://img.shields.io/badge/Tailscale-Private%20Only-242424?style=for-the-badge)](https://tailscale.com/)
[![Linux](https://img.shields.io/badge/Desktop-21%20Native%20Options-168566?style=for-the-badge&logo=linux)](https://docs.linuxserver.io/images/docker-webtop/)

[**▶ Jalankan Linux Workspace**](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml) · [**▶ Windows Workspace**](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml) · [README Root](../README.md)

</div>

---

## 🔥 Fitur dan pilihan GUI

Workflow menggunakan **Ubuntu 24.04 GitHub-hosted runner** sebagai host, menjalankan sistem Linux pilihan sebagai **container LinuxServer Webtop tanpa QEMU**. Browser menggunakan Selkies, sedangkan XRDP menggunakan **sesi X11 sesuai desktop yang dipilih** (bukan lagi selalu Xfce).

**Rekomendasi default: `distro=ubuntu`, `desktop=kde`, `remote_access=rdp`.** Kombinasi ini memasang desktop KDE Plasma pada X11 untuk XRDP dan menggunakan image Webtop Ubuntu KDE untuk desktop web. Keduanya **sesi terpisah**, tetapi berada dalam container yang sama.

| Distro | KDE Plasma | Xfce | MATE | i3 | LXQt |
|:--|:--:|:--:|:--:|:--:|:--:|
| **Ubuntu (default)** | ✅ | ✅ | ✅ | ✅ | ✅ |
| Debian | ✅ | ✅ | ✅ | ✅ | — |
| Fedora | ✅ | ✅ | ✅ | ✅ | — |
| Arch Linux | ✅ | ✅ | ✅ | ✅ | — |
| Alpine Linux | ✅ | ✅ | ✅ | ✅ | — |

Tabel tersebut adalah pilihan **native image Webtop** (21 kombinasi). XRDP Arch belum didukung dan harus menggunakan mode web; KDE Alpine adalah Wayland-only dan juga memerlukan mode web. Penggunaan KDE/MATE/i3/LXQt melalui XRDP membutuhkan paket X11 khusus yang diinstal dan diperiksa, dengan status akhir bergantung pada uji login grafis.

**Rekomendasi:** **Ubuntu + KDE Plasma + XRDP** untuk tampilan modern dan kompatibilitas aplikasi; Debian + Xfce untuk desktop ringan; i3 untuk pengguna keyboard; Ubuntu + LXQt sebagai alternatif ringan.

## 🖥️ Jenis remote sama dengan Windows

| `remote_access` | Cara masuk | Port Tailscale | Autentikasi |
|:--|:--|:--|:--|
| `rdp` | Windows `mstsc` / klien Microsoft RDP | TCP `3389` | Username `rdp_username` + `RDP_PASSWORD` |
| `novnc` | Browser (sebenarnya **Selkies Webtop**, bukan VNC tradisional) | HTTPS `443` atau TLS/TCP `6082` | Username `web_username` + `VNC_PASSWORD` |
| `both` | **Kedua akses di atas sekaligus** | TCP `3389` **dan** port web terpilih | Password terpisah untuk masing-masing akses |

**RDP dan browser merupakan dua sesi desktop yang berbeda**, tidak mencerminkan layar yang sama. Container mengikat port backend pada `127.0.0.1`. Saat Tailscale Serve belum diaktifkan oleh admin tailnet, workflow **langsung meneruskan port 6082 (HTTPS browser) dan/atau 3389 (xrdp) pada alamat IPv4 Tailscale runner saja (`100.x.x.x`)**, bukan pada `0.0.0.0` atau internet publik. Tailscale Serve HTTPS 443 tetap opsional. Tidak menggunakan Cloudflare, Funnel, maupun port forwarding router.

Pada mode web, layanan otomatis menyesuaikan ukuran browser. Fullscreen monitor tetap memakai **F11** atau kontrol fullscreen browser.

## 🔐 Pakai GitHub Secrets Windows yang sudah ada

Tidak perlu membuat secret password Linux baru.

| Secret | Digunakan untuk | Wajib jika |
|:--|:--|:--|
| `TAILSCALE_AUTH_KEY` | Join runner Linux ke Tailscale privat | Semua mode |
| `RDP_PASSWORD` | Login xrdp Linux | `rdp` atau `both` |
| `VNC_PASSWORD` | Login desktop web Selkies Linux | `novnc` atau `both` |

Simpan di [**Settings → Secrets and variables → Actions**](https://github.com/wawanwfs/RDP/settings/secrets/actions). Password minimal 8 byte dan tidak boleh mengandung newline. **Nama secret dan nilainya sama dengan yang sudah dipakai workflow Windows.**

### Nama runner, akun, dan mode password

| Input | Fungsi | Default |
|:--|:--|:--|
| `tailscale_hostname` | Nama node Tailscale yang bisa diisi sendiri (huruf kecil, angka, strip) | `rdp-runner` |
| `hostname_mode` | `same_each_run` atau `unique_each_run` | `same_each_run` |
| `rdp_username` | Nama akun Linux xrdp; **case-sensitive**, sama seperti Windows | `RDP` |
| `web_username` | Nama akun login browser Webtop | `wfs` |
| `rdp_password_mode` | `same_from_secret` atau `random_each_run` | `same_from_secret` |
| `vnc_password_mode` | `same_from_secret` atau `random_each_run` | `same_from_secret` |

`unique_each_run` menambahkan GitHub Run ID pada hostname, menghindari bentrok dengan runner lain. `same_each_run` mempertahankan nama dasar (jangan aktifkan dua runner dengan hostname sama sekaligus).

**Password tetap:** pilih `same_from_secret` untuk memakai nilai `RDP_PASSWORD` dan `VNC_PASSWORD` apa adanya.

**Password per-run:** pilih `random_each_run`. Supaya tidak membocorkan password dalam log repository publik, Linux menghasilkan password 24 karakter heksadesimal menggunakan HMAC-SHA256 dari **secret asal + GitHub Run ID + jenis akses**. Tidak ada password mentah yang dicetak di Actions. Untuk memperoleh password per-run, hitung di PC Anda sendiri:

```powershell
# Masukkan GitHub Actions Run ID yang aktif:
$RunId = "42500000000"
# Pilih "rdp" atau "web":
$Type = "rdp"

# Masukkan nilai secret RDP_PASSWORD untuk rdp, atau VNC_PASSWORD untuk web.
$Secure = Read-Host "Password secret asal" -AsSecureString
$Plain = (New-Object System.Net.NetworkCredential("", $Secure)).Password
$KeyBytes = [Text.Encoding]::UTF8.GetBytes($Plain)
$Message = [Text.Encoding]::UTF8.GetBytes(('wfs:' + $RunId + ':' + $Type))
$HMAC = [System.Security.Cryptography.HMACSHA256]::new($KeyBytes)
try {
  $Digest = $HMAC.ComputeHash($Message)
  $Hex = -join ($Digest | ForEach-Object { $_.ToString("x2") })
  Write-Host ("Password per-run: " + $Hex.Substring(0,24))
} finally {
  $HMAC.Dispose()
  $Plain = $null
  $KeyBytes = $null
}
```

Angka `$RunId` adalah nomor dari URL Actions run Anda, **bukan** commit SHA atau nomor job. Gunakan jenis `rdp` untuk xrdp, `web` untuk akses browser. Jangan kirim hasil atau secret asal ke issue/log publik.

## 📊 Dashboard Summary & log baru (seperti Windows)

Workflow Linux menampilkan **Dashboard** pada tab **Summary** setiap run aktif dan banner **WFS LINUX REMOTE WORKSPACE — READY** pada langkah **Remote READY — Keep Alive**. Informasi tidak hanya berupa URL pendek, tetapi terbagi menjadi:

| Bagian output | Apa yang ditampilkan |
|:--|:--|
| **🎯 Recommended Login** | Alamat RDP `100.x.x.x:3389`, username yang dipilih (default **`RDP`**, kapital), tautan browser HTTPS, username web (default `wfs`), dan petunjuk password |
| **🔗 Connection & Runner Details** | Distro, desktop, image/digest, hostname Tailscale, IP, mode, transport diminta/aktif, port privat, durasi dan link run |
| **🧪 Service Health** | Autentikasi Webtop HTTPS, status Tailscale, pemeriksaan xrdp, dan batas verifikasi dari sisi runner |
| **📦 Selected Applications & Install Status** | Semua kategori aplikasi, hasil per-app jika ada, status langkah instalasi opsional, dan ArtCraft |
| **🚀 How to Connect** | Langkah masuk melalui Microsoft Remote Desktop atau browser |
| **🧯 Troubleshooting** | Solusi koneksi, sertifikat self-signed, username/password, dan aplikasi |
| **🧹 Keep Alive & Cleanup** | Heartbeat kesehatan setiap menit, sisa waktu, batas maksimal GitHub Actions, serta pembersihan sesi |

**Hostname default adalah `rdp-runner`**, dapat diganti langsung di kolom `tailscale_hostname` pada **Run workflow**. Mode default **`same_each_run`** menggunakan hostname yang sama pada setiap run, tanpa Run ID. Jika perlu menghindari bentrok antar-run yang aktif bersamaan, pilih `unique_each_run` untuk menambahkan Run ID, contohnya `rdp-runner-42500000000`. Jangan menjalankan dua runner aktif dengan hostname yang sama; Tailscale dapat memberi sufiks berbeda bila masih ada node yang menggunakan nama tersebut.

**Username xrdp default kini `RDP` (huruf besar, sama seperti Windows)**, sedangkan username web tetap `wfs`. Keduanya dapat dikustomisasi terpisah. Mode password `same_from_secret` tetap menggunakan secret RDP/VNC yang sama dengan Windows; mode `random_each_run` mengikuti rumus HMAC pada panduan ini.

**Keamanan:** log dan Summary tidak pernah menampilkan nilai `RDP_PASSWORD` atau `VNC_PASSWORD` (termasuk password per-run). Status READY membuktikan koneksi dan respons layanan **dari runner**, bukan keberhasilan login grafis dari perangkat lain. Setelah Anda melakukan uji langsung, gunakan URL yang berasal dari run baru yang masih aktif.

## 🚀 Langkah penggunaan

1. Pastikan Tailscale terpasang pada PC/HP yang akan mengakses runner dan secret `TAILSCALE_AUTH_KEY` telah tersedia.
2. Buka [Linux Remote Workspace Actions](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml) → **Run workflow** → branch `main`.
3. Pilih distro, desktop, `remote_access`, hostname dan mode password. Untuk konfigurasi premium gunakan Ubuntu, KDE, `rdp`, `same_from_secret`, dan tanpa aplikasi tambahan.
4. Tunggu **Publish selected private RDP and/or web endpoints through Tailscale**. Lihat **Actions Summary** untuk IP RDP, URL web, username dan jenis password. Jangan memakai URL runner lama.
5. Untuk RDP: di Windows tekan `Win + R` → `mstsc` → masukkan `100.x.x.x:3389` → login dengan `rdp_username` dan password RDP. Untuk web: buka URL HTTPS dan login dengan `web_username` dan password VNC.

Mode `transport=auto` mencoba Tailscale HTTPS Serve `443` sebentar (**maksimal 12 detik**). Jika Serve tidak diaktifkan/diizinkan di tailnet, workflow **langsung menggunakan HTTPS Webtop pada IP Tailscale privat port `6082` tanpa Tailscale Serve**. Fallback menggunakan sertifikat Webtop self-signed sehingga browser mungkin menampilkan peringatan; pastikan IP sesuai Actions Summary. Native xrdp di mode `rdp`/`both` diteruskan pada **IP Tailscale port `3389`** secara privat. `tailnet_https` khusus untuk pengguna yang sudah mengaktifkan Serve + HTTPS Certificates/MagicDNS di tailnet.

## 🌐 Chromium bawaan + Cookie-Editor dan GoFullPage

**Browser tidak perlu dipasang ulang jika Chromium sudah tersedia.** Workflow sekarang mengecek `chromium` atau `chromium-browser` terlebih dahulu dan memakainya **tanpa menginstal Google Chrome tambahan**. Jika Chromium tidak tersedia tetapi Chrome sudah ada, workflow menggunakan Chrome tersebut. Google Chrome baru diinstal sebagai fallback pada Debian/Ubuntu/Fedora **hanya jika keduanya tidak tersedia**; pada Arch/Alpine fallback-nya Chromium native.

Contoh hasil CI: Kubuntu/LinuxServer Webtop menggunakan Chromium `156.0.8078.73` di `/usr/bin/chromium`, status `reused`, tanpa unduhan Chrome baru. **Pilihan ini berlaku baik untuk XRDP maupun desktop web**, sebab policy berbasis sistem.

Dua ekstensi yang sama dengan workflow Windows dikonfigurasi melalui kebijakan **Chromium atau Chrome yang benar-benar dipilih** untuk seluruh akun lokal:

| Ekstensi | Chrome Web Store ID | Fungsi |
|:--|:--|:--|
| **Cookie-Editor** | `hlkenndednhfkekhgcdicdfddnkalmdm` | Mengelola cookie browser |
| **GoFullPage** | `fdpohaocaechififmbbbbbknoalclacl` | Screenshot halaman penuh |

Pemeriksaan setup memvalidasi browser terpilih dan JSON `ExtensionInstallForcelist`. Untuk Chromium, kebijakan disimpan di `/etc/chromium/policies/managed/` (juga `/etc/chromium-browser/policies/managed/` demi kompatibilitas); untuk Chrome fallback di `/etc/opt/chrome/policies/managed/`. **Unduhan CRX terjadi saat profil browser pertama dijalankan** dan memerlukan akses Chrome Web Store. Cek `chrome://policy` dan `chrome://extensions` di Chromium; policy terpasang tidak otomatis berarti ekstensi sudah muncul. Untuk memeriksa, buka `chrome://policy` (klik Reload policies) dan `chrome://extensions`. Login akun Chrome/Google serta sinkronisasi ekstensi lain tidak dapat dipulihkan otomatis tanpa data profil dan otorisasi.

## 🖥️ Perbaikan layar hitam xrdp

Untuk menghindari layar hitam, launcher XRDP sekarang memilih **desktop X11 sesuai `desktop`**, memeriksa executable, mengatur DBus, dan hanya kemudian mempublikasikan endpoint. Untuk Xfce komponen `xfwm4`/`xfdesktop` tetap diinstal. KDE menggunakan `startplasma-x11`, MATE `mate-session`, i3 `i3`, dan Ubuntu LXQt `startlxqt`.

Tes grafis menggunakan **FreeRDP melalui Xvfb**, lalu memeriksa proses desktop terpilih (misalnya `plasmashell`/`kwin_x11` untuk KDE; `xfce4-session`/`xfwm4`/`xfdesktop` untuk Xfce). Jika gagal, log `xrdp-sesman` dan `~/.wfs-xrdp-session.log` digunakan untuk diagnosis. Browser dan XRDP tetap dua sesi berbeda.

## 📦 Aplikasi — kategori sama dengan Windows

| Menu | Pilihan | Implementasi Linux |
|:--|:--|:--|
| `ide_choice` | none, vscode, antigravity, both | VS Code: repo APT Microsoft Debian/Ubuntu; Antigravity IDE: dicoba dari tarball Linux resmi Google (tanpa checksum yang diterbitkan) |
| `editor_choice` | none, capcut, shotcut, both | Shotcut melalui package manager; CapCut native Linux tidak didukung |
| `metatrader_choice` | none, mt4, mt5, both | Wine/Xvfb + official publisher/broker installer; either `INSTALLED` with verified executable or `PENDING_INTERACTIVE` |
| `router_choice` | none, 9router, omniroute, both | Dicoba via npm package yang dipilih |
| `coding_agent_choice` | none, codex, claude, both | npm `@openai/codex` dan `@anthropic-ai/claude-code` |
| `ai_agent_choice` | none, hermes, openclaw, opencode, both, all | OpenClaw/OpenCode via npm; Hermes CLI dicoba dari installer stable resmi Nous Research dengan mode noninteraktif; login model tetap manual |
| `install_artcraft` | true/false | Rilis stabil GitHub resmi, DEB/RPM/Arch; Alpine dilewati |
| `apps_bundle` | none, developer, office, media, all | Paket Git/Python/Node, LibreOffice, GIMP, VLC |

Instalasi aplikasi opsional **tidak mematikan desktop jika gagal**. Installer sekarang memeriksa executable masing-masing, melaporkan **INSTALLED**, **FAILED**, **MANUAL**, atau **UNSUPPORTED** per item, dan menandai langkah installer sebagai gagal bila ada paket yang gagal (desktop tetap aktif). Pemilihan aplikasi berarti instruksi untuk *mencoba instalasi*, bukan jaminan telah terpasang dan berfungsi. Untuk CLI AI biasanya perlu autentikasi akun/API tambahan setelah masuk ke Linux.

### 🔧 Perbaikan xrdp dan installer aplikasi (November 2026)

- **Username RDP:** akun Linux bersifat case-sensitive. Workflow kini membuat akun **`RDP` (huruf kapital)** secara nyata dan tidak menurunkannya menjadi `rdp`. Pada klien Microsoft Remote Desktop, isi **Username: `RDP`**, tanpa domain, dengan secret `RDP_PASSWORD`. Pastikan memakai workflow run baru dari `main` karena run lama tetap menggunakan konfigurasi sebelumnya.
- **Akun dan password:** sebelum endpoint RDP dipublikasikan, script memastikan `getent passwd` dan `id` menemukan akun serta melakukan autentikasi PAM melalui `pamtester xrdp-sesman` dengan password secret yang sudah dipilih. Pemeriksaan sebelumnya baru sampai TCP handshake.
- **Node/npm:** image Ubuntu dapat berisi Node.js 22 dari NodeSource yang sudah membundel npm. Memasang paket `npm` Debian secara terpisah menyebabkan konflik dependensi. Installer sekarang memverifikasi Node dan npm dahulu, lalu hanya memulihkan paket `nodejs` bila perlu. Git, Python, Node, 9Router, dan Codex diverifikasi satu per satu.
- **GUI/agent tambahan:** Antigravity IDE dicoba dari arsip Linux Google resmi dan ditambahkan shortcut desktop jika executable ditemukan. Arsip itu tidak menyediakan digest SHA-256 terpisah dalam halaman yang diperiksa, sehingga tidak setara dengan verifikasi checksum ArtCraft. Hermes Agent dicoba dari installer resmi stable noninteraktif untuk akun Linux yang akan digunakan, tanpa memaksa login provider.
- **MetaTrader 4/5:** tahap `linux/install-metatrader.sh` kini benar-benar mencoba instalasi dengan Wine, terpisah dari paket opsional, serta hanya mencatat `INSTALLED` ketika binary yang tepat dan shortcut berhasil diverifikasi. Jika gagal, hasil per-terminal `FAILED` tampil di Summary. CapCut native Linux tetap tidak didukung.
- **Cleanup:** cache aplikasi milik root di volume Webtop dibersihkan dari folder sementara khusus run menggunakan izin yang memadai. Tidak menghapus data di luar workspace sementara.

Jika ada aplikasi yang gagal, lihat kolom **Per-Application Results** di GitHub Actions Summary. Status `INSTALLED` berarti executable/paket ditemukan, bukan bahwa login provider, aktivasi lisensi, atau sesi GUI sudah terbukti.

## 📈 MetaTrader 4/5 — installer otomatis dengan verifikasi nyata

Pada menu `metatrader_choice`, pilih `mt4`, `mt5` atau `both`. Tahap tersendiri [`install-metatrader.sh`](install-metatrader.sh) berjalan setelah XRDP dan browser siap. Wine dan Xvfb diinstal dari repositori distro yang dipilih; installer MT5 berasal dari MetaQuotes sedangkan MT4 berasal dari tautan Exness resmi. Prefix Wine masing-masing berada di home pengguna. **MT5 mungkin perlu fallback browser/Windows jika GUI Wine tidak kompatibel.**

| Pemilihan | Tindakan | Bukti pemasangan | Catatan |
|:--|:--|:--|:--|
| `none` | Tidak ada installer trading | `SKIPPED` | Desktop lebih cepat |
| `mt5` | `mt5setup.exe /auto` | `terminal64.exe` di direktori MetaTrader 5, launcher, shortcut | Runtime GUI dan koneksi broker tetap harus diuji |
| `mt4` | Coba installer Exness melalui Wine; jika wizard memerlukan GUI, sediakan shortcut | `terminal.exe` yang benar = `INSTALLED`; jika belum ada = `PENDING_INTERACTIVE` | Tidak mengklaim berhasil jika pemasangan membutuhkan klik wizard |
| `both` | Dua prefiks Wine independen | Bukti executable/shortcut tiap platform | Dapat berstatus berbeda per platform |

### Cara membuka terminal

1. Jalankan [Linux Workspace](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml) dengan `distro=ubuntu`, `desktop=kde`, `remote_access=rdp`, `metatrader_choice=mt5` (atau `both`).
2. Buka tab **Summary → Per-Application Results**. Pastikan baris `MetaTrader 5` benar-benar bertuliskan **INSTALLED**. Jika `FAILED`, jangan anggap aplikasi tersedia.
3. Login melalui XRDP pada alamat IP yang dicetak run. Untuk MT5, buka **MetaTrader 5 (WFS)**; untuk MT4 yang sudah `INSTALLED` buka **MetaTrader 4 (WFS)**. Jika status MT4 **`PENDING_INTERACTIVE`**, klik **Install MetaTrader 4 (WFS)** di desktop dan selesaikan wizard Exness di Wine. Instalasi manual ini tidak otomatis mengubah status Summary run yang sudah dibuat.
4. Setelah terminal terbuka, pilih server broker lalu login **secara manual**. Pasang EA setelah Anda memastikan platform bekerja dan menyimpan backup-nya. Tidak ada tindakan otomatis yang mengeksekusi order.
5. Jika belum muncul, lihat **Install selected MetaTrader desktop terminals with Wine**, status `FAILED` atau `PENDING_INTERACTIVE`, dan log Wine. Aplikasi Wine tidak berjalan di Alpine lewat installer ini.

> [!WARNING]
> Wine tidak menjamin seluruh fitur broker, WebView2, grafik, EA berbasis DLL, atau login berjalan sebagaimana Windows. **INSTALLED berarti executable dan shortcut ditemukan**, bukan trading telah diuji. Koneksi live dan login broker tidak diuji CI. Pembatasan GitHub 360 menit juga berlaku, sehingga instalasi Wine besar dapat mengurangi masa penggunaan.

Referensi: [panduan MT5 Linux MetaQuotes](https://www.metatrader5.com/en/terminal/help/start_advanced/install_linux), [MT5 installer /auto](https://www.metatrader5.com/en/terminal/help/start_advanced/installation), [panduan MT4 Linux](https://www.metatrader4.com/en/trading-platform/help/userguide/install_linux).

### Hasil pengujian dan batasan penting

Pengujian [Windows CI](https://github.com/wawanwfs/RDP/actions/runs/42924327969) sudah membuktikan instalasi **MT4 native Windows (Exness)** dan **MT5 native Windows**, termasuk executable yang benar. Di Linux, [CI Wine MT5](https://github.com/wawanwfs/RDP/actions/runs/42844537445) lulus. Pengujian MT4 Linux awalnya gagal pada installer grafis yang tidak menyelesaikan `/auto` setelah timeout; fallback desktop `PENDING_INTERACTIVE` disediakan agar aplikasi tidak pernah dinyatakan terinstal tanpa bukti. Jalur interaktif harus tetap diuji dalam sesi XRDP pengguna.

`PENDING_INTERACTIVE` **bukan** berarti `INSTALLED`. File setup yang disimpan di home desktop user berasal dari unduhan HTTPS Exness dengan pemeriksaan header PE dan SHA-256. Workflow Linux belum melakukan verifikasi sertifikat Authenticode setara Windows.

### MT5 Linux: pesan `A debugger has been found running in your system`

Pesan seperti pada screenshot KDE/RDP **tidak berarti Anda benar-benar menjalankan debugger**. Run sebelumnya menggunakan **Wine 10.0**, dan laporan komunitas terbaru menunjukkan build MT5 setelah Oktober 2026 dapat menampilkan *false positive* tersebut pada Wine 9 maupun 10. **Jangan menghapus data Wine prefix, mematikan proteksi keamanan OS, atau mengganti Wine sembarangan** berdasarkan pesan ini.

Perubahan berikut dilakukan:

1. Untuk **Linux**, pengujian mencoba installer MT5 resmi Exness (`exness5setup.exe`) sebagai alternatif, tetapi mode `/auto` **tidak menghasilkan terminal** pada Wine di runner. Karena itu installer otomatis dikembalikan ke **paket resmi MetaQuotes** yang sebelumnya terbukti memasang `terminal64.exe`. **Keberhasilan instalasi bukan bukti MT5 dapat dibuka** pada build terbaru.
2. CI menyediakan [`linux/test-metatrader-gui.sh`](test-metatrader-gui.sh), yaitu **peluncuran MT5 nyata pada Xvfb tanpa login broker**, dan mencari judul jendela **MetaTrader 5**, bukan sekadar proses `terminal64.exe`. Hasil GUI dilaporkan terpisah dari status installer: dialog error tidak dihitung sebagai terminal berfungsi.
3. Sebagai fallback tanpa Wine, menu aplikasi menawarkan **MetaTrader WebTerminal (WFS fallback)** lewat Chromium di <https://web.metatrader.app/>. WebTerminal hanya mendukung fungsi trading berbasis browser dan **tidak menjalankan EA/script desktop**.
4. Jika membutuhkan **MetaTrader desktop, MetaEditor, Expert Advisor, dan operasi stabil**, gunakan workflow **Windows RDP native** yang sudah membuktikan instalasi MT4/MT5 Windows. Uji login, chart, dan EA secara manual sebelum trading live.

**Penting:** pembaruan repo baru berlaku untuk **run Actions baru** setelah commit ini. Sesi RDP yang sudah berjalan tidak otomatis mengganti installer, executable, atau policy browser di dalam containernya.

Referensi isu: [laporan MT5 terbaru di MQL5](https://www.mql5.com/en/forum/518725) dan [diskusi Wine + build MT5](https://www.mql5.com/en/forum/10114/page38).

## ⏳ Keep Alive dan keamanan

Pilihan `duration_hours` adalah `1`, `3`, atau `6` jam dari sesi ready, dengan **batas total job 360 menit** termasuk instalasi, pull image, dan setup. GitHub runner bersifat sementara: data akan hilang setelah selesai/cancel/timeout.

**Jangan mematikan runner GitHub atau container dari terminal desktop.** Untuk keluar tanpa mengakhiri sesi, cukup tutup tab web atau disconnect klien RDP. Untuk menghentikan runner, pilih **Cancel workflow** di Actions. Cleanup mencoba menghapus container dan file password, sedangkan Tailscale Action menjalankan logout pada post-step.

RDP dan web hanya bisa dijangkau dari **tailnet** yang memiliki izin ACL/grants sesuai konfigurasi Anda. Jangan membagikan password, auth key, URL sensitif, atau membuka port Docker ke internet publik.

## 🧪 Additional compatibility: optional ISO guest

Untuk eksperimen lama tersedia input `distro=igos-nusantara` (bukan default). Opsi ini menjalankan ISO **IGOS Nusantara 26** melalui QEMU di dalam outer Ubuntu/Xfce, berbeda dari semua distro Webtop native pada tabel utama. Pilih `desktop=xfce` dan `remote_access=rdp`. Aplikasi yang diinstal oleh workflow, termasuk Chrome dan MetaTrader, berada di **outer host**, bukan guest ISO. Kinerja tanpa KVM dapat sangat lambat dan **boot guest GUI tidak dinyatakan terverifikasi**. Gunakan distro native untuk aktivitas harian. Detail teknis ada di [`start-igos.sh`](start-igos.sh).

## 🧪 Pengujian dan troubleshooting

Pengujian otomatis memvalidasi YAML/Bash, password mode, desktop Debian Xfce, dan xrdp handshake. **Run integrasi nyata [#42538689043](https://github.com/wawanwfs/RDP/actions/runs/42538689043) berhasil 4/4 job:** runner masuk tailnet, HTTPS browser di `100.x.x.x:6082` lolos autentikasi, port xrdp `3389` merespons, dan kedua listener tetap aktif antarlangkah Actions. **Login GUI dari perangkat lain, koneksi RDP sampai desktop siap, serta seluruh 20 kombinasi belum diverifikasi**; pengujian tersebut masih perlu dilakukan oleh pengguna.

```powershell
# Ganti dengan IP Tailscale dari Actions Summary run aktif.
tailscale ping 100.x.x.x
Test-NetConnection 100.x.x.x -Port 3389  # hanya rdp / both
Test-NetConnection 100.x.x.x -Port 6082  # hanya web TCP fallback
```

Jika RDP error, periksa langkah **Start native Linux xrdp server** dan **Publish private ... endpoints**; paket xrdp/Xorg dan sesi desktop terpilih bergantung pada repositori distro. Jika web gagal, cek log publikasi port, `ss -ltn` pada runner, autentikasi dan log container Webtop. **Tailscale Serve tidak wajib** untuk port privat `6082`/`3389`. Periksa ACL/grants tailnet jika koneksi dari perangkat lain gagal. Untuk paket aplikasi, baca tabel di Summary.

---

<div align="center">

**WFS Tech • Windows & Linux Remote Workspace**

[**▶ Linux Actions**](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml) · [**▶ Windows Actions**](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace-with-apps.yml) · [Root README](../README.md)

</div>

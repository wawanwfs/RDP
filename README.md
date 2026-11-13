<div align="center">

# 🖥️ WFS Remote Workspaces

**Desktop Windows dan Linux, serta shell macOS native — dalam satu repository.**  
Jalankan workspace sementara dari GitHub Actions dan hubungkan perangkat Anda melalui jaringan privat Tailscale.

[![Windows · RDP & noVNC](https://img.shields.io/badge/Windows-RDP%20%2B%20noVNC-1769E0?style=for-the-badge)](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace.yml)
[![Linux · XRDP & Selkies](https://img.shields.io/badge/Linux-XRDP%20%2B%20Selkies-147D64?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml)
[![macOS · SSH & Preview](https://img.shields.io/badge/macOS-SSH%20%2B%20Preview-5C4CD8?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/wawanwfs/RDP/actions/workflows/macos-remote-workspace.yml)

[**Mulai cepat**](#mulai-cepat) · [**Bandingkan akses**](#bandingkan-cara-akses) · [**Aplikasi**](#aplikasi-opsional) · [**Troubleshooting**](#troubleshooting) · [**Semua run**](https://github.com/wawanwfs/RDP/actions)

</div>

## Pilih workspace

| Kebutuhan | Pilihan awal | Akses | Jalankan |
| --- | --- | --- | --- |
| Aplikasi Windows native, pengujian UI, atau MetaTrader desktop | **Windows 2025** | RDP atau noVNC interaktif | [Run Windows](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace.yml) |
| Desktop Linux untuk pengembangan dan pengujian lintas distro | **Ubuntu + KDE Plasma** | XRDP atau Selkies di browser | [Run Linux](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml) |
| Shell dan tooling macOS native di Apple Silicon atau Intel | **macOS 15** | SSH, preview screenshot, dan Apple VNC eksperimental | [Run macOS](https://github.com/wawanwfs/RDP/actions/workflows/macos-remote-workspace.yml) |

> [!IMPORTANT]
> **Ingin desktop yang bisa diklik?** Gunakan Windows atau Linux. Di macOS, SSH dan screenshot adalah jalur terpisah. Finder dan Dock dapat terlihat di preview meskipun Apple VNC tetap hitam atau tidak menerima input. Kendali mouse dan keyboard macOS belum terverifikasi.

## Bandingkan cara akses

| Saya ingin… | Pilihan | Yang terbuka di klien |
| --- | --- | --- |
| Menjalankan aplikasi **Windows** dari PC Windows 10/11 | Windows → `rdp` | Sesi Windows RDP melalui `mstsc` |
| Mengendalikan desktop **Windows** dari browser | Windows → `novnc` | noVNC menampilkan console Windows melalui TightVNC |
| Mengendalikan desktop **Linux** dari browser | Linux → `novnc` | Selkies Webtop, termasuk dari browser di PC Windows |
| Menggunakan terminal **macOS** dan melihat tampilannya | macOS → `ssh` + `gui_preview=true` | Terminal SSH dan screenshot terpisah |

> [!TIP]
> **RDP atau noVNC untuk Windows?** Mulai dengan **RDP** jika `mstsc` tersedia. Pilih **noVNC** jika harus memakai browser. Selkies dirancang untuk host Linux dan bukan pengganti noVNC pada Windows native. WFS belum menyertakan gateway RDP lewat browser seperti Apache Guacamole. [noVNC](https://novnc.com/) · [Desain Selkies](https://github.com/selkies-project/selkies/blob/main/docs/design.md) · [Apache Guacamole](https://guacamole.apache.org/)

## Mulai cepat

1. **Siapkan repository.** Gunakan repo ini jika Anda punya akses tulis, atau fork ke akun sendiri. Jika memakai fork, jalankan Actions dan buat Secrets di **fork tersebut**, bukan di repo sumber. Aktifkan Actions pada fork jika diminta.
2. **Siapkan jaringan.** Instal Tailscale pada PC atau perangkat yang akan dipakai untuk remote. Hubungkan klien ke tailnet yang sama dengan auth key yang dipakai runner. [Unduh Tailscale](https://tailscale.com/download)
3. **Simpan Secrets.** Buka **Settings → Secrets and variables → Actions → New repository secret**. Isi sesuai tabel di bawah. [Buka Secrets repo ini](https://github.com/wawanwfs/RDP/settings/secrets/actions)
4. **Jalankan workflow.** Buka **Actions → pilih Windows, Linux, atau macOS Remote Workspace → Run workflow**, lalu pilih branch `main`. Untuk percobaan pertama, pilih **1 jam**, biarkan pilihan aplikasi di `none` bila tersedia, dan gunakan akses yang direkomendasikan. Di Windows, ubah `install_artcraft=false` jika ingin setup paling ringan. [Cara menjalankan workflow manual](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
5. **Buka Summary run aktif.** Salin IP, URL, nama pengguna, dan metode akses yang benar-benar tercantum. Coba login dari perangkat klien saat job masih aktif. Setelah selesai, putuskan koneksi dan pilih **Cancel workflow** jika sesi tidak perlu dibiarkan berjalan.

### Konfigurasi yang siap dipakai

| Skenario | Input pada formulir | Secrets |
| --- | --- | --- |
| Windows · Remote Desktop | `windows_version=windows-2025`, `remote_access=rdp` | `TAILSCALE_AUTH_KEY` + `RDP_PASSWORD` |
| Windows · Browser | `windows_version=windows-2025`, `remote_access=novnc`, `novnc_transport=tailscale_tcp` | `TAILSCALE_AUTH_KEY` + `RDP_PASSWORD` + `VNC_PASSWORD` |
| Linux · Remote Desktop | `distro=ubuntu`, `desktop=kde`, `remote_access=rdp` | `TAILSCALE_AUTH_KEY` + `RDP_PASSWORD` |
| Linux · Browser | `distro=ubuntu`, `desktop=kde`, `remote_access=novnc`, `transport=auto` | `TAILSCALE_AUTH_KEY` + `VNC_PASSWORD` |
| macOS · Terminal + preview | `runner_label=macos-15`, `remote_access=ssh`, `gui_preview=true` | `TAILSCALE_AUTH_KEY` + `RDP_PASSWORD` |

Contoh di atas memakai mode password tetap. **Windows noVNC tetap membutuhkan `RDP_PASSWORD`** pada mode ini karena workflow membuat akun Windows `RDP` untuk penyiapan workspace, meskipun akses RDP dari luar tidak digunakan.

### Secrets dan password

Simpan nilai sebagai **Repository secrets** pada repo yang menjalankan workflow. Jangan masukkan auth key atau password ke kolom formulir **Run workflow**.

| Secret | Dipakai untuk | Kapan disiapkan |
| --- | --- | --- |
| `TAILSCALE_AUTH_KEY` | Mendaftarkan runner ke tailnet | Semua workspace utama |
| `RDP_PASSWORD` | Akun Windows `RDP`, akun XRDP Linux, serta akun sementara macOS | Windows saat `rdp_password_mode=same_from_secret`, termasuk mode browser saja. Linux untuk `rdp`/`both`. macOS di semua mode |
| `VNC_PASSWORD` | noVNC Windows atau Selkies Linux | Windows untuk `novnc`/`both` dengan `vnc_password_mode=same_from_secret`. Linux untuk `novnc`/`both` pada kedua mode password |

Di macOS, nama `RDP_PASSWORD` hanya dipakai ulang sebagai secret akun. Koneksinya tetap SSH atau Apple VNC, bukan Microsoft RDP. Secret macOS minimal **12 byte** tanpa baris baru. Linux memerlukan minimal **8 byte** tanpa baris baru untuk secret yang digunakan. Windows noVNC memakai autentikasi VNC klasik yang hanya membaca **8 byte pertama**. Jangan gunakan ulang password Windows RDP sebagai password noVNC.

- **`same_from_secret`** memakai nilai secret secara langsung. Ini pilihan yang disarankan untuk percobaan pertama.
- **`random_each_run`** berbeda antar-OS. Pada workflow **Windows**, password acak RDP dan noVNC dapat tercetak di log. Hindari opsi ini di repo publik. **Linux dan macOS** menurunkan password dari secret dan Run ID tanpa mencetak password mentah. Cara menghitungnya tersedia di [panduan Linux](linux/README.md) dan [panduan macOS](macos/README.md).

## 🪟 Windows Remote Workspace

**Default** · `windows_version=windows-2025` · `remote_access=rdp` · akun `RDP` · `duration_hours=6`

Tunggu **Remote READY – Keep Alive**, lalu buka **Summary** untuk menyalin alamat. Jika memilih `both`, uji RDP dan browser secara terpisah.

| Mode | Cara masuk dari Windows 10/11 | Port privat |
| --- | --- | --- |
| `rdp` | Buka Remote Desktop Connection dengan `mstsc`, masukkan alamat dari Summary, lalu login sebagai `RDP` | `3389/TCP` |
| `novnc` | Buka URL `/vnc.html` dari Summary di browser, lalu masukkan password noVNC | HTTP `6082` atau HTTPS `443` |
| `both` | Kedua akses tersedia. Desktop sesi RDP dan console yang ditampilkan noVNC dapat berbeda | `3389` dan port web aktif |

- **noVNC.** Pilih image **x64** untuk `novnc` atau `both`. `windows-11-arm` tidak mendukung noVNC pada workflow ini.
- **Transport web.** `tailscale_tcp` adalah default dan memakai **HTTP** pada port `6082` melalui tailnet. `tailscale_https` memakai HTTPS pada port `443` jika sertifikat dan Serve siap. Jika konfigurasi HTTPS gagal, workflow mencoba kembali lewat TCP privat. Gunakan **Active transport** dan URL aktual dari Summary. [Pengaturan HTTPS Tailscale](https://tailscale.com/docs/how-to/set-up-https-certificates)
- **Tampilan.** URL dari Summary sudah meminta penskalaan gambar dan koneksi otomatis. Untuk layar penuh, gunakan tombol **Full screen** pada toolbar noVNC atau `F11`. Resolusi desktop aktual tetap bergantung pada driver dan sesi console. Log penyesuaian resolusi ada di `C:\ProgramData\RDP-Setup\wfs-display-resolution.log` pada runner.
- **Kesiapan.** noVNC memakai TightVNC dan websockify di loopback. Pemeriksaan HTTP, WebSocket, dan RFB di runner berguna untuk diagnosis, tetapi login dan input tetap perlu diuji dari PC Anda. Status aplikasi ada di **App Status**.

<details>
<summary><strong>Pengaturan Windows lainnya</strong></summary>

| Input | Default | Pilihan lainnya |
| --- | --- | --- |
| `windows_version` | `windows-2025` | `windows-latest`, `windows-2022`, `windows-11-arm`, dan `windows-2025-vs2026` sesuai ketersediaan |
| `novnc_transport` | `tailscale_tcp` | `tailscale_https` jika HTTPS tailnet siap |
| `rdp_password_mode`, `vnc_password_mode` | `same_from_secret` | `random_each_run` dapat menulis password ke log |
| `install_artcraft` | `true` | `false` untuk melewati instalasi |
| `tailscale_hostname`, `hostname_mode` | `rdp-runner`, `same_each_run` | Nama sendiri atau `unique_each_run` jika menjalankan beberapa sesi |

</details>

[Run Windows Workspace →](https://github.com/wawanwfs/RDP/actions/workflows/windows-remote-workspace.yml) · [Konfigurasi workflow](.github/workflows/windows-remote-workspace.yml)

## 🐧 Linux Workspace

**Default** · `distro=ubuntu` · `desktop=kde` · `remote_access=rdp` · `duration_hours=6`

| Mode | Cara masuk | Akun bawaan |
| --- | --- | --- |
| `rdp` | Buka `mstsc` ke alamat `:3389` dari Summary. Jika layar login XRDP meminta jenis sesi, gunakan Xorg | `RDP`, huruf besar |
| `novnc` | Buka tautan HTTPS dari Summary. Label formulir ini membuka **Selkies Webtop**, bukan noVNC Windows | `wfs` |
| `both` | Pilih akses yang sesuai. XRDP dan Selkies membuka **dua sesi desktop** dalam container yang sama | Masing-masing akun di atas |

- **Pilihan distro dan desktop.** Ubuntu, Debian, Fedora, Arch, dan Alpine berjalan sebagai container Webtop. Pilihan desktop bergantung pada distro. Arch dan Alpine KDE memakai mode web, sedangkan LXQt tersedia untuk Ubuntu. **IGOS Nusantara** adalah opsi ISO/QEMU eksperimental. Pilih `desktop=xfce` dan `remote_access=rdp`. Aplikasi pilihan dipasang di desktop luar, bukan guest ISO. Boot desktop guest belum terverifikasi.
- **HTTPS browser.** `transport=auto` mencoba Tailscale HTTPS pada `443` dan dapat beralih ke **HTTPS** pada `6082` dengan sertifikat self-signed. Cocokkan alamat dengan Summary run aktif jika browser menampilkan peringatan sertifikat.
- **Akun.** `rdp_username` dan `web_username` dapat diubah terpisah. Di XRDP, `RDP` dan `rdp` bukan nama akun yang sama. Pastikan **Keyboard Layout** saat memasukkan password.
- **Browser.** Workflow mengutamakan Chromium yang sudah tersedia, lalu menggunakan Chrome yang sudah ada atau memasang Chrome bila perlu. Kebijakan menargetkan **Cookie-Editor** dan **GoFullPage**. Periksa ekstensi langsung di profil desktop setelah login.

[Panduan Linux lengkap →](linux/README.md) · [Run Linux Workspace](https://github.com/wawanwfs/RDP/actions/workflows/linux-remote-workspace.yml)

## 🍎 macOS Workspace

**Default** · `runner_label=macos-15` · `remote_username=wfsremote` · `remote_access=both` · `gui_preview=true` · `duration_hours=1`

Formulir menawarkan macOS 15 dan 26 di perangkat Apple, dengan pilihan Apple Silicon dan Intel sesuai ketersediaan. Untuk shell saja, pilih `remote_access=ssh` dan `gui_preview=false`. Untuk shell plus screenshot, pilih `ssh` dengan `gui_preview=true`. Gunakan `both` untuk menguji Apple Screen Sharing sambil mempertahankan SSH.

| Jalur | Cara pakai | Yang dibuktikan |
| --- | --- | --- |
| **SSH · `2222`** | `ssh -p 2222 wfsremote@100.64.0.10`, ganti user dan IP sesuai Summary | Login shell. Uji historis mencakup autentikasi SSH di loopback, bukan jaminan koneksi dari PC Anda |
| **Private Preview · `6081`** | Aktifkan `gui_preview=true`, buka URL HTTP privat dari Summary, login, lalu pilih **Capture one frame** | Screenshot saja. Capture manual dapat memakai cache hingga sekitar 60 detik |
| **Apple Screen Sharing · `5900`** | Gunakan klien yang mendukung autentikasi Apple pada tailnet. Tidak menggunakan `mstsc` | Status RFB hanya menunjukkan respons protokol. Login grafis, framebuffer, dan input perlu dibuktikan terpisah |

<details>
<summary><strong>Opsi A · WFS macOS Controller untuk Windows</strong></summary>

**Capture one frame** menampilkan screenshot privat. **Capture Apple VNC** mengambil gambar dari sesi VNC yang dipakai untuk mengirim input. Jika yang pertama menampilkan Finder tetapi yang kedua tetap hitam, preview tidak membuktikan bahwa jalur input berfungsi. Pesan input terkirim juga belum membuktikan bahwa macOS memprosesnya.

Controller masih eksperimental dan memakai dependensi pihak ketiga. Permintaan `SetMode(control)` tidak memberi izin baru di macOS. Uji yang dianggap lulus adalah perubahan yang terlihat pada desktop setelah klik atau input keyboard yang aman dari klien.

[Panduan controller dan uji input](macos/WINDOWS_CONTROL.md) · [Batasan Remote Management dari Apple](https://support.apple.com/id-id/guide/remote-desktop/apd8b1c65bd/mac)

</details>

[Panduan macOS lengkap →](macos/README.md) · [Run macOS Workspace](https://github.com/wawanwfs/RDP/actions/workflows/macos-remote-workspace.yml)

## Aplikasi opsional

| Kategori | Windows | Linux | macOS |
| --- | --- | --- | --- |
| **IDE & coding CLI** | VS Code, Antigravity, Codex CLI, Claude Code | VS Code, Antigravity, Codex CLI, Claude Code | VS Code, Codex CLI, Claude Code |
| **Media** | CapCut, Shotcut | Shotcut dan paket media | Paket tooling media CLI |
| **AI tooling** | 9Router, OmniRoute, Hermes, OpenClaw, OpenCode | 9Router, OmniRoute, Hermes, OpenClaw, OpenCode | Pilihan coding CLI di atas |
| **Browser dan ekstensi** | Chrome dengan kebijakan Cookie-Editor dan GoFullPage | Chromium atau Chrome dengan kebijakan dua ekstensi yang sama | Browser dari image runner jika tersedia |
| **ArtCraft Launcher** | Rilis stabil resmi, dengan verifikasi checksum aset | Opsi instalasi eksperimental. Tidak native di Alpine | Tidak tersedia di formulir |
| **MetaTrader** | MT4/MT5 native | MT4/MT5 via Wine | Opsi WebTerminal, tanpa EA desktop |

- **MetaTrader Windows.** Workflow memeriksa installer dan executable MT4/MT5. Jika pemasangan silent tidak selesai, installer bisa disiapkan untuk dijalankan manual di desktop. **Pending Interactive** bukan status berhasil terpasang. [Installer Windows](windows/Install-MetaTrader.ps1)
- **MetaTrader Linux.** Executable yang ditemukan belum membuktikan GUI berjalan. MT4 bisa memerlukan pemasangan interaktif. Jika MT5 bermasalah di Wine, gunakan WebTerminal untuk akses browser atau Windows native jika perlu EA desktop. [Panduan Linux](linux/README.md)
- **ArtCraft.** Di Windows, `install_artcraft` aktif secara default. Matikan untuk percobaan koneksi yang lebih ringan. Di Linux, opsi ini nonaktif secara default.
- **Pemeriksaan setelah login.** Buka aplikasi yang Anda pilih dan periksa ekstensi Chrome/Chromium dari profil yang benar. Login broker atau penyedia AI tetap dilakukan pengguna. Status instalasi tidak berarti akun sudah terhubung.

<details>
<summary><strong>Nama input aplikasi</strong></summary>

| Workflow | Input aplikasi |
| --- | --- |
| Windows | `ide_choice`, `editor_choice`, `metatrader_choice`, `router_choice`, `coding_agent_choice`, `ai_agent_choice`, `install_artcraft` |
| Linux | Opsi seperti Windows, ditambah `apps_bundle`. CapCut tidak didukung sebagai aplikasi native Linux |
| macOS | `ide_choice`, `coding_agent_choice`, `apps_bundle`, `trading_choice` |

</details>

## Durasi, jaringan, dan data

- **Durasi.** Pilih **1, 3, atau 6 jam**. Batas job adalah **360 menit dari awal job**, termasuk instalasi. Pilihan 6 jam bisa menyisakan waktu remote kurang dari 6 jam. Job `in_progress` saat **Keep Alive** adalah normal. [Batas GitHub Actions](https://docs.github.com/en/actions/reference/limits)
- **Data.** Runner bersifat sementara. Simpan pekerjaan ke lokasi yang Anda kendalikan sebelum job berhenti. Jangan mengandalkan file, instalasi, sesi browser, atau proses tetap ada setelah run berakhir.
- **Hostname.** Default ketiga workflow adalah `rdp-runner` dengan `same_each_run`. Untuk beberapa run aktif sekaligus, gunakan hostname berbeda atau `unique_each_run` agar mudah membedakan node. Selalu gunakan IP dan URL run aktif dari Summary.
- **Jaringan privat.** Tiga workflow utama memakai tailnet, bukan tautan desktop publik. Tidak perlu port forwarding di router. Beri perangkat klien akses yang diperlukan lewat kebijakan tailnet dan jangan bagikan auth key, password, atau log yang belum disunting.
- **Biaya dan kebijakan.** Penggunaan runner mengikuti batas dan kebijakan GitHub Actions. Periksa kuota akun Anda, terutama sebelum menjalankan sesi macOS atau sesi panjang.

## Troubleshooting

| Gejala | Periksa dulu |
| --- | --- |
| **Run workflow** tidak muncul | Pastikan Actions diaktifkan, workflow ada di default branch, dan akun Anda punya akses menjalankan workflow. Jika memakai fork, buka tab Actions di fork tersebut. |
| Runner tidak dapat dihubungi | Buka Summary run aktif. Periksa Tailscale di kedua sisi, IP terbaru, dan aturan akses perangkat. Runner lama tidak bisa dipakai kembali. |
| Windows noVNC tidak bisa dibuka | Salin **Active transport**. Windows `6082` menggunakan **HTTP**. Jika HTTP sudah menjawab tetapi koneksi gagal, cek WebSocket/RFB di log dan coba dari klien tailnet. |
| Linux XRDP menolak login atau blank | Cocokkan akun huruf besar `RDP`, jenis sesi Xorg, dan desktop pilihan. Coba konfigurasi Ubuntu/KDE tanpa aplikasi opsional untuk membedakan masalah sesi dan instalasi. |
| Linux web menampilkan peringatan sertifikat | Cocokkan URL dengan Summary. Fallback Linux `6082` menggunakan **HTTPS** self-signed. Jika butuh sertifikat tailnet, siapkan HTTPS Certificates dan gunakan mode Tailscale HTTPS. |
| macOS terlihat di preview, tetapi tidak bisa diklik | Pastikan apakah gambar berasal dari **Capture Apple VNC** atau **Capture one frame**. Tetap gunakan SSH untuk akses yang tersedia. [Panduan diagnosis macOS](macos/README.md) |
| Aplikasi tidak muncul atau tidak bisa dibuka | Cek **App Status** atau log installer. Lalu login ke desktop yang benar dan buka aplikasinya. Status pending, installer tersedia, dan GUI berjalan adalah tiga hal berbeda. |

<details>
<summary><strong>Contoh pemeriksaan dari PowerShell Windows 10/11</strong></summary>

Ganti IP contoh dengan IP Tailscale run aktif. Jalankan hanya pemeriksaan untuk mode yang Anda pilih.

```powershell
$RunnerIp = '100.64.0.10'

tailscale status
tailscale ping $RunnerIp

# Windows RDP atau Linux XRDP
Test-NetConnection $RunnerIp -Port 3389
mstsc "/v:$RunnerIp"

# Windows noVNC dengan Active transport = tailscale_tcp
Test-NetConnection $RunnerIp -Port 6082
curl.exe --noproxy "*" --max-time 15 -sS -o NUL -w "HTTP %{http_code}\n" "http://$($RunnerIp):6082/vnc.html"

# macOS SSH. Ganti wfsremote jika username di Summary berbeda.
Test-NetConnection $RunnerIp -Port 2222
ssh -p 2222 "wfsremote@$RunnerIp"
```

Ping atau port yang merespons belum berarti login berhasil. Untuk desktop interaktif, buka aplikasi sederhana dari klien, lalu pastikan mouse dan keyboard mengubah isi sesi yang sedang Anda lihat.

</details>

## Verifikasi dan dokumentasi

**Cara memastikan sesi Anda benar-benar bisa dipakai**

1. **Jaringan.** Periksa node dan port dari klien menggunakan alamat dari Summary.
2. **Login.** Pastikan sesi desktop terbuka setelah autentikasi. Untuk SSH, pastikan `whoami` menunjukkan akun yang sesuai.
3. **Interaksi.** Buka aplikasi ringan dengan mouse, lalu ketik teks pendek. Screenshot macOS saja tidak memenuhi tahap ini.
4. **Aplikasi.** Periksa hasil instalasi di Summary/log, lalu jalankan aplikasi dari sesi yang tepat.

| Bukti historis | Cakupan uji |
| --- | --- |
| [Windows · #42924327969](https://github.com/wawanwfs/RDP/actions/runs/42924327969) | Verifikasi tanda tangan installer dan executable MT4/MT5 native. Bukan uji broker atau EA |
| [Linux · #42925180890](https://github.com/wawanwfs/RDP/actions/runs/42925180890) | Login XRDP KDE dan pemeriksaan transport Tailscale pada lingkungan uji |
| [macOS · #43258055630](https://github.com/wawanwfs/RDP/actions/runs/43258055630) | SSH lokal Apple Silicon/Intel dan pemeriksaan screenshot. Tidak membuktikan klik atau keyboard via Apple VNC |

Run tersebut adalah hasil historis, bukan status CI live untuk `main`. Gunakan Summary dari run Anda untuk memeriksa kondisi sesi saat ini.

| Rujukan | Isi |
| --- | --- |
| [Actions dan Summary](https://github.com/wawanwfs/RDP/actions) | Status instalasi, hasil probe dari runner, dan alamat koneksi untuk setiap run |
| [Matriks acceptance](docs/ACCEPTANCE_MATRIX.md) | Bukti uji terdahulu dan checklist untuk pengujian dari perangkat klien |
| [Panduan Linux](linux/README.md) | Kombinasi distro/desktop, transport, opsi aplikasi, dan diagnosis XRDP |
| [Panduan macOS](macos/README.md) dan [Controller Windows](macos/WINDOWS_CONTROL.md) | SSH, preview, diagnosis Screen Sharing, dan kriteria lulus kendali input |
| [Workflow Multi-OS lama](.github/workflows/multi-os-remote.yml) | Workflow lama yang dapat menampilkan kredensial sementara di log atau Summary. Untuk setup baru, gunakan salah satu dari tiga workflow utama |

Saat melaporkan masalah, sertakan **URL run, sistem operasi, mode akses, dan gejala dari perangkat klien**. Hapus password, token, dan informasi tailnet yang tidak perlu dari cuplikan log.

---

<div align="center">

**WFS Tech · Build. Connect. Test.**

</div>

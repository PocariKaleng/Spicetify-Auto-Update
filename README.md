# Spicetify Auto Update

Auto updater Windows untuk Spicetify. Menerapkan ulang tema dan extension setelah Spotify berubah, dengan pilihan restart otomatis saat patch hilang.

## Pasang dengan satu command

Jalankan di **PowerShell biasa**, menggunakan akun Windows yang menjalankan Spotify:

```powershell
irm https://raw.githubusercontent.com/PocariKaleng/Spicetify-Auto-Update/main/install.ps1 | iex
```

Spotify desktop harus sudah terpasang dan pernah dibuka serta login. Jika Spicetify belum ada, tutup Spotify terlebih dahulu; installer mengambil CLI dari rilis resmi. Instalasi melalui Scoop, Chocolatey, atau WinGet perlu diperbarui melalui package manager masing-masing.

Command ini bisa dijalankan ulang untuk memperbarui skrip updater. Satu task Windows bernama `Spicetify Auto Update` digunakan kembali.

Agar tema pulih otomatis meskipun Spotify sedang terbuka setelah update, aktifkan restart otomatis:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/PocariKaleng/Spicetify-Auto-Update/main/install.ps1))) -AutoRestart
```

Spotify akan ditutup dan dibuka kembali ketika patch hilang; pemutaran musik bisa terhenti. Pilihan ini dipertahankan saat installer dijalankan ulang. Gunakan `-AutoRestart:$false` untuk kembali menunggu Spotify ditutup.

## Elaina Glass + foto sendiri

Tema kaca gelap dengan aksen lavender, wallpaper lokal, dan tombol bintang **Elaina Glass** di kiri atas Spotify. Tombolnya menyediakan preset Portrait / Balanced / Focus, kegelapan foto, kepekatan panel, blur, aksen Lavender / Moonlight / Rose, dan daftar lagu rapat. Pengaturan tampilan tersimpan otomatis.

Home memakai latar foto yang menyambung tanpa gradient hitam bawaan. Sudut panel seragam, pemutar sejajar dengan library, serta toolbar dan panel lyrics memakai warna yang selaras. Preset Balanced: foto 40%, panel 50%, blur 2 px.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/PocariKaleng/Spicetify-Auto-Update/main/install.ps1))) -WallpaperPath "$env:USERPROFILE\Pictures\wallpaper.jpg"
```

Gunakan foto JPG/JPEG. Pemasangan tema me-restart Spotify agar tampil langsung. Foto disalin ke folder tema lokal dan tidak diunggah ke GitHub. Marketplace dan extension yang sudah aktif tetap dipertahankan. Repo ini berisi kode tema; ilustrasi Elaina tidak disertakan.

## Cara kerjanya

- Berjalan 2 menit setelah login Windows, kemudian setiap 5 menit selama akun masih login.
- Secara default, Spotify yang terbuka ditunggu sampai ditutup. Dengan `-AutoRestart`, patch yang hilang memicu restart dan pemulihan; Spotify yang masih terpasang patch tetap dibiarkan berjalan.
- Task memakai `wscript.exe` dan peluncur tersembunyi agar jendela PowerShell tidak berkedip ketika dimulai.
- Mengecek rilis stabil resmi Spicetify maksimal sekali dalam 24 jam saat Spotify ditutup.
- Memverifikasi checksum SHA-256 apabila disediakan oleh GitHub.
- Mendeteksi perubahan Spotify, konfigurasi, berkas tema, dan wallpaper; menerapkan ulang patch jika diperlukan.
- Perubahan berkas tema saja memakai `refresh`, sehingga Spotify tidak dikembalikan ke tampilan bawaan selama prosesnya.
- Jika Spotify dibuka di tengah pemasangan patch penuh, mode restart otomatis membuka ulang Spotify; mode default mencatat kebutuhan restart di log.
- Error dicatat dan dicoba lagi pada jadwal berikutnya; tidak mengubah konfigurasi ke tema default.
- Jika pemulihan otomatis gagal, Spotify tetap dibuka kembali dan restart berikutnya ditunda 30 menit.

Updater mendukung instalasi desktop Windows yang dapat ditulis oleh akun pengguna. Pembaruan Spotify bisa membutuhkan rilis Spicetify baru; script tidak bisa membuat versi CLI yang belum tersedia menjadi kompatibel.

## Command manual

Tutup Spotify untuk menjalankan pengecekan sekarang:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\spicetify\AutoUpdate\update.ps1" -CheckNow
```

Status dan log:

```powershell
Get-ScheduledTaskInfo -TaskName 'Spicetify Auto Update'
Get-Content "$env:LOCALAPPDATA\spicetify\AutoUpdate\update.log" -Tail 20
```

Matikan / aktifkan kembali:

```powershell
Disable-ScheduledTask -TaskName 'Spicetify Auto Update'
Enable-ScheduledTask -TaskName 'Spicetify Auto Update'
```

Hapus task otomatis, sambil menyimpan Spicetify dan tema:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\spicetify\AutoUpdate\uninstall.ps1"
```

## Kembali ke tema sebelumnya

Installer tema menyimpan `config-before-theme-*.ini` di `%LOCALAPPDATA%\spicetify\AutoUpdate`. Salin backup yang diinginkan ke lokasi yang ditampilkan `spicetify --config`, lalu jalankan `spicetify apply`.

## Pengujian

```powershell
./tests/check.ps1
node --check ./themes/ElainaGlass/theme.js
```

Tes memeriksa progres native pada stderr dan exit code Windows PowerShell 5.1, parsing konfigurasi, jeda 24 jam, pemilihan perintah repair untuk stock/mixed/applied Spotify, dan deteksi perubahan tema. GitHub Actions menjalankannya di Windows.

Tema ini diperiksa pada Spotify desktop 1.2.95, 1.3.4, dan 1.3.5 dengan Spicetify 2.45.3: wallpaper lokal, preset, aksen, reset, persistensi pengaturan, dan kontrol keyboard. Fitur Marketplace/extension tetap mengikuti dukungan versi Spicetify masing-masing.

Referensi: [Spicetify resmi](https://spicetify.app/docs/getting-started), [struktur tema](https://spicetify.app/docs/development/themes), [deteksi status Spotify](https://github.com/spicetify/cli/blob/main/src/status/spotify/spotify.go).

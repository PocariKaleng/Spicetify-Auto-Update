$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName 'Spicetify Auto Update' -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName 'Spicetify Auto Update'
    Unregister-ScheduledTask -TaskName 'Spicetify Auto Update' -Confirm:$false
}
Write-Host 'Auto update dinonaktifkan. Spicetify, tema, foto, konfigurasi, dan log tetap tersimpan.'

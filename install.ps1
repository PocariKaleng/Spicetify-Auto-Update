param(
    [string]$WallpaperPath,
    [string]$SourceDirectory = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
$runtimeRoot = Join-Path $localAppData 'spicetify\AutoUpdate'
$repoBase = 'https://raw.githubusercontent.com/PocariKaleng/Spicetify-Auto-Update/main'
$command = Get-Command spicetify -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$spiceExe = if ($command) { $command.Source } else { Join-Path $localAppData 'spicetify\spicetify.exe' }
if ($spiceExe -match '\\(scoop|chocolatey|WinGet)\\') { throw 'This updater supports the official direct install. Update package-manager installations with their own package manager.' }
if ($WallpaperPath -and (-not (Test-Path -LiteralPath $WallpaperPath -PathType Leaf) -or [IO.Path]::GetExtension($WallpaperPath) -notmatch '^\.jpe?g$')) { throw 'WallpaperPath must point to an existing JPG/JPEG file.' }
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
function Save-RepoFile([string]$RelativePath, [string]$Destination) {
    $source = if ($SourceDirectory) { Join-Path $SourceDirectory $RelativePath } else { $null }
    if ($source -and (Test-Path -LiteralPath $source -PathType Leaf)) {
        if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($Destination)) { Copy-Item -LiteralPath $source -Destination $Destination -Force }
    } else { Invoke-WebRequest -UseBasicParsing -Uri "$repoBase/$RelativePath" -OutFile $Destination -TimeoutSec 60 }
}
# Reinstalling replaces the same task; it never creates a second updater.
$existingTask = Get-ScheduledTask -TaskName 'Spicetify Auto Update' -ErrorAction SilentlyContinue
if ($existingTask) { Stop-ScheduledTask -TaskName 'Spicetify Auto Update' }
foreach ($file in @('common.ps1', 'update.ps1', 'uninstall.ps1', 'run-hidden.vbs')) { Save-RepoFile $file (Join-Path $runtimeRoot $file) }
# Load the downloaded helper like the inline installer, without changing policy.
. ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $runtimeRoot 'common.ps1') -Raw)))
if (-not (Test-Path -LiteralPath $spiceExe)) {
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) { throw 'Close Spotify before the first Spicetify installation, then rerun this command.' }
    $release = Invoke-RestMethod 'https://api.github.com/repos/spicetify/cli/releases/latest' -TimeoutSec 60
    Install-SpiceRelease $spiceExe $release $runtimeRoot
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $spiceFolder = Split-Path $spiceExe
    if (($userPath -split ';') -notcontains $spiceFolder) { [Environment]::SetEnvironmentVariable('Path', "$userPath;$spiceFolder", 'User') }
    & $spiceExe | Out-Host
}
$context = Get-SpiceContext $spiceExe
if ($WallpaperPath) {
    $themeRoot = Join-Path (Split-Path $context.ConfigPath) 'Themes\ElainaGlass'
    New-Item -ItemType Directory -Path (Join-Path $themeRoot 'assets') -Force | Out-Null
    $backupPath = Join-Path $runtimeRoot ('config-before-theme-{0:yyyyMMdd-HHmmss}.ini' -f (Get-Date))
    Copy-Item -LiteralPath $context.ConfigPath -Destination $backupPath
    foreach ($file in @('color.ini', 'user.css', 'theme.js')) { Save-RepoFile "themes/ElainaGlass/$file" (Join-Path $themeRoot $file) }
    Copy-Item -LiteralPath $WallpaperPath -Destination (Join-Path $themeRoot 'assets\elaina-wallpaper.jpg') -Force
    & $spiceExe config current_theme ElainaGlass color_scheme Lavender inject_css 1 inject_theme_js 1 replace_colors 1 overwrite_assets 1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Theme configuration failed.' }
    $index = Join-Path $context.Apps 'xpui\index.html'
    if ((Test-Path -LiteralPath $index) -and (Get-Content -LiteralPath $index -Raw) -match 'spicetifyWrapper\.js') { & $spiceExe apply | Out-Host }
    else { & $spiceExe backup apply | Out-Host }
    if ($LASTEXITCODE -ne 0) { throw 'Theme application failed.' }
}
@{ SpicetifyExecutable = $spiceExe } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtimeRoot 'settings.json') -Encoding UTF8
# Invalidate the old updater's state, so the first idle run verifies everything.
@{ LastReleaseCheck = ''; AppliedFingerprint = '' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtimeRoot 'state.json') -Encoding UTF8
$userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\wscript.exe') -Argument ('//B //Nologo "{0}"' -f (Join-Path $runtimeRoot 'run-hidden.vbs')) -WorkingDirectory $runtimeRoot
$logon = New-ScheduledTaskTrigger -AtLogOn -User $userId
$logon.Delay = 'PT2M'
$hourly = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName 'Spicetify Auto Update' -Action $action -Trigger @($logon, $hourly) -Principal $principal -Settings $settings -Description 'Check official Spicetify releases daily; repair patches hourly while Spotify is closed.' -Force | Out-Null
Start-ScheduledTask -TaskName 'Spicetify Auto Update'
Write-Host 'Spicetify Auto Update aktif. Cek setiap jam, rilis terbaru sekali sehari. Spotify yang terbuka tidak akan dihentikan.' -ForegroundColor Green
Write-Host "Log: $(Join-Path $runtimeRoot 'update.log')"

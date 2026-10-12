function Read-SpiceIni([string]$Path) {
    $result = @{}; $section = ''
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*\[([^\]]+)\]\s*$') {
            $section = $Matches[1]; $result[$section] = @{}
        } elseif ($section -and $line -match '^\s*([^;#=]+?)\s*=\s*(.*?)\s*$') {
            $result[$section][$Matches[1].Trim()] = $Matches[2]
        }
    }
    return $result
}
function Get-SpiceVersion([string]$Executable) {
    $version = (& $Executable --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^\d+\.\d+\.\d+$') { throw 'Cannot read Spicetify version.' }
    return $version
}
function Invoke-SpiceCaptured([string]$Executable, [string[]]$CommandArguments) {
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { throw 'Spicetify executable was not found.' }
    $previousPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 turns redirected native stderr into error records.
        # Spicetify writes progress there; only the exit code indicates failure.
        $ErrorActionPreference = 'Continue'
        $output = @(& $Executable @CommandArguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    return @{ ExitCode = $code; Output = $output }
}
function Get-SpiceContext([string]$Executable) {
    $configPath = (& $Executable --config | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $configPath)) { throw 'Spicetify configuration is missing. Open Spotify and sign in first.' }
    $ini = Read-SpiceIni $configPath
    $spotifyRoot = $ini.Setting.spotify_path
    if (-not $spotifyRoot -or -not (Test-Path -LiteralPath (Join-Path $spotifyRoot 'Spotify.exe'))) { throw 'Configured Spotify desktop installation was not found.' }
    return @{ ConfigPath = $configPath; Config = $ini; SpotifyRoot = $spotifyRoot; Apps = (Join-Path $spotifyRoot 'Apps') }
}
function Get-SpiceFingerprint([string]$Executable, $Context) {
    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add((Get-SpiceVersion $Executable))
    $parts.Add((Get-Item -LiteralPath (Join-Path $Context.SpotifyRoot 'Spotify.exe')).VersionInfo.ProductVersion)
    $files = @($Context.ConfigPath, (Join-Path $Context.Apps 'xpui\index.html'))
    $files += @(Get-ChildItem -LiteralPath $Context.Apps -Filter '*.spa' -File | Sort-Object Name | ForEach-Object { $_.FullName })
    $theme = $Context.Config.Setting.current_theme
    if ($theme) {
        $themeRoot = Join-Path (Split-Path $Context.ConfigPath) "Themes\$theme"
        if (-not (Test-Path -LiteralPath $themeRoot)) { $themeRoot = Join-Path (Split-Path $Executable) "Themes\$theme" }
        if (Test-Path -LiteralPath $themeRoot) { $files += @(Get-ChildItem -LiteralPath $themeRoot -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName }) }
    }
    foreach ($file in $files) {
        $parts.Add($(if (Test-Path -LiteralPath $file) { (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash } else { 'missing' }))
    }
    return ($parts -join '|')
}
function Test-SpiceReleaseDue($State, [bool]$CheckNow) {
    if ($CheckNow -or -not $State.LastReleaseCheck) { return $true }
    return ([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($State.LastReleaseCheck)).TotalHours -ge 24
}
function Get-SpiceRepairCommands([string]$Apps) {
    # Matches spicetify/cli/src/status/spotify: .spa files mean stock/mixed.
    if (@(Get-ChildItem -LiteralPath $Apps -Filter '*.spa' -File).Count -gt 0) { return @('backup', 'apply', '--no-restart') }
    return @('restore', 'backup', 'apply', '--no-restart', '--quiet')
}
function Install-SpiceRelease([string]$Executable, $Release, [string]$RuntimeRoot) {
    if ($Release.tag_name -notmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid official release version.' }
    $version = $Release.tag_name.Substring(1)
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } elseif ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x32' }
    $asset = $Release.assets | Where-Object { $_.name -eq "spicetify-$version-windows-$arch.zip" } | Select-Object -First 1
    if (-not $asset -or $asset.browser_download_url -notlike "https://github.com/spicetify/cli/releases/download/v$version/*") { throw 'Official Windows release asset was not found.' }
    $archive = Join-Path $RuntimeRoot 'release.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $archive -TimeoutSec 120
    if ($asset.digest -like 'sha256:*' -and (Get-FileHash -LiteralPath $archive).Hash -ne $asset.digest.Substring(7)) { throw 'Release checksum verification failed.' }
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) { throw 'Spotify opened during download. Update deferred until the next run.' }
    Expand-Archive -LiteralPath $archive -DestinationPath (Split-Path $Executable) -Force
    Remove-Item -LiteralPath $archive -Force
    if ((Get-SpiceVersion $Executable) -ne $version) { throw 'Installed release version does not match.' }
}

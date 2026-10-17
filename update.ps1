param([switch]$CheckNow)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot 'common.ps1')
$logPath = Join-Path $PSScriptRoot 'update.log'
$statePath = Join-Path $PSScriptRoot 'state.json'
$lock = $null
$restartSpotifyPath = $null
function Write-UpdateLog([string]$Message) {
    Add-Content -LiteralPath $logPath -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message)
}
function Close-SpotifyForRecovery([string]$SpotifyRoot, [string]$Reason) {
    $script:restartSpotifyPath = Join-Path $SpotifyRoot 'Spotify.exe'
    Write-UpdateLog "Recovery: $Reason"
    Get-Process -Name Spotify -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}
try {
    try { $lock = [IO.File]::Open((Join-Path $PSScriptRoot 'updater.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { exit 0 }
    if ((Test-Path -LiteralPath $logPath) -and (Get-Item -LiteralPath $logPath).Length -gt 1048576) { Move-Item -LiteralPath $logPath -Destination "$logPath.previous" -Force }
    $settings = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'settings.json') -Raw | ConvertFrom-Json
    $spiceExe = $settings.SpicetifyExecutable
    $context = Get-SpiceContext $spiceExe
    $state = @{ LastReleaseCheck = ''; AppliedFingerprint = ''; RecoveryRetryAfter = '' }
    if (Test-Path -LiteralPath $statePath) {
        $saved = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $state.LastReleaseCheck = $saved.LastReleaseCheck
        $state.AppliedFingerprint = $saved.AppliedFingerprint
        $state.RecoveryRetryAfter = $saved.RecoveryRetryAfter
    }
    $autoRestart = [bool]$settings.AutoRestart
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) {
        if (-not $autoRestart -or (Test-SpicePatchApplied $context.Apps)) {
            Write-UpdateLog 'Deferred: Spotify is running. Will retry in 5 minutes.'
            exit 0
        }
        if (-not (Test-SpiceRecoveryDue $state)) {
            Write-UpdateLog "Deferred: automatic recovery retry after $($state.RecoveryRetryAfter)."
            exit 0
        }
        Close-SpotifyForRecovery $context.SpotifyRoot 'Spotify patch is missing; closing Spotify for automatic repair.'
    }
    if (Test-SpiceReleaseDue $state ([bool]$CheckNow)) {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/spicetify/cli/releases/latest' -TimeoutSec 60
        $before = Get-SpiceVersion $spiceExe
        if ([version]$release.tag_name.TrimStart('v') -gt [version]$before) {
            Install-SpiceRelease $spiceExe $release $PSScriptRoot
            Write-UpdateLog "Updated Spicetify from $before to $(Get-SpiceVersion $spiceExe)."
        }
        $state.LastReleaseCheck = [DateTimeOffset]::UtcNow.ToString('o')
    }
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) {
        if ($autoRestart -and -not (Test-SpicePatchApplied $context.Apps)) {
            Close-SpotifyForRecovery $context.SpotifyRoot 'Spotify opened before patching; completing automatic repair.'
        } else {
            Write-UpdateLog 'Deferred: Spotify opened before patching.'
            exit 0
        }
    }
    $fingerprint = Get-SpiceFingerprint $spiceExe $context
    $isPatched = Test-SpicePatchApplied $context.Apps
    if ($fingerprint -ne $state.AppliedFingerprint -or -not $isPatched) {
        $commands = if ($isPatched) { Get-SpiceRepairCommands $context.Apps $state.AppliedFingerprint $fingerprint }
                    else { Get-SpiceRepairCommands $context.Apps }
        if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) {
            if ($autoRestart -and -not $isPatched) {
                Close-SpotifyForRecovery $context.SpotifyRoot 'Spotify opened before repair; completing automatic repair.'
            } else {
                Write-UpdateLog 'Deferred: Spotify opened before repair.'
                exit 0
            }
        }
        Write-UpdateLog ('Repair: ' + ($commands -join ' '))
        $run = Invoke-SpiceCaptured $spiceExe $commands
        $run.Output | ForEach-Object { Write-UpdateLog (([string]$_) -replace '\x1b\[[0-9;]*[mK]', '') }
        if ($run.ExitCode -ne 0) { throw "Spicetify repair exited with code $($run.ExitCode)." }
        if (-not (Test-SpicePatchApplied $context.Apps)) { throw 'Spicetify injection could not be verified.' }
        $context = Get-SpiceContext $spiceExe
        $state.AppliedFingerprint = Get-SpiceFingerprint $spiceExe $context
        $state.RecoveryRetryAfter = ''
        Write-UpdateLog 'Verified: patch reapplied; existing theme and local wallpaper preserved.'
        if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) {
            if ($autoRestart) {
                Close-SpotifyForRecovery $context.SpotifyRoot 'Spotify opened during repair; restarting to load the patched files.'
            } else {
                Write-UpdateLog 'Restart needed: Spotify opened during repair. Reopen Spotify to load the patched files.'
            }
        }
    } else { Write-UpdateLog "Healthy: Spicetify $(Get-SpiceVersion $spiceExe); no changes needed." }
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    exit 0
} catch {
    $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { ($_ | Out-String).Trim() }
    Write-UpdateLog "ERROR: $errorMessage"
    if ($restartSpotifyPath) {
        # An unsupported Spotify release must not cause repeated restarts.
        $state.RecoveryRetryAfter = [DateTimeOffset]::UtcNow.AddMinutes(30).ToString('o')
        $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    }
    exit 1
} finally {
    try {
        if ($restartSpotifyPath) {
            # Reopen even after a failed repair, so recovery cannot leave Spotify closed.
            Start-Process -FilePath $restartSpotifyPath -WindowStyle Normal
            Write-UpdateLog 'Recovery: Spotify reopened.'
        }
    } finally {
        if ($lock) { $lock.Dispose() }
    }
}

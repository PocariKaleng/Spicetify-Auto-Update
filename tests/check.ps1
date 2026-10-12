$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot
. (Join-Path $repoRoot 'common.ps1')
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$tokens = $null; $errors = $null
Get-ChildItem -LiteralPath $repoRoot -Filter '*.ps1' | ForEach-Object {
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    Assert-True ($errors.Count -eq 0) "Syntax error: $($_.Name)"
}
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('spicetify-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $childPath = Join-Path $tempRoot 'native-command.ps1'
    Set-Content -LiteralPath $childPath -Value "[Console]::Error.WriteLine('progress'); Write-Output 'done'; exit 0"
    $nativePS = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $run = Invoke-SpiceCaptured $nativePS @('-NoProfile', '-File', $childPath)
    Assert-True ($run.ExitCode -eq 0) 'Native progress on stderr must not stop a successful repair.'
    Assert-True (($run.Output -join ' ') -match 'progress') 'Native diagnostics were lost.'
    Set-Content -LiteralPath $childPath -Value "[Console]::Error.WriteLine('failure'); exit 7"
    $failed = Invoke-SpiceCaptured $nativePS @('-NoProfile', '-File', $childPath)
    Assert-True ($failed.ExitCode -eq 7) 'Nonzero native exit codes must be preserved.'
    $iniPath = Join-Path $tempRoot 'config.ini'
    @'
; header
[Setting]
spotify_path = C:\Users\Test User\Spotify
current_theme = MyTheme
spotify_launch_flags = --foo=bar
[Backup]
version = 1.2.95.453.gexample
'@ | Set-Content -LiteralPath $iniPath
    $ini = Read-SpiceIni $iniPath
    Assert-True ($ini.Setting.spotify_path -eq 'C:\Users\Test User\Spotify') 'Path with spaces was changed.'
    Assert-True ($ini.Setting.spotify_launch_flags -eq '--foo=bar') 'Equals sign in config value was lost.'
    Assert-True ($ini.Backup.version -eq '1.2.95.453.gexample') 'Backup section was not parsed.'
    Assert-True (Test-SpiceReleaseDue @{ LastReleaseCheck = '' } $false) 'First run must check releases.'
    Assert-True (-not (Test-SpiceReleaseDue @{ LastReleaseCheck = [DateTimeOffset]::UtcNow.AddHours(-2).ToString('o') } $false)) 'Daily limit was ignored.'
    Assert-True (Test-SpiceReleaseDue @{ LastReleaseCheck = [DateTimeOffset]::UtcNow.AddHours(-25).ToString('o') } $false) 'Expired check was skipped.'
    Assert-True (Test-SpiceReleaseDue @{ LastReleaseCheck = [DateTimeOffset]::UtcNow.ToString('o') } $true) 'CheckNow did not bypass daily limit.'
    Assert-True ((Get-SpiceRepairCommands $tempRoot) -join ' ' -eq 'restore backup apply --no-restart --quiet') 'Applied Spotify needs a restore before backup.'
    $stockFile = Join-Path $tempRoot 'xpui.spa'
    Set-Content -LiteralPath $stockFile -Value 'stock'
    Assert-True ((Get-SpiceRepairCommands $tempRoot) -join ' ' -eq 'backup apply --no-restart') 'Stock/mixed Spotify must back up new stock files.'
    # Stub the CLI dependency; verify fingerprints against actual changed files.
    function Get-SpiceVersion { return '2.45.3' }
    Set-Content -LiteralPath (Join-Path $tempRoot 'Spotify.exe') -Value ''
    $context = @{ ConfigPath = $iniPath; Config = $ini; SpotifyRoot = $tempRoot; Apps = $tempRoot }
    $fakeExe = Join-Path $tempRoot 'fake.exe'
    $themeRoot = Join-Path $tempRoot 'Themes\MyTheme'
    New-Item -ItemType Directory -Path $themeRoot -Force | Out-Null
    $cssPath = Join-Path $themeRoot 'user.css'
    Set-Content -LiteralPath $cssPath -Value 'body { background: red; }'
    $first = Get-SpiceFingerprint $fakeExe $context
    Set-Content -LiteralPath $stockFile -Value 'new Spotify resources'
    Assert-True ((Get-SpiceFingerprint $fakeExe $context) -ne $first) 'Stock resource changes must trigger repair.'
    $second = Get-SpiceFingerprint $fakeExe $context
    Add-Content -LiteralPath $iniPath -Value 'with = 2.46.0'
    Assert-True ((Get-SpiceFingerprint $fakeExe $context) -ne $second) 'Configuration changes must trigger repair.'
    $third = Get-SpiceFingerprint $fakeExe $context
    Set-Content -LiteralPath $cssPath -Value 'body { background: blue; }'
    Assert-True ((Get-SpiceFingerprint $fakeExe $context) -ne $third) 'Theme edits must trigger repair.'
    Write-Host 'PASS: native stderr/exit codes, syntax, INI paths/values, daily checks, repair selection, change detection.' -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath (Join-Path $tempRoot 'Themes\MyTheme\user.css')) {
        Remove-Item -LiteralPath (Join-Path $tempRoot 'Themes\MyTheme\user.css') -Force
        Remove-Item -LiteralPath (Join-Path $tempRoot 'Themes\MyTheme') -Force
        Remove-Item -LiteralPath (Join-Path $tempRoot 'Themes') -Force
    }
    Get-ChildItem -LiteralPath $tempRoot -File | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Remove-Item -LiteralPath $tempRoot -Force
}

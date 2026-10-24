# Hidden worker for Metro NR graphical installer.
param(
    [Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Action,
    [Parameter(Mandatory=$true)][string]$GameDir,
    [ValidateSet('2033','LastLight')][string]$Game = '2033',
    [Parameter(Mandatory=$true)][string]$LogPath,
    [ValidateSet('Keep','Browse','Build','Url')][string]$NrMode = 'Keep',
    [string]$NrDllPath = '',
    [string]$NrDownloadUrl = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$encoding = New-Object System.Text.UTF8Encoding($false)
function Log-Line([string]$Line) {
    [System.IO.File]::AppendAllText($LogPath, $Line + [Environment]::NewLine, $encoding)
}
try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null
    [System.IO.File]::WriteAllText($LogPath, '', $encoding)
    Log-Line ('[INFO] Metro NR Setup - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    Log-Line ('[INFO] Action: ' + $Action)
    Log-Line ('[INFO] Game: ' + $Game)
    Log-Line ('[INFO] Game folder: ' + $GameDir)
    Log-Line ('[STEP] ' + $(if ($Action -eq 'Install') { 'Checking prerequisites...' } else { 'Checking installed mod...' }))
    if ($Action -eq 'Install') {
        & (Join-Path $PSScriptRoot 'Install.ps1') -GameDir $GameDir -Game $Game -NrMode $NrMode -NrDllPath $NrDllPath -NrDownloadUrl $NrDownloadUrl *>&1 | ForEach-Object {
            $line = ($_ | Out-String).TrimEnd()
            if ($line) { Log-Line $line }
        }
    } else {
        & (Join-Path $PSScriptRoot 'Uninstall.ps1') -GameDir $GameDir -Game $Game *>&1 | ForEach-Object {
            $line = ($_ | Out-String).TrimEnd()
            if ($line) { Log-Line $line }
        }
    }
    Log-Line '[RESULT] SUCCESS'
    exit 0
} catch {
    Log-Line ('[ERROR] ' + $_.Exception.Message)
    Log-Line ('[ERROR] ' + ($_ | Out-String).TrimEnd())
    Log-Line '[RESULT] FAILED'
    exit 1
}
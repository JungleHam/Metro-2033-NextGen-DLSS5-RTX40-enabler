param([string]$GameDir = '')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
$GameDir = Resolve-MetroGameDir -Candidate $GameDir
if (Get-Process -Name metro -ErrorAction SilentlyContinue) { throw 'Close Metro before switching tests.' }
if (!(Test-Path (Join-Path $GameDir 'MetroNRGpuSpoof.install.sha256'))) { throw 'Run Install.cmd before enabling the bridge.' }
Set-Content -LiteralPath (Join-Path $GameDir 'MetroNRFeature18Probe.on') -Value '1' -Encoding ascii
Set-Content -LiteralPath (Join-Path $GameDir 'MetroNRDirectSnippet.on') -Value '1' -Encoding ascii
Write-Host 'Direct snippet test enabled. Close game and run DisableDirect.cmd to roll back.' -ForegroundColor Yellow

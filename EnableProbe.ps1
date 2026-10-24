param([string]$GameDir = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
$GameDir = Resolve-MetroGameDir -Candidate $GameDir
if (Get-Process -Name metro -ErrorAction SilentlyContinue) { throw 'Exit Metro completely before changing probe mode.' }
if (!(Test-Path (Join-Path $GameDir 'MetroNRGpuSpoof.install.sha256'))) { throw 'Run Install.cmd before enabling the probe.' }
Set-Content -LiteralPath (Join-Path $GameDir 'MetroNRFeature18Probe.on') -Value '1' -Encoding ascii
Write-Host 'Diagnostic query override ENABLED for the next Metro launch.' -ForegroundColor Yellow

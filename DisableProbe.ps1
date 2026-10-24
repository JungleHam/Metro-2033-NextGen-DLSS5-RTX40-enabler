param([string]$GameDir = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
$GameDir = Resolve-MetroGameDir -Candidate $GameDir
if (Get-Process -Name metro -ErrorAction SilentlyContinue) { throw 'Exit Metro completely before changing probe mode.' }
$marker = Join-Path $GameDir 'MetroNRFeature18Probe.on'
if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
Write-Host 'Diagnostic query override DISABLED.' -ForegroundColor Green

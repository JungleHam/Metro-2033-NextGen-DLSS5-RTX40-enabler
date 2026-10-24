param([string]$GameDir = '')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
$GameDir = Resolve-MetroGameDir -Candidate $GameDir
if (Get-Process -Name metro -ErrorAction SilentlyContinue) { throw 'Close Metro before switching tests.' }
foreach ($name in @('MetroNRDirectSnippet.on','MetroNRFeature18Probe.on')) {
 $path = Join-Path $GameDir $name
 if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
Write-Host 'Both direct-snippet and requirements probes disabled.' -ForegroundColor Green

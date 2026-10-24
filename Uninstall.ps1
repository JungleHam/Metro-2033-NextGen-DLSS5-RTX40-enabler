param(
    [string]$GameDir = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
$GameDir = Resolve-MetroGameDir -Candidate $GameDir
Set-StrictMode -Version Latest
if (Get-Process -Name metro -ErrorAction SilentlyContinue) { throw 'Close Metro before uninstalling.' }
$target = Join-Path $GameDir 'dinput8.dll'
$marker = Join-Path $GameDir 'MetroNRGpuSpoof.install.sha256'
if (!(Test-Path $marker)) { throw 'Install marker absent: refusing to delete an unknown dinput8.dll.' }
if (!(Test-Path $target)) { throw 'No dinput8.dll found. Nothing to remove; marker retained.' }
$expected = (Get-Content $marker -Raw).Trim()
$actual = (Get-FileHash $target -Algorithm SHA256).Hash
if ($expected -ne $actual) {
    throw 'dinput8.dll differs from the installed file. Refusing to delete someone else''s mod.'
}
Remove-Item -LiteralPath $target
Remove-Item -LiteralPath $marker
$probeMarker = Join-Path $GameDir 'MetroNRFeature18Probe.on'
if (Test-Path -LiteralPath $probeMarker) { Remove-Item -LiteralPath $probeMarker -Force }
Write-Host 'Removed GPU spoof proxy. NR DLL, configurator, logs and backups are untouched.' -ForegroundColor Green

$extra = Join-Path $GameDir "MetroNRDirectSnippet.on"
if (Test-Path -LiteralPath $extra) { Remove-Item -LiteralPath $extra -Force }

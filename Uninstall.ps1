param(
    [string]$GameDir = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
Write-Host '[STEP] Finding your Metro installation...' 
$GameDir = Resolve-MetroGameDir -Candidate $GameDir
Set-StrictMode -Version Latest
if (Get-Process -Name metro -ErrorAction SilentlyContinue) { throw 'Close Metro before uninstalling.' }
$target = Join-Path $GameDir 'dinput8.dll'
$marker = Join-Path $GameDir 'MetroNRGpuSpoof.install.sha256'
if (!(Test-Path $target)) { throw 'No dinput8.dll found. Nothing to remove.' }
Write-Host '[STEP] Verifying the mod belongs to this installer...'
$actual = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if (Test-Path $marker) {
    $expected = (Get-Content -LiteralPath $marker -Raw).Trim()
} else {
    # Recognize only the exact v0.9.2 file from the successful test.
    $expected = '2083A4009DCA2451B905B1D97C9787EA69E654307DC970613590102A0B7178B6'
}
if ($expected -ne $actual) {
    throw 'dinput8.dll is not one of our verified mod files. Refusing to delete another mod.'
}
Write-Host '[STEP] Removing the mod files...'
Remove-Item -LiteralPath $target
if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
$probeMarker = Join-Path $GameDir 'MetroNRFeature18Probe.on'
if (Test-Path -LiteralPath $probeMarker) { Remove-Item -LiteralPath $probeMarker -Force }
Write-Host 'Removed GPU spoof proxy. NR DLL, configurator, logs and backups are untouched.' -ForegroundColor Green

$extra = Join-Path $GameDir "MetroNRDirectSnippet.on"
if (Test-Path -LiteralPath $extra) { Remove-Item -LiteralPath $extra -Force }

Write-Host '[STEP] Uninstall complete!' 

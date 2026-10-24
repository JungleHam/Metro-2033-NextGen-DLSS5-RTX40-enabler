param(
    [string]$GameDir = '',
    [switch]$ForceBuild,
    [ValidateSet('Ask','Keep','Browse','Build','Url')][string]$NrMode = 'Ask',
    [string]$NrDllPath = '',
    [string]$NrDownloadUrl = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
. (Join-Path $PSScriptRoot 'NRRuntime.ps1')
$GameDir = Resolve-MetroGameDir -Candidate $GameDir -AllowPrompt
Set-StrictMode -Version Latest
$root = $PSScriptRoot
if (!(Test-Path $GameDir -PathType Container)) { throw "Game folder not found: $GameDir" }
$exe = Join-Path $GameDir 'metro.exe'
if (!(Test-Path $exe)) {
    Write-Warning 'metro.exe was not found in the supplied folder. Confirm the Next-Gen game path.'
    throw 'Invalid game directory.'
}
$target = Join-Path $GameDir 'dinput8.dll'
$marker = Join-Path $GameDir 'MetroNRGpuSpoof.install.sha256'
# Accept in-place upgrades ONLY if our existing install marker matches the DLL.
# Preserve third-party proxies and manually changed DLLs without touching them.
$upgrading = $false
if (Test-Path $target) {
    if (!(Test-Path $marker)) {
        throw "An unmanaged dinput8.dll exists at $target. Refusing to overwrite it."
    }
    $expectedHash = (Get-Content -LiteralPath $marker -Raw).Trim()
    $currentHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($expectedHash -ne $currentHash) {
        throw 'Existing dinput8.dll no longer matches the installer marker. Refusing to replace it.'
    }
    $upgrading = $true
    Write-Host 'Verified existing Metro NR GPU Spoof installation; safe in-place upgrade enabled.' -ForegroundColor Cyan
}
if (Get-Process -Name metro -ErrorAction SilentlyContinue) {
    throw 'Close Metro before installing.'
}
$gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'NVIDIA.*RTX\s*40' } | Select-Object -First 1)
if ($gpu.Count -eq 0) {
    throw 'This release was tested only with RTX 40-series GPUs. No supported RTX 40 device was detected; installation stopped.'
}
Write-Host "Detected GPU: $($gpu[0].Name)" -ForegroundColor Cyan
# Prepare and validate the DLL BEFORE replacing the game proxy or existing NR file.
$nr = Acquire-NR -GameDir $GameDir -Mode $NrMode -LocalPath $NrDllPath -DownloadUrl $NrDownloadUrl
$dll = Join-Path $root 'build\dinput8.dll'
# Release ZIPs ship a Windows CI-built DLL; source ZIPs compile locally.
# -ForceBuild always discards stale binaries and compiles the checked-out source.
if ($ForceBuild -or !(Test-Path -LiteralPath $dll)) {
    & (Join-Path $root 'Build.ps1')
} else {
    Write-Host 'Using bundled build/dinput8.dll. Use -ForceBuild to rebuild locally.' -ForegroundColor Cyan
}
if (!(Test-Path -LiteralPath $dll)) { throw 'No dinput8.dll available.' }

# Never touch the working DLSSNR DLL. Save a copy for safety.
$backup = Join-Path $root ('backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $backup | Out-Null
foreach ($name in @('nvngx_dlssnr.dll','winmm.dll','Metro2033AdvancedConfigurator.ini')) {
    $file = Join-Path $GameDir $name
    if (Test-Path $file) { Copy-Item -LiteralPath $file -Destination (Join-Path $backup $name) }
}
if ($upgrading) {
    Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'previous-dinput8.dll')
}
# Only after runtime verification do we modify game files.
if ([IO.Path]::GetFullPath($nr.File) -ine [IO.Path]::GetFullPath((Join-Path $GameDir 'nvngx_dlssnr.dll'))) {
    Copy-Item -LiteralPath $nr.File -Destination (Join-Path $GameDir 'nvngx_dlssnr.dll') -Force
}
if ($nr.Temporary) { Remove-Item -LiteralPath $nr.File -Force -ErrorAction SilentlyContinue }
Copy-Item -LiteralPath $dll -Destination $target -Force
# Native menu switch works without the optional Advanced Configurator.
Set-Content -LiteralPath (Join-Path $GameDir 'MetroNRFeature18Probe.on') -Value '1' -Encoding ascii
Set-Content -LiteralPath (Join-Path $GameDir 'MetroNRDirectSnippet.on') -Value '1' -Encoding ascii
$hash = (Get-FileHash $target -Algorithm SHA256).Hash
Set-Content -LiteralPath $marker -Value $hash -Encoding ascii
Write-Host "Installed / upgraded $target" -ForegroundColor Green
Write-Host "Backups: $backup"
Write-Host 'Ready! Start Metro, choose DLSS Quality, and enable Neural Rendering in the native video settings.' -ForegroundColor Green
Write-Host 'Advanced Configurator is optional; it is NOT required.'

# Remember user's installation location for all other scripts.
Set-Content -LiteralPath (Join-Path $PSScriptRoot '.metro-game-path') -Value $GameDir -Encoding UTF8

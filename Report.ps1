param([string]$GameDir = '', [ValidateSet('2033','LastLight')][string]$Game = '2033')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
$GameDir = Resolve-MetroGameDir -Candidate $GameDir -Game $Game
$reportDir = Join-Path $env:LOCALAPPDATA 'Metro-NR-RTX40\Reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$report = Join-Path $reportDir ('MetroNR-' + $Game + '-TestReport.txt')
$lines = New-Object System.Collections.Generic.List[string]
function Add([string]$s) { $lines.Add($s) | Out-Null }
Add ('Metro NR GPU Spoof v1.0.0 diagnostic report - ' + (Get-Date -Format o))
Add ('Game: ' + $Game)
Add ('Game folder: ' + $GameDir)
Add ('Feature18 probe marker=' + (Test-Path (Join-Path $GameDir 'MetroNRFeature18Probe.on')))
Add ('Direct snippet marker=' + (Test-Path (Join-Path $GameDir 'MetroNRDirectSnippet.on')))
foreach ($name in @('metro.exe', 'dinput8.dll', 'winmm.dll', 'nvngx_dlssnr.dll')) {
    $file = Join-Path $GameDir $name
    if (Test-Path -LiteralPath $file) {
        $item = Get-Item -LiteralPath $file
        $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        Add ('FILE ' + $name + ' SIZE=' + $item.Length + ' SHA256=' + $hash)
        if ($name -eq 'nvngx_dlssnr.dll') {
            $sig = Get-AuthenticodeSignature -LiteralPath $file
            Add ('NR Authenticode=' + $sig.Status)
            Add ('NR FileVersion=' + $item.VersionInfo.FileVersion)
        }
    } else { Add ('MISSING ' + $name) }
}
foreach ($name in @('MetroNRGpuSpoof.log','Metro2033AdvancedConfigurator.log','MetroLastLightAdvancedConfigurator.log')) {
    $log = Join-Path $GameDir $name
    if (-not (Test-Path -LiteralPath $log)) { Add ('MISSING LOG ' + $name); continue }
    Add ('--- ' + $name + ' (current process session) ---')
    $all = @(Get-Content -LiteralPath $log -ErrorAction Stop)
    if ($name -eq 'MetroNRGpuSpoof.log') {
        $indexes = @()
        for ($i=0; $i -lt $all.Count; $i++) { if ($all[$i] -match '^\[init\]') { $indexes += $i } }
        if ($indexes.Count -gt 0) { $all = @($all[$indexes[-1]..($all.Count - 1)]) }
        Add ('Log session length=' + $all.Count)
        foreach ($line in $all) { Add $line }
    } else {
        foreach ($line in ($all | Select-String -Pattern 'Neural rendering state:|Neural rendering controls:' | Select-Object -Last 12)) { Add ([string]$line) }
    }
}
$lines | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host ('Saved ' + $report) -ForegroundColor Green

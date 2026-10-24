# Runtime sourcing for Metro NR: known-good 310.9.16 Ada compatibility build.
# No NVIDIA model binaries shipped in this project.
$script:NRKnownGood = 'CDFA6C1EC784867182164C7836F324F087B5C9F374D0C9FE46F54999FEABF3ED'
$script:NROriginal = '2BC19BC09A7B89DD44F73E2AC0108FCC586E2154BDD0830F242F4F040E28789F'

function Get-NRHash([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "DLL not found: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}
function Assert-WorkingNR([string]$Path) {
    $hash = Get-NRHash $Path
    if ($hash -ne $script:NRKnownGood) {
        throw "This DLL is not the tested 310.9.16 RTX 40 build. Hash=$hash. Expected=$script:NRKnownGood. No file was installed."
    }
    return $Path
}
function Ask-NRDllPath {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = 'Select compatible nvngx_dlssnr.dll (310.9.16 RTX 40)'
        $dlg.Filter = 'DLL files (*.dll)|*.dll|All files (*.*)|*.*'
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
    } catch { Write-Warning 'File-picker unavailable, using terminal input.' }
    return (Read-Host 'Full path to the compatible nvngx_dlssnr.dll').Trim('"')
}
function Build-NRFromGame([string]$OriginalPath) {
    if ((Get-NRHash $OriginalPath) -ne $script:NROriginal) {
        throw 'Automatic builder requires the untouched Metro NR 310.9.16 DLL. Restore this DLL with Steam verification or select a prepatched DLL.'
    }
    # OpenNR compiles the EXACT verified output, using the NVIDIA DLL already included with Metro.
    # Its CUDA/VS/CMake prerequisites are external; installer does not silently install SDKs.
    if (!(Get-Command cmake.exe -ErrorAction SilentlyContinue)) {
        throw 'CMake 3.23+ is required for the automatic OpenNR build. Install CMake or choose Bring Your Own DLL.'
    }
    $pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $vswhere = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere)) {
        throw 'Visual Studio 2022 C++ Build Tools are required for OpenNR. Choose Bring Your Own DLL if unavailable.'
    }
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$vs) { throw 'MSVC x64 tools were not found by vswhere. Install Desktop development with C++.' }
    $cudaBin = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4\bin'
    foreach ($tool in @('ptxas.exe','fatbinary.exe','cuobjdump.exe')) {
        if (!(Test-Path -LiteralPath (Join-Path $cudaBin $tool))) { throw "CUDA 13.4 tools are required ($tool missing). Install CUDA Toolkit 13.4 / 13.4.3 or choose Bring Your Own DLL." }
    }
    Write-Host 'Downloading OpenNR source from clshortfuse/openNR (no prepatched NVIDIA binary)...' -ForegroundColor Cyan
    $work = Join-Path $env:TEMP ('MetroNR-OpenNR-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
        $zip = Join-Path $work 'openNR-source.zip'
        $headers = @{'User-Agent'='Metro-NR-RTX40-Installer'}
        Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri 'https://github.com/clshortfuse/openNR/archive/refs/heads/main.zip' -OutFile $zip
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $work 'source')
        $source = Get-ChildItem -LiteralPath (Join-Path $work 'source') -Directory | Select-Object -First 1
        if (!$source -or !(Test-Path (Join-Path $source.FullName 'build.cmd'))) { throw 'Unexpected OpenNR source archive.' }
        $out = Join-Path $work 'nvngx_dlssnr.dll'
        $buildCmd = 'call "' + (Join-Path $source.FullName 'build.cmd') + '" --input "' + $OriginalPath + '" --output "' + $out + '" --cuda-bin "' + $cudaBin + '"'
        Write-Host 'Reconstructing CUDA compatibility kernels with OpenNR; this may consume significant disk space.' -ForegroundColor Cyan
        Push-Location $source.FullName
        try { & cmd.exe /d /c $buildCmd; if ($LASTEXITCODE -ne 0) { throw "OpenNR failed (exit $LASTEXITCODE). No game files were changed." } }
        finally { Pop-Location }
        Assert-WorkingNR $out | Out-Null
        # Caller owns this returned copy; original temporary files can be cleaned.
        $kept = Join-Path ([IO.Path]::GetTempPath()) ('MetroNR-verified-' + [guid]::NewGuid().ToString('N') + '.dll')
        Copy-Item -LiteralPath $out -Destination $kept
        return $kept
    }
    finally { Remove-Item -LiteralPath $work -Force -Recurse -ErrorAction SilentlyContinue }
}
function Acquire-NR([string]$GameDir,[string]$Mode,[string]$LocalPath,[string]$DownloadUrl) {
    $gameDLL = Join-Path $GameDir 'nvngx_dlssnr.dll'
    $hash = Get-NRHash $gameDLL
    if (!$Mode -or $Mode -eq 'Ask') {
        if ($hash -eq $script:NRKnownGood) {
            Write-Host 'Compatible RTX 40 NR 310.9.16 DLL already installed — keeping it.' -ForegroundColor Green
            $Mode = 'Keep'
        } else {
        Write-Host ''
        Write-Host 'Neural Rendering DLL setup (310.9.16 RTX 40):' -ForegroundColor Cyan
        Write-Host '  1) Keep existing compatible DLL (recommended if already patched)'
        Write-Host '  2) Browse for a compatible DLL'
        Write-Host '  3) Download OpenNR source and rebuild Metro original DLL (requires VS, CMake, CUDA 13.4)'
        Write-Host '  4) Download from my HTTPS DLL URL (verified SHA-256 only)'
        $choice = Read-Host 'Choose 1-4'
        $Mode = switch ($choice) { '1' {'Keep'} '2' {'Browse'} '3' {'Build'} '4' {'Url'} default {throw 'Invalid DLL source choice'} }
        }
    }
    if ($Mode -eq 'Keep') { Assert-WorkingNR $gameDLL | Out-Null; return [pscustomobject]@{File=$gameDLL; Temporary=$false; Source='Existing verified'} }
    if ($Mode -eq 'Browse') {
        if (!$LocalPath) { $LocalPath = Ask-NRDllPath }
        Assert-WorkingNR $LocalPath | Out-Null
        return [pscustomobject]@{File=(Resolve-Path -LiteralPath $LocalPath).Path; Temporary=$false; Source='User-supplied verified'}
    }
    if ($Mode -eq 'Build') {
        $made = Build-NRFromGame $gameDLL
        return [pscustomobject]@{File=$made; Temporary=$true; Source='OpenNR locally built'}
    }
    if ($Mode -eq 'Url') {
        if (!$DownloadUrl) { $DownloadUrl = Read-Host 'HTTPS download URL for the matching RTX 40 310.9.16 DLL' }
        if ($DownloadUrl -notmatch '^https://') { throw 'Only HTTPS URLs are permitted.' }
        $tmp = Join-Path $env:TEMP ('MetroNR-download-' + [guid]::NewGuid().ToString('N') + '.dll')
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $tmp -Headers @{'User-Agent'='Metro-NR-RTX40-Installer'}
            Assert-WorkingNR $tmp | Out-Null
        } catch { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; throw }
        return [pscustomobject]@{File=$tmp; Temporary=$true; Source='HTTPS SHA256 verified'}
    }
    throw "Unsupported DLL mode: $Mode"
}

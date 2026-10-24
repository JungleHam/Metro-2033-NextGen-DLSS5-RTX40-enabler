# Metro NR GPU Spoof v0.4 - Windows x64 source build.
# This script uses vcvars64.bat with NO extra architecture arguments, verifies cl.exe,
# then builds from a temporary command file to avoid cmd.exe quoting ambiguities.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = $PSScriptRoot
$output = Join-Path $root 'build'
New-Item -ItemType Directory -Force $output | Out-Null

# Prefer an already configured VS x64 Developer Command Prompt, otherwise discover VS.
$compilerAlreadyAvailable = [bool](Get-Command cl.exe -ErrorAction SilentlyContinue)
$vcvars = $null
if (-not $compilerAlreadyAvailable) {
    $pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $vswhere = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        throw @'
Microsoft C++ compiler not found, and Visual Studio Installer/vswhere is missing.
Install Visual Studio 2022 Build Tools with 'Desktop development with C++'.
Then reopen this folder and run Install.cmd again.
'@
    }
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $vs) {
        throw @'
MSVC C++ x64 tools are not installed (or VS registration is broken).
Open Visual Studio Installer > Modify > 'Desktop development with C++'.
Check 'MSVC v143 - VS 2022 C++ x64/x86 build tools' and a Windows 10/11 SDK.
Then re-run Install.cmd.
'@
    }
    $vcvars = Join-Path (($vs | Select-Object -First 1).Trim()) 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path -LiteralPath $vcvars)) { throw "Missing vcvars64.bat: $vcvars" }
    Write-Host "Using Visual Studio: $vs" -ForegroundColor Cyan
}

$vendor = Join-Path $root 'vendor\minhook'
$archive = Join-Path $env:TEMP 'metro-minhook-v1.3.3.zip'
if (-not (Test-Path -LiteralPath (Join-Path $vendor 'include\MinHook.h'))) {
    Write-Host 'Downloading MinHook v1.3.3 from TsudaKageyu/minhook...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri 'https://github.com/TsudaKageyu/minhook/archive/refs/tags/v1.3.3.zip' -OutFile $archive -UseBasicParsing
    $staging = Join-Path $env:TEMP 'metro-minhook-extract'
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    Expand-Archive -LiteralPath $archive -DestinationPath $staging
    $source = Get-ChildItem $staging -Directory | Where-Object { $_.Name -like 'minhook-*' } | Select-Object -First 1
    if (-not $source) { throw 'Unexpected MinHook archive format.' }
    New-Item -ItemType Directory -Force (Split-Path $vendor) | Out-Null
    Copy-Item -Recurse -LiteralPath $source.FullName -Destination $vendor
}

$src = Join-Path $root 'src\metro_spoof.cpp'
$def = Join-Path $root 'src\dinput8.def'
$include = Join-Path $vendor 'include'
$files = @(
    $src,
    (Join-Path $vendor 'src\buffer.c'),
    (Join-Path $vendor 'src\hook.c'),
    (Join-Path $vendor 'src\trampoline.c'),
    (Join-Path $vendor 'src\hde\hde64.c')
)
foreach ($file in $files) { if (-not (Test-Path -LiteralPath $file)) { throw "Missing source: $file" } }

# Running the environment setup and the compiler from a .cmd file preserves PATH
# changes and exposes vcvars failure messages previously swallowed by >nul.
$compileBatch = Join-Path $output '_compile_metro_nr.cmd'
$quotedSources = ($files | ForEach-Object { '"' + $_ + '"' }) -join ' '
$dll = Join-Path $output 'dinput8.dll'
$lines = @('@echo off')
if ($vcvars) {
    $lines += 'call "' + $vcvars + '"'
    $lines += 'if errorlevel 1 ( echo ERROR: vcvars64.bat failed. & exit /b 11 )'
}
$lines += 'where cl.exe >nul 2>&1'
$lines += 'if errorlevel 1 ( echo ERROR: cl.exe missing after Visual Studio setup. Install/repair Desktop development with C++ and MSVC x64 tools. & exit /b 12 )'
$lines += 'where link.exe >nul 2>&1'
$lines += 'if errorlevel 1 ( echo ERROR: link.exe missing from MSVC tools. & exit /b 13 )'
$lines += 'echo Compiler located:'
$lines += 'where cl.exe'
$lines += 'cl /nologo /O2 /MD /EHsc /W3 /LD /I"' + $include + '" ' + $quotedSources + ' /link /NOLOGO /MACHINE:X64 /OUT:"' + $dll + '" /DEF:"' + $def + '" dxguid.lib'
$lines += 'exit /b %errorlevel%'
[System.IO.File]::WriteAllLines($compileBatch, $lines, [System.Text.Encoding]::ASCII)
Write-Host 'Compiling x64 DirectInput proxy...' -ForegroundColor Cyan
Push-Location $output
try {
    & cmd.exe /d /c ('"' + $compileBatch + '"')
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "MSVC build failed: exit code $code. See the compiler/Visual Studio message above." }
} finally { Pop-Location }
if (-not (Test-Path -LiteralPath $dll)) { throw 'Compiler reported success but dinput8.dll was not produced.' }
Write-Host "Built $dll" -ForegroundColor Green
Get-FileHash $dll -Algorithm SHA256 | Format-Table -AutoSize

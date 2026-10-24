param([string]$Version = 'v1.0.0-preview3')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $root '_release'
if (!(Test-Path -LiteralPath (Join-Path $stage 'build\dinput8.dll'))) {
    throw 'Missing _release\build\dinput8.dll. Run Build.ps1 and create the release stage first.'
}
$output = Join-Path $root 'build'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$payload = Join-Path $output 'MetroNR-PortablePayload.zip'
$exe = Join-Path $output ('Metro-NR-RTX40-Portable-' + $Version + '.exe')
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $payload -CompressionLevel Optimal -Force
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $csc)) { throw 'The Windows .NET Framework x64 C# compiler was not found.' }
$argsList = @('/nologo','/target:winexe','/platform:x64','/optimize+',
    ('/out:' + $exe),('/resource:' + $payload + ',MetroNR.Payload.zip'),
    '/reference:System.Windows.Forms.dll',
    '/reference:System.IO.Compression.dll',
    '/reference:System.IO.Compression.FileSystem.dll',
    (Join-Path $PSScriptRoot 'PortableLauncher.cs'))
& $csc @argsList
if ($LASTEXITCODE -ne 0) { throw "Portable launcher build failed with code $LASTEXITCODE" }
if (!(Test-Path -LiteralPath $exe)) { throw 'Portable EXE was not created.' }
Write-Host ('Portable executable: ' + $exe) -ForegroundColor Green
(Get-FileHash -LiteralPath $exe -Algorithm SHA256) | Format-Table -AutoSize

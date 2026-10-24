# Requires authenticated GitHub CLI (`gh auth login`) and git.
# Only the explicitly listed project files are committed; logs/backups stay private.
param([string]$Repository = 'JungleHam/Metro-2033-NextGen-DLSS5-RTX40')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Install GitHub CLI (https://cli.github.com) first.' }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows first.' }
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Run gh auth login before publishing.' }
if (Test-Path '.git') { throw 'This folder is already a git repository; refusing to replace its remotes.' }
& git init -b main
if ($LASTEXITCODE -ne 0) { throw 'Git init failed.' }
$files = @('README.md','LICENSE','.gitignore','.github/workflows/build-release.yml','Build.ps1','Install.ps1','Install.cmd','Uninstall.ps1','Uninstall.cmd','EnableDirect.ps1','EnableDirect.cmd','DisableDirect.ps1','DisableDirect.cmd','Report.ps1','Report.cmd','GamePath.ps1','EnableProbe.ps1','EnableProbe.cmd','DisableProbe.ps1','DisableProbe.cmd','src/metro_spoof.cpp','src/dinput8.def')
& git add -- $files
if ($LASTEXITCODE -ne 0) { throw 'Git add failed.' }
& git -c user.name='JungleHam' -c user.email='86321242+JungleHam@users.noreply.github.com' commit -m 'Initial public RTX 40 NR bridge source'
if ($LASTEXITCODE -ne 0) { throw 'Commit failed.' }
& gh repo create $Repository --public --source . --remote origin --push --description 'Experimental native DLSS 5 Neural Rendering bridge for Metro 2033 Next-Gen on RTX 40 GPUs'
if ($LASTEXITCODE -ne 0) { throw 'Repository publishing failed. Run gh repo view to inspect state.' }
Write-Host "Published https://github.com/$Repository" -ForegroundColor Green

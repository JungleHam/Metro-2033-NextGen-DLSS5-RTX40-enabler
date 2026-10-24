# Stores only a local path next to these scripts; never bundled or uploaded.
function Resolve-MetroGameDir {
    param([string]$Candidate = '', [switch]$AllowPrompt, [ValidateSet('2033','LastLight')][string]$Game = '2033')
    $folderName = if ($Game -eq 'LastLight') { 'Metro Last Light Redux' } else { 'Metro 2033 Redux' }
    # Portable builds extract to a temporary folder. Remember both game locations permanently.
    $settingsDir = Join-Path $env:LOCALAPPDATA 'Metro-NR-RTX40\Preferences'
    $pathFile = Join-Path $settingsDir $(if($Game -eq 'LastLight'){'.metro-lastlight-game-path'}else{'.metro-2033-game-path'})
    $legacyPath = Join-Path $PSScriptRoot $(if($Game -eq 'LastLight'){'.metro-lastlight-game-path'}else{'.metro-2033-game-path'})
    if (-not $Candidate -and -not (Test-Path -LiteralPath $pathFile) -and (Test-Path -LiteralPath $legacyPath)) {
        $Candidate = (Get-Content -LiteralPath $legacyPath -Raw).Trim()
    }
    if (-not $Candidate -and (Test-Path -LiteralPath $pathFile)) {
        $Candidate = (Get-Content -LiteralPath $pathFile -Raw).Trim()
    }
    if (-not $Candidate) {
        $likely = @()
        if (${env:ProgramFiles(x86)}) {
            $likely += (Join-Path ${env:ProgramFiles(x86)} ('Steam\steamapps\common\' + $folderName))
        }
        if ($env:ProgramFiles) {
            $likely += (Join-Path $env:ProgramFiles ('Steam\steamapps\common\' + $folderName))
        }
        foreach ($guess in $likely) {
            if ($guess -and (Test-Path -LiteralPath (Join-Path $guess 'metro.exe'))) {
                $Candidate = $guess; break
            }
        }
    }
    # Locate non-default Steam libraries, including other drives.
    if (-not $Candidate) {
        $steamRoots = @()
        $reg = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
        if ($reg -and $reg.SteamPath) { $steamRoots += [string]$reg.SteamPath }
        foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            foreach ($prefix in @('Steam','Games\Steam','SteamLibrary')) {
                $candidateSteam = Join-Path $drive.Root $prefix
                if (Test-Path -LiteralPath (Join-Path $candidateSteam 'steamapps')) { $steamRoots += $candidateSteam }
            }
        }
        foreach ($steam in @($steamRoots | Select-Object -Unique)) {
            $libraries = @($steam)
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $vdf) {
                foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                    $libraries += ($m.Groups[1].Value -replace '\\','\')
                }
            }
            foreach ($lib in $libraries) {
                $game = Join-Path $lib ('steamapps\common\' + $folderName)
                if (Test-Path -LiteralPath (Join-Path $game 'metro.exe')) { $Candidate = $game; break }
            }
            if ($Candidate) { break }
        }
    }
    if (-not $Candidate -and $AllowPrompt) {
        Write-Host ('Could not auto-detect ' + $folderName + '. Browse to the folder containing metro.exe.') -ForegroundColor Yellow
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description = ('Select ' + $folderName + ' game folder (metro.exe)')
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $Candidate = $dlg.SelectedPath }
        } catch { Write-Warning 'Folder picker unavailable.' }
        if (-not $Candidate) { $Candidate = Read-Host ('Metro ' + $folderName + ' game folder') }
    }
    $Candidate = [string]$Candidate
    $Candidate = $Candidate.Trim().Trim('"')
    if (-not $Candidate -or -not (Test-Path -LiteralPath (Join-Path $Candidate 'metro.exe'))) {
        throw "Can't find metro.exe in '$Candidate'. Run Install.cmd first or use -GameDir 'C:\path\to\Metro 2033 Redux'."
    }
    $baseName = Split-Path -Path $Candidate -Leaf
    if ($Game -eq 'LastLight' -and $baseName -match '(?i)metro\s*2033') { throw 'You selected the 2033 folder while Last Light is selected.' }
    if ($Game -eq '2033' -and $baseName -match '(?i)last\s*light') { throw 'You selected the Last Light folder while 2033 is selected.' }
    return (Resolve-Path -LiteralPath $Candidate).Path
}

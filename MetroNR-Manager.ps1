# Windows graphical installer, with no visible terminal. Background work is
# delegated to MetroNR-Worker.ps1 and progress is read from its log file.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Metro Redux Next-Gen - Neural Rendering Setup'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(740, 645)
$form.MinimumSize = New-Object System.Drawing.Size(740, 645)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

function Label([string]$text,[int]$x,[int]$y,[int]$w,[int]$h=25) {
    $c = New-Object System.Windows.Forms.Label
    $c.Text=$text; $c.Location=New-Object System.Drawing.Point($x,$y)
    $c.Size=New-Object System.Drawing.Size($w,$h)
    $form.Controls.Add($c)
    return $c
}
function Button([string]$text,[int]$x,[int]$y,[int]$w,[int]$h=30) {
    $c = New-Object System.Windows.Forms.Button
    $c.Text=$text; $c.Location=New-Object System.Drawing.Point($x,$y)
    $c.Size=New-Object System.Drawing.Size($w,$h)
    $form.Controls.Add($c)
    return $c
}
function TextBox([int]$x,[int]$y,[int]$w) {
    $c = New-Object System.Windows.Forms.TextBox
    $c.Location=New-Object System.Drawing.Point($x,$y)
    $c.Size=New-Object System.Drawing.Size($w,26)
    $form.Controls.Add($c)
    return $c
}

$heading = Label 'Neural Rendering for RTX 40 graphics cards' 22 17 690 30
$heading.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
$hint = Label 'Choose Install or Uninstall. No command window will appear.' 22 52 680 24
$hint.ForeColor = [System.Drawing.Color]::DimGray

$installChoice = New-Object System.Windows.Forms.RadioButton
$installChoice.Text='Install / update'; $installChoice.Location=New-Object System.Drawing.Point(25,87)
$installChoice.Size=New-Object System.Drawing.Size(140,23); $installChoice.Checked=$true
$form.Controls.Add($installChoice)
$removeChoice = New-Object System.Windows.Forms.RadioButton
$removeChoice.Text='Uninstall mod'; $removeChoice.Location=New-Object System.Drawing.Point(180,87)
$removeChoice.Size=New-Object System.Drawing.Size(150,23)
$form.Controls.Add($removeChoice)

# Keep the label completely outside the dropdown. The previous 150 px
# label covered the leftmost 22 px of a dropdown also starting at x=150.
$null = Label 'Game' 22 114 100
$gameChoice = New-Object System.Windows.Forms.ComboBox
$gameChoice.DropDownStyle='DropDownList'
$gameChoice.Location=New-Object System.Drawing.Point(150,114)
$gameChoice.Size=New-Object System.Drawing.Size(567,26)
[void]$gameChoice.Items.Add('Metro 2033 Redux')
[void]$gameChoice.Items.Add('Metro Last Light Redux')
$gameChoice.SelectedIndex=0
$form.Controls.Add($gameChoice)
$null = Label 'Game folder' 22 141 600
$gamePath = TextBox 22 166 595
$browseGame = Button 'Browse...' 630 164 88

$nrLabel = Label 'DLSS Neural Rendering file (310.9.16)' 22 207 640
$nrSource = New-Object System.Windows.Forms.ComboBox
$nrSource.DropDownStyle = 'DropDownList'
$nrSource.Location = New-Object System.Drawing.Point(22,235)
$nrSource.Size = New-Object System.Drawing.Size(695,27)
[void]$nrSource.Items.Add('Use compatible DLL already in Metro folder (recommended if installed)')
[void]$nrSource.Items.Add('Browse for a compatible DLL on my PC')
[void]$nrSource.Items.Add('Build from my original game DLL (advanced: needs developer tools)')
[void]$nrSource.Items.Add('Download from an HTTPS link I provide (verified file only)')
$nrSource.SelectedIndex = 0
$form.Controls.Add($nrSource)
$extraLabel = Label 'DLL file or HTTPS link' 22 264 690 24
$extra = TextBox 22 289 595
$browseNR = Button 'Browse...' 630 287 88
$note = Label 'Advanced Configurator is optional. The game''s normal NR switch works without it.' 22 325 680 25
$note.ForeColor = [System.Drawing.Color]::DimGray

$start = Button 'Install mod' 22 358 190 38
$start.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$showLog = Button 'Open saved log' 228 362 137 30
$showLog.Enabled=$false
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(22,407)
$progress.Size = New-Object System.Drawing.Size(695,16)
$progress.Style = 'Blocks'
$form.Controls.Add($progress)
$status = Label 'Ready.' 22 432 695 28
$status.AutoEllipsis = $true
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(22,466)
$logBox.Size = New-Object System.Drawing.Size(695,155)
$logBox.Multiline=$true; $logBox.ScrollBars='Vertical'; $logBox.ReadOnly=$true
$logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($logBox)

$script:running = $false
$script:proc = $null
$script:logPath = ''
$script:previousLength = 0
$script:finished = $false
$script:operation = 'Install'

function Update-Choices {
    $installing = $installChoice.Checked
    $nrLabel.Visible=$installing; $nrSource.Visible=$installing
    $extraLabel.Visible=$installing; $extra.Visible=$installing; $browseNR.Visible=$installing
    $note.Visible=$installing
    $start.Text= $(if($installing){'Install mod'}else{'Uninstall mod'})
    $needsExtra = $installing -and ($nrSource.SelectedIndex -eq 1 -or $nrSource.SelectedIndex -eq 3)
    $extraLabel.Visible=$needsExtra; $extra.Visible=$needsExtra
    $browseNR.Visible=$installing -and $nrSource.SelectedIndex -eq 1
    if ($installing -and $nrSource.SelectedIndex -eq 3) { $extraLabel.Text='Direct HTTPS link to compatible DLL' }
    else { $extraLabel.Text='Select compatible nvngx_dlssnr.dll' }
}
$installChoice.Add_CheckedChanged({ Update-Choices })
$removeChoice.Add_CheckedChanged({ Update-Choices })
$nrSource.Add_SelectedIndexChanged({ $extra.Text=''; Update-Choices })
$browseGame.Add_Click({
    $dlg=New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description='Select the folder containing metro.exe'
    if ($gamePath.Text -and (Test-Path -LiteralPath $gamePath.Text -PathType Container)) { $dlg.SelectedPath=$gamePath.Text }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $gamePath.Text=$dlg.SelectedPath }
})
$browseNR.Add_Click({
    $dlg=New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter='DLL files (*.dll)|*.dll|All files (*.*)|*.*'
    $dlg.Title='Select RTX 40-compatible nvngx_dlssnr.dll (310.9.16)'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $extra.Text=$dlg.FileName }
})

# Find the selected title separately, including non-default Steam libraries.
. (Join-Path $PSScriptRoot 'GamePath.ps1')
function Find-SelectedGame {
    $choice = if ($gameChoice.SelectedIndex -eq 1) { 'LastLight' } else { '2033' }
    try { $gamePath.Text = Resolve-MetroGameDir -Candidate '' -Game $choice }
    catch { $gamePath.Text = '' }
}
$gameChoice.Add_SelectedIndexChanged({ Find-SelectedGame })
Find-SelectedGame
Update-Choices

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300
$timer.Add_Tick({
    if (-not $script:running) { return }
    if (Test-Path -LiteralPath $script:logPath -PathType Leaf) {
        try {
            $fs = New-Object System.IO.FileStream($script:logPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $reader = New-Object System.IO.StreamReader($fs)
                $all = $reader.ReadToEnd()
                $reader.Dispose()
            } finally { $fs.Dispose() }
            if ($all.Length -gt $script:previousLength) {
                $new = $all.Substring($script:previousLength)
                $script:previousLength = $all.Length
                $logBox.AppendText($new)
                foreach ($line in ($new -split '\r?\n')) {
                    if ($line.StartsWith('[STEP] ')) { $status.Text = $line.Substring(7) }
                    elseif ($line.StartsWith('[ERROR] ')) { $status.Text='Installation problem - see log below' }
                }
            }
        } catch { } # Writer may have the file open for a fraction of a second.
    }
    if ($script:proc -and $script:proc.HasExited -and -not $script:finished) {
        $script:finished=$true
        $code=$script:proc.ExitCode
        $timer.Stop()
        $progress.Style='Blocks'; $progress.Value=$(if($code -eq 0){100}else{0})
        $start.Enabled=$true; $browseGame.Enabled=$true; $browseNR.Enabled=$true
        $installChoice.Enabled=$true; $removeChoice.Enabled=$true; $nrSource.Enabled=$true
        $extra.Enabled=$true; $gamePath.Enabled=$true; $gameChoice.Enabled=$true
        $script:running=$false
        if ($code -eq 0) {
            $status.Text = $(if($script:operation -eq 'Install'){'Installed successfully. Launch the selected Metro game and enable Neural Rendering.'}else{'Mod uninstalled successfully. Your game files were preserved.'})
            [System.Windows.Forms.MessageBox]::Show($status.Text,'Metro NR Setup','OK','Information') | Out-Null
        } else {
            $status.Text='Operation failed. Please review the log for details.'
            [System.Windows.Forms.MessageBox]::Show('Something went wrong. The installer saved a detailed log. Click Open saved log to review it.','Metro NR Setup','OK','Error') | Out-Null
        }
        $script:proc.Dispose(); $script:proc=$null
    }
})

$start.Add_Click({
    $game=$gamePath.Text.Trim()
    if (-not $game -or -not (Test-Path -LiteralPath (Join-Path $game 'metro.exe') -PathType Leaf)) {
        [System.Windows.Forms.MessageBox]::Show('Please select the folder containing metro.exe for the chosen game.','Metro NR Setup','OK','Warning') | Out-Null
        return
    }
    $chosenGame=if($gameChoice.SelectedIndex -eq 1){'LastLight'}else{'2033'}
    try { $game = Resolve-MetroGameDir -Candidate $game -Game $chosenGame }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Wrong game folder','OK','Warning') | Out-Null
        return
    }
    $action=$(if($installChoice.Checked){'Install'}else{'Uninstall'})
    if ($action -eq 'Uninstall') {
        if ([System.Windows.Forms.MessageBox]::Show('Uninstall the Metro NR mod? Your game and other mods will be left alone.','Confirm uninstall','YesNo','Question') -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }
    $mode=@('Keep','Browse','Build','Url')[$nrSource.SelectedIndex]
    if ($action -eq 'Install' -and (($mode -eq 'Browse' -and -not (Test-Path -LiteralPath $extra.Text -PathType Leaf)) -or ($mode -eq 'Url' -and $extra.Text -notmatch '^https://'))) {
        [System.Windows.Forms.MessageBox]::Show('Please supply a valid DLL file or an HTTPS download link.','Metro NR Setup','OK','Warning') | Out-Null
        return
    }
    $dir = Join-Path $env:LOCALAPPDATA 'Metro-NR-RTX40\Logs'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:logPath = Join-Path $dir (('setup-{0}-{1}.log' -f $action.ToLowerInvariant(),(Get-Date -Format 'yyyyMMdd-HHmmss-fff')))
    $script:previousLength=0; $script:finished=$false; $script:operation=$action
    $logBox.Clear(); $status.Text='Starting ' + $action.ToLowerInvariant() + '...'
    $showLog.Enabled=$true
    $args=@('-NoLogo','-NoProfile','-STA','-NonInteractive','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',(Join-Path $PSScriptRoot 'MetroNR-Worker.ps1'),'-Action',$action,'-Game',$chosenGame,'-GameDir',$game,'-LogPath',$script:logPath)
    if($action -eq 'Install') {
        $args += @('-NrMode',$mode)
        if($mode -eq 'Browse') { $args += @('-NrDllPath',$extra.Text) }
        if($mode -eq 'Url') { $args += @('-NrDownloadUrl',$extra.Text) }
    }
    # Quote CreateProcess arguments directly. Do not use cmd.exe.
    $quoted=@($args | ForEach-Object { if($_ -match '[\s"]') { '"' + ($_.Replace('"','\"')) + '"' }else{ $_ } })
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $info.Arguments = $quoted -join ' '
    $info.WorkingDirectory = $PSScriptRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    try {
        $script:proc = [System.Diagnostics.Process]::Start($info)
        if (-not $script:proc) { throw 'Could not start the installer worker.' }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Unable to launch installer','OK','Error') | Out-Null
        return
    }
    $script:running=$true
    $progress.Style='Marquee'; $progress.MarqueeAnimationSpeed=30
    $start.Enabled=$false; $browseGame.Enabled=$false; $browseNR.Enabled=$false
    $installChoice.Enabled=$false; $removeChoice.Enabled=$false; $nrSource.Enabled=$false
    $extra.Enabled=$false; $gamePath.Enabled=$false; $gameChoice.Enabled=$false
    $timer.Start()
})
$showLog.Add_Click({ if($script:logPath -and (Test-Path -LiteralPath $script:logPath)){ Start-Process -FilePath 'notepad.exe' -ArgumentList ('"'+$script:logPath+'"') } })
$form.Add_FormClosing({
    param($sender,$e)
    if ($script:running) {
        $e.Cancel=$true
        [System.Windows.Forms.MessageBox]::Show('Please let the current operation finish before closing this window.','Metro NR Setup','OK','Information') | Out-Null
    }
})
[void]$form.ShowDialog()
$form.Dispose()
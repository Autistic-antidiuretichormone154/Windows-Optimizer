<#
.SYNOPSIS
    WinOptimizer v2.1 - by NishantJLU
.DESCRIPTION
    A comprehensive Windows 10/11 optimization and setup utility.
#>

param(
    [switch]$DryRun,
    [switch]$Restore,
    [switch]$Silent,
    [int]$RunModule = 0
)

$Version = "2.1.0"

# 1. Admin check & Relaunch
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Restarting as Administrator..."
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    if ($DryRun) { $arguments += " -DryRun" }
    if ($Restore) { $arguments += " -Restore" }
    if ($Silent) { $arguments += " -Silent" }
    if ($RunModule -gt 0) { $arguments += " -RunModule $RunModule" }
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

# 2. Directory setup & Config Loading
$BaseDir = "C:\WinOptimizer"
$LogDir = "$BaseDir\logs"
$BackupDir = "$BaseDir\backups"
$ConfigPath = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $BackupDir)) { New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null }

if (Test-Path $ConfigPath) {
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
} else {
    Write-Error "config.json not found! Please ensure it's in the same directory."
    exit
}

$LogFile = "$LogDir\$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
$global:GamingModeState = "OFF"
$global:ActiveProfile = "None"

# 3. Helpers
function Write-Log {
    param([string]$Module, [string]$Action, [string]$Status)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $OSBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
    if (-not $OSBuild) { $OSBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion }
    $LogEntry = "[$Timestamp] [v$Version] [OS:$OSBuild] [$Module] [$Action] [$Status]"
    Add-Content -Path $LogFile -Value $LogEntry
}

function Write-OutputColor {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host $Message -ForegroundColor $Color
}

function Ask-Confirm {
    param([string]$Message)
    if ($Silent) { return $true }
    $answer = Read-Host "$Message [Y/N]"
    return ($answer -match "^[yY]")
}

function Create-RestorePoint {
    if ($DryRun) { Write-OutputColor "DRY RUN: Skip Restore Point creation." "Yellow"; return }
    Write-OutputColor "Creating System Restore Point..." "Cyan"
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Before WinOptimizer v$Version" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-OutputColor "Restore point created successfully." "Green"
        Write-Log "Safety" "CreateRestorePoint" "SUCCESS"
    } catch {
        Write-Warning "Could not create restore point: $_"
        Write-Log "Safety" "CreateRestorePoint" "FAILED: $_"
        if (-not (Ask-Confirm "Continue without restore point?")) { exit }
    }
}

function Backup-RegistryKey {
    param([string]$KeyPath)
    $RegPath = $KeyPath -replace 'HKCU:\\', 'HKEY_CURRENT_USER\' -replace 'HKLM:\\', 'HKEY_LOCAL_MACHINE\' -replace 'HKCR:\\', 'HKEY_CLASSES_ROOT\'
    $SafeName = $RegPath -replace '\\', '_' -replace ':', ''
    $ExportPath = "$BackupDir\$SafeName.reg"
    if (Test-Path $KeyPath) {
        if (-not $DryRun) {
            reg export $RegPath $ExportPath /y 2>$null
        }
        Write-Log "Backup" "Export $RegPath" "SUCCESS"
    }
}

function Set-RegistryValueSafe {
    param([string]$Path, [string]$Name, [string]$Value, [string]$PropertyType)
    Backup-RegistryKey $Path
    if ($DryRun) {
        Write-OutputColor "DRY RUN: Set registry $Path\$Name to $Value" "Cyan"
        Write-Log "Registry" "Set $Path\$Name = $Value" "DRY_RUN"
    } else {
        try {
            if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -ErrorAction Stop
            Write-Log "Registry" "Set $Path\$Name = $Value" "SUCCESS"
        } catch {
            Write-Log "Registry" "Set $Path\$Name = $Value" "ERROR: $_"
        }
    }
}

function Restore-Backups {
    $files = Get-ChildItem -Path $BackupDir -Filter *.reg
    if ($files.Count -eq 0) { Write-OutputColor "No backups found." "Yellow"; return }
    foreach ($file in $files) {
        Write-OutputColor "Restoring $($file.Name)..." "Cyan"
        if (-not $DryRun) {
            reg import $file.FullName
        }
    }
    Write-OutputColor "Restore complete." "Green"
}

# --- Module 1: Bloatware Nuke ---
function Invoke-BloatwareNuke {
    Write-OutputColor "`n--- MODULE 1: Bloatware Nuke ---" "Cyan"
    if (-not (Ask-Confirm "Remove bloatware?")) { return }
    
    $packages = if ($global:ActiveProfile -ne "None") {
        $Config.Profiles.$($global:ActiveProfile).Bloatware
    } else {
        # Fallback to a default list if no profile selected
        @("Microsoft.XboxApp", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay", "Microsoft.ZuneMusic", "Microsoft.ZuneVideo")
    }

    $count = 0
    $total = $packages.Count
    for ($i=0; $i -lt $total; $i++) {
        $pkg = $packages[$i]
        Write-Progress -Activity "Removing Bloatware" -Status "Processing $pkg" -PercentComplete (($i / $total) * 100)
        $found = Get-AppxPackage -Name "*$pkg*" -AllUsers 2>$null
        if ($found) {
            if ($DryRun) {
                Write-Log "Bloatware" "Remove $pkg" "DRY_RUN"
            } else {
                try {
                    $found | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    $count++
                    Write-Log "Bloatware" "Remove $pkg" "SUCCESS"
                } catch {
                    Write-Log "Bloatware" "Remove $pkg" "ERROR: $_"
                }
            }
        }
    }
    Write-Progress -Activity "Removing Bloatware" -Completed
    if (Ask-Confirm "Remove OneDrive?") {
        if (-not $DryRun) {
            Stop-Process -Name "OneDrive" -ErrorAction SilentlyContinue
            $odPath = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
            if (Test-Path $odPath) { & $odPath /uninstall }
            Write-Log "Bloatware" "Remove OneDrive" "SUCCESS"
        }
    }
    Set-RegistryValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0 "DWord"
    Write-OutputColor "Removed $count packages." "Green"
}

# --- Module 2: Privacy Hardener ---
function Invoke-PrivacyHardener {
    Write-OutputColor "`n--- MODULE 2: Privacy Hardener ---" "Cyan"
    if (-not (Ask-Confirm "Apply privacy tweaks?")) { return }
    foreach ($t in $Config.PrivacyTweaks) {
        Set-RegistryValueSafe $t.P $t.N $t.V $t.T
        Write-OutputColor "[v] $($t.D)" "Green"
    }
    foreach ($srv in $Config.ServicesToDisable) {
        if (Get-Service $srv -ErrorAction SilentlyContinue) {
            if (-not $DryRun) {
                Stop-Service $srv -Force -ErrorAction SilentlyContinue
                Set-Service $srv -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log "Privacy" "Disable service $srv" "SUCCESS"
            }
        }
    }
}

# --- Module 3: Dev Machine Setup ---
function Invoke-DevMachineSetup {
    Write-OutputColor "`n--- MODULE 3: Dev Machine Setup ---" "Cyan"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-OutputColor "winget not found." "Red"; return
    }
    
    $apps = if ($global:ActiveProfile -ne "None") {
        $Config.Profiles.$($global:ActiveProfile).DevApps
    } else {
        @()
    }

    if ($apps.Count -eq 0) {
        Write-OutputColor "No apps defined for current profile ($global:ActiveProfile)." "Yellow"
        return
    }

    if (-not (Test-Path "C:\DevSetup")) { New-Item "C:\DevSetup" -ItemType Directory | Out-Null }
    $sum = "C:\DevSetup\setup-summary.txt"
    "Dev Setup $(Get-Date)" | Out-File $sum
    
    function Install-App {
        param($Id, $Name)
        if (winget list --id $Id --exact -ErrorAction SilentlyContinue) {
            Write-OutputColor "[v] ${Name} installed." "Green"
        } else {
            if (-not $DryRun) {
                Write-Host "Installing ${Name}..."
                winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
                "${Name}: OK" | Out-File -Append $sum
            }
        }
    }
    
    foreach ($app in $apps) {
        Install-App $app.Id $app.Name
    }
}

# --- Module 4: Startup Speed Booster ---
function Invoke-StartupSpeedBooster {
    Write-OutputColor "`n--- MODULE 4: Startup Speed Booster ---" "Cyan"
    $runKeys = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run")
    $items = @()
    foreach ($rk in $runKeys) {
        if (Test-Path $rk) {
            $p = Get-ItemProperty $rk
            foreach ($prop in $p.psobject.properties) {
                if ($prop.Name -notmatch "^PS" -and $prop.Name -ne "Path") {
                    $items += [PSCustomObject]@{ K = $rk; N = $prop.Name }
                }
            }
        }
    }
    if ($items.Count -gt 0) {
        for ($i=0; $i -lt $items.Count; $i++) { Write-Host "[$i] $($items[$i].N)" }
        $sel = Read-Host "Enter index to disable (blank to skip)"
        if ($sel -ne "") {
            $idx = [int]$sel
            if (-not $DryRun) { Remove-ItemProperty -Path $items[$idx].K -Name $items[$idx].N -ErrorAction SilentlyContinue }
        }
    }
    foreach ($t in $Config.ScheduledTasksToDisable) {
        $found = Get-ScheduledTask -TaskName ($t | Split-Path -Leaf) -ErrorAction SilentlyContinue
        if ($found -and -not $DryRun) { Disable-ScheduledTask -InputObject $found | Out-Null }
    }
}

# --- Module 5: Junk Cleaner ---
function Invoke-JunkCleaner {
    Write-OutputColor "`n--- MODULE 5: Junk Cleaner ---" "Cyan"
    function Clean-Dir {
        param($P)
        if (Test-Path $P) {
            if (-not $DryRun) { Remove-Item "$P\*" -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    Clean-Dir $env:TEMP
    Clean-Dir "C:\Windows\Temp"
    if (Ask-Confirm "Run cleanmgr?") {
        if (-not $DryRun) { Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:65" -Wait -WindowStyle Hidden }
    }
    if (Ask-Confirm "Run Dism Cleanup?") {
        if (-not $DryRun) { Start-Process "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait }
    }
}

# --- Module 6: Gaming Mode ---
function Invoke-GamingModeToggle {
    Write-OutputColor "`n--- MODULE 6: Gaming Mode Toggle ---" "Cyan"
    $HighPerfGUID = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $BalancedGUID = "381b4222-f694-41f0-9685-ff5bb260df2e"

    function Validate-PowerPlan {
        param($Guid)
        $exists = powercfg /l | Select-String $Guid
        if (-not $exists) {
            Write-Warning "Power Plan $Guid missing. Restoring defaults..."
            powercfg /restoredefaultschemes
        }
    }

    if ($global:GamingModeState -eq "OFF") {
        if ($DryRun) { $global:GamingModeState = "ON"; return }
        Validate-PowerPlan $HighPerfGUID
        powercfg /setactive $HighPerfGUID
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        $global:GamingModeState = "ON"
        Write-OutputColor "Gaming Mode ON (High Performance & Defender Paused)" "Green"
    } else {
        if ($DryRun) { $global:GamingModeState = "OFF"; return }
        Validate-PowerPlan $BalancedGUID
        powercfg /setactive $BalancedGUID
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        $global:GamingModeState = "OFF"
        Write-OutputColor "Gaming Mode OFF (Balanced & Defender Resumed)" "Green"
    }
}

# --- Module 7: Network Reset ---
function Invoke-NetworkReset {
    Write-OutputColor "`n--- MODULE 7: Network Reset ---" "Cyan"
    if ($DryRun) { return }
    ipconfig /flushdns | Out-Null
    netsh winsock reset | Out-Null
    netsh int ip reset | Out-Null
    Write-OutputColor "Network reset. Restart recommended." "Green"
}

# --- Module 8: Safe Uninstall ---
function Invoke-SafeUninstall {
    Write-OutputColor "\n--- MODULE 8: Safe Uninstall ---" "Cyan"
    $name = Read-Host "Enter program name to search (or press Enter to list ALL)"
    
    $searchPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    Write-OutputColor "Scanning registry for installed applications..." "Gray"
    $apps = @()
    foreach ($path in $searchPaths) {
        $apps += Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -and $_.UninstallString } |
                 Select-Object DisplayName, UninstallString, InstallLocation, DisplayVersion
    }

    # Filter by name if provided, otherwise show all
    if ($name -ne "") {
        $apps = $apps | Where-Object { $_.DisplayName -match $name }
    }

    # Remove duplicates and sort
    $apps = $apps | Sort-Object DisplayName -Unique

    if ($apps.Count -eq 0) { 
        Write-OutputColor "No matching apps found." "Yellow"
        return 
    }

    # Paginated or Scrollable List
    Write-OutputColor "Found $($apps.Count) applications:" "Green"
    for ($i=0; $i -lt $apps.Count; $i++) { 
        $ver = if ($apps[$i].DisplayVersion) { "[$($apps[$i].DisplayVersion)]" } else { "" }
        Write-Host ("[{0,3}] {1} {2}" -f $i, $apps[$i].DisplayName, $ver)
    }

    $sel = Read-Host "`nSelect index to uninstall (blank to cancel)"
    if ($sel -match "^\d+$" -and [int]$sel -lt $apps.Count) {
        $app = $apps[[int]$sel]
        Write-OutputColor "Preparing to uninstall: $($app.DisplayName)" "Yellow"
        if (Ask-Confirm "Are you sure you want to proceed?") {
            if (-not $DryRun) { 
                Write-OutputColor "Launching uninstaller..." "Cyan"
                if ($app.UninstallString -match '^".*"') {
                    $cmd = $app.UninstallString
                    cmd.exe /c $cmd
                } else {
                    $cmd = $app.UninstallString
                    cmd.exe /c $cmd
                }
                Write-Log "Uninstall" "Uninstall $($app.DisplayName)" "EXECUTED"
            } else {
                Write-OutputColor "DRY RUN: Would execute $($app.UninstallString)" "Gray"
            }
        }
    }
}

# --- Module 9: Focus Mode ---
function Invoke-FocusMode {
    Write-OutputColor "`n--- MODULE 9: Focus Mode ---" "Cyan"
    $h = "C:\Windows\System32\drivers\etc\hosts"
    $c = Get-Content $h -Raw
    if ($c -match "FocusMode-START") {
        if (Ask-Confirm "Disable Focus Mode?") {
            $new = $c -replace "(?s)# FocusMode-START.*?# FocusMode-END\r?\n?", ""
            Set-Content $h $new; ipconfig /flushdns | Out-Null
            Unregister-ScheduledTask -TaskName "DisableFocusMode" -Confirm:$false -ErrorAction SilentlyContinue
            Write-OutputColor "Focus Mode disabled." "Green"
        }
    } else {
        $hrs = Read-Host "Hours (default 1)"
        if ($hrs -eq "") { $hrs = 1 }
        $block = "`n# FocusMode-START`n127.0.0.1 youtube.com`n127.0.0.1 reddit.com`n127.0.0.1 facebook.com`n127.0.0.1 twitter.com`n127.0.0.1 instagram.com`n# FocusMode-END`n"
        Add-Content $h $block; ipconfig /flushdns | Out-Null
        
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command `"`$c = Get-Content '$h' -Raw; `$new = `$c -replace '(?s)# FocusMode-START.*?# FocusMode-END\r?\n?', ''; Set-Content '$h' `$new; ipconfig /flushdns`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours([double]$hrs)
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "DisableFocusMode" -User "SYSTEM" -Force | Out-Null
        
        Write-OutputColor "Focus Mode enabled for $hrs hours. Will auto-disable via Scheduled Task." "Green"
    }
}

# --- Module 10: Visual Performance Tweaks ---
function Invoke-VisualTweaks {
    Write-OutputColor "`n--- MODULE 10: Visual Performance Tweaks ---" "Cyan"
    if (-not (Ask-Confirm "Optimize Visuals for Performance?")) { return }
    foreach ($t in $Config.VisualTweaks) {
        Set-RegistryValueSafe $t.P $t.N $t.V $t.T
        Write-OutputColor "[v] $($t.D)" "Green"
    }
    Write-OutputColor "Visual tweaks applied. Restart Explorer to see changes." "Yellow"
}

# --- Module 11: Browser Maintenance ---
function Invoke-BrowserMaintenance {
    Write-OutputColor "`n--- MODULE 11: Browser Maintenance ---" "Cyan"
    $browsers = @(
        @{ Name = "Edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" },
        @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" },
        @{ Name = "Firefox"; Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2" }
    )
    foreach ($b in $browsers) {
        $p = Resolve-Path $b.Path -ErrorAction SilentlyContinue
        if ($p) {
            Write-OutputColor "Cleaning $($b.Name) cache..." "Cyan"
            if (-not $DryRun) { Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

# --- Module 12: System Integrity Check ---
function Invoke-SystemIntegrity {
    Write-OutputColor "`n--- MODULE 12: System Integrity Check ---" "Cyan"
    if (-not $DryRun) {
        Write-OutputColor "Running SFC Scannow..." "Cyan"
        sfc /scannow
        Write-OutputColor "Running DISM Health Check..." "Cyan"
        Dism /Online /Cleanup-Image /CheckHealth
        Dism /Online /Cleanup-Image /ScanHealth
    }
}

# --- Module 13: Update System Apps ---
function Invoke-UpdateSystem {
    Write-OutputColor "`n--- MODULE 13: Update System & Apps ---" "Cyan"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return }
    Write-OutputColor "Checking for updates via winget..." "Cyan"
    if (-not $DryRun) { winget upgrade --all --accept-package-agreements --accept-source-agreements }
}

# --- Module 14: Context Menu Cleanup ---
function Invoke-ContextMenuCleanup {
    Write-OutputColor "`n--- MODULE 14: Context Menu Cleanup ---" "Cyan"
    foreach ($item in $Config.ContextMenuCleanup) {
        if (Test-Path $item.P) {
            Write-OutputColor "[x] $($item.D)" "Yellow"
            if (-not $DryRun) { Remove-Item $item.P -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

# --- Module 15: Restore Center ---
function Invoke-RestoreCenter {
    Write-OutputColor "`n--- MODULE 15: Restore Center ---" "Cyan"
    $menu = @"
[1] Restore Registry from Backup (.reg files)
[2] Open System Restore (rstrui.exe)
[3] Open Windows Recovery Settings
[B] Back to Main Menu
"@
    Write-Host $menu -ForegroundColor Yellow
    $sel = Read-Host "Select option"
    switch ($sel) {
        "1" {
            $files = Get-ChildItem -Path $BackupDir -Filter *.reg
            if ($files.Count -eq 0) { Write-OutputColor "No backups found." "Red"; return }
            for ($i=0; $i -lt $files.Count; $i++) { Write-Host "[$i] $($files[$i].Name)" }
            $fsel = Read-Host "Select file index to restore"
            if ($fsel -ne "" -and [int]$fsel -lt $files.Count) {
                $file = $files[[int]$fsel]
                Write-OutputColor "Restoring $($file.Name)..." "Cyan"
                if (-not $DryRun) { reg import $file.FullName }
            }
        }
        "2" {
            Write-OutputColor "Launching System Restore UI..." "Cyan"
            Start-Process "rstrui.exe"
        }
        "3" {
            Write-OutputColor "Opening Recovery Settings..." "Cyan"
            Start-Process "ms-settings:recovery"
        }
        "B" { return }
    }
}

# --- Profile Selector ---
function Invoke-ProfileSelector {
    Write-OutputColor "`n--- Select User Profile ---" "Cyan"
    $profiles = $Config.Profiles.psobject.properties
    $i = 1
    $plist = @()
    foreach ($p in $profiles) {
        Write-Host "[$i] $($p.Name) - $($p.Value.Description)"
        $plist += $p.Name
        $i++
    }
    Write-Host "[N] None / Manual Only"
    $sel = Read-Host "`nPick a profile"
    if ($sel -match "^\d+$" -and [int]$sel -le $plist.Count) {
        $global:ActiveProfile = $plist[[int]$sel - 1]
        Write-OutputColor "Profile set to: $global:ActiveProfile" "Green"
    } else {
        $global:ActiveProfile = "None"
        Write-OutputColor "No profile active. Using manual selections." "Yellow"
    }
    Read-Host "Press Enter to continue..."
}

# --- Main Menu ---
function Show-Menu {
    Clear-Host
    $menu = @"
+-------------------------------------------------------+
|          WinOptimizer v$Version - by NishantJLU          |
+-------------------------------------------------------+
|  [1] Bloatware Nuke          [8] Safe Uninstall       |
|  [2] Privacy Hardener        [9] Focus Mode           |
|  [3] Dev Machine Setup       [10] Visual Tweaks       |
|  [4] Startup Speed Booster   [11] Browser Maintenance |
|  [5] Junk Cleaner            [12] System Integrity    |
|  [6] Gaming Mode Toggle      [13] Update All (Winget) |
|  [7] Network Reset           [14] Context Menu Nuke   |
+-------------------------------------------------------+
|  [P] Select Profile (Active: $global:ActiveProfile)           |
|  [15] RESTORE CENTER         [A] Run Essential        |
|  [R] Restore All Reg         [S] Create Restore Point |
|  [Q] Quit                                             |
+-------------------------------------------------------+
  State: Gaming Mode [$global:GamingModeState]
"@
    Write-Host $menu -ForegroundColor Cyan
}

# Start Logic
if ($Restore) { Restore-Backups; exit }
if ($RunModule -gt 0) {
    # Non-interactive CLI support (profiles ignored unless pre-set)
    switch ($RunModule) {
        1 { Invoke-BloatwareNuke }
        2 { Invoke-PrivacyHardener }
        3 { Invoke-DevMachineSetup }
        4 { Invoke-StartupSpeedBooster }
        5 { Invoke-JunkCleaner }
        6 { Invoke-GamingModeToggle }
        7 { Invoke-NetworkReset }
        8 { Invoke-SafeUninstall }
        9 { Invoke-FocusMode }
        10 { Invoke-VisualTweaks }
        11 { Invoke-BrowserMaintenance }
        12 { Invoke-SystemIntegrity }
        13 { Invoke-UpdateSystem }
        14 { Invoke-ContextMenuCleanup }
        15 { Invoke-RestoreCenter }
    }
    exit
}

# Interactive Mode
Create-RestorePoint
Invoke-ProfileSelector

while ($true) {
    Show-Menu
    $choice = Read-Host "`nSelect an option"
    switch ($choice) {
        "1" { Invoke-BloatwareNuke }
        "2" { Invoke-PrivacyHardener }
        "3" { Invoke-DevMachineSetup }
        "4" { Invoke-StartupSpeedBooster }
        "5" { Invoke-JunkCleaner }
        "6" { Invoke-GamingModeToggle }
        "7" { Invoke-NetworkReset }
        "8" { Invoke-SafeUninstall }
        "9" { Invoke-FocusMode }
        "10" { Invoke-VisualTweaks }
        "11" { Invoke-BrowserMaintenance }
        "12" { Invoke-SystemIntegrity }
        "13" { Invoke-UpdateSystem }
        "14" { Invoke-ContextMenuCleanup }
        "15" { Invoke-RestoreCenter }
        "P" { Invoke-ProfileSelector }
        "A" { 
            Invoke-BloatwareNuke
            Invoke-PrivacyHardener
            Invoke-JunkCleaner
            Invoke-VisualTweaks
            Invoke-UpdateSystem
        }
        "R" { Restore-Backups }
        "S" { Create-RestorePoint }
        "Q" { exit }
    }
    Read-Host "`nPress Enter to return to menu..."
}

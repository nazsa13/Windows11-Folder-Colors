param(
    # Enable the classic context menu as default (Windows 11 compact menu cannot
    # host static registry verbs at all - everything lives in 'Show more options'
    # unless the classic menu is enabled).
    [switch]$ClassicMenu
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# ------------------------------------------------------------------
# Install layout
# ------------------------------------------------------------------
# App lives in a stable per-user location OUTSIDE OneDrive. desktop.ini files
# store absolute icon paths, so anything that can move or re-sync (Documents,
# Desktop, OneDrive) would silently break every customized folder when moved.
$appRoot = Join-Path $env:LOCALAPPDATA "Programs\FolderColors"
$appDir  = Join-Path $appRoot "app"
$iconsDir = Join-Path $appRoot "icons"
$psDir   = Join-Path $appRoot "ps1"
$exePath = Join-Path $appRoot "FolderColors.exe"
$oldStableDir = Join-Path $env:LOCALAPPDATA "FolderColors"   # pre-v3 location, migrated away

$iconLibraryPath = Join-Path $iconsDir "Windows_11_coloured_icons.icl"
$menuIconPath    = Join-Path $iconsDir "MenuIcon.ico"

# ------------------------------------------------------------------
# Source files (next to this script). Launcher exes are optional;
# registry commands fall back to PowerShell when they are missing.
# ------------------------------------------------------------------
$srcIcl      = Join-Path $scriptDirectory "Windows_11_coloured_icons.icl"
$srcMenuIcon = Join-Path $scriptDirectory "MenuIcon.ico"
$srcRunner   = Join-Path $scriptDirectory "..\launcher\Run-MenuAction.ps1"
$srcRunnerAlt = Join-Path $appDir "Run-MenuAction.ps1"        # when run from the installed copy
$srcRunnerZip = Join-Path $scriptDirectory "Run-MenuAction.ps1" # when run from a flat distributed zip
$srcExe      = Join-Path $scriptDirectory "FolderColors.exe"
$srcSet      = Join-Path $scriptDirectory "Set-FolderIcon.ps1"
$srcReset    = Join-Path $scriptDirectory "Reset-FolderIcon.ps1"
$srcRepair   = Join-Path $scriptDirectory "Repair-FolderColors.ps1"
$srcUninst   = Join-Path $scriptDirectory "Uninstall-FolderColors.ps1"
$srcInstall  = Join-Path $scriptDirectory "Install-FolderColors.ps1"

if (-not (Test-Path -LiteralPath $srcIcl -PathType Leaf))      { throw "Missing required file: $srcIcl" }
if (-not (Test-Path -LiteralPath $srcMenuIcon -PathType Leaf)) { throw "Missing required file: $srcMenuIcon" }

$usingRunner = $false
$runnerSource = $null
if (Test-Path -LiteralPath $srcRunner -PathType Leaf)         { $runnerSource = $srcRunner }   # repo layout
elseif (Test-Path -LiteralPath $srcRunnerZip -PathType Leaf)  { $runnerSource = $srcRunnerZip } # flat zip release
elseif (Test-Path -LiteralPath $srcRunnerAlt -PathType Leaf)  { $runnerSource = $srcRunnerAlt } # installed copy
if ($runnerSource -and (Test-Path -LiteralPath $srcExe -PathType Leaf)) { $usingRunner = $true }

# ------------------------------------------------------------------
# Deploy payload
# ------------------------------------------------------------------
foreach ($dir in @($appRoot, $appDir, $iconsDir, $psDir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
Copy-Item -LiteralPath $srcIcl      -Destination $iconLibraryPath -Force
Copy-Item -LiteralPath $srcMenuIcon -Destination $menuIconPath    -Force
if ($runnerSource) { Copy-Item -LiteralPath $runnerSource -Destination (Join-Path $appDir "Run-MenuAction.ps1") -Force }
foreach ($s in @($srcSet, $srcReset, $srcRepair, $srcUninst, $srcInstall)) {
    if (Test-Path -LiteralPath $s -PathType Leaf) {
        Copy-Item -LiteralPath $s -Destination $psDir -Force
    }
}
if (Test-Path -LiteralPath $srcExe -PathType Leaf) {
    Copy-Item -LiteralPath $srcExe -Destination $exePath -Force
}

# Older installs shipped double-click Setup/Uninstall/Install exes; they are
# gone now - the PowerShell scripts are the only install/uninstall route.
foreach ($stub in @("Setup.exe", "Uninstall.exe", "Install.exe")) {
    $stubPath = Join-Path $appRoot $stub
    if (Test-Path -LiteralPath $stubPath -PathType Leaf) {
        Remove-Item -LiteralPath $stubPath -Force
    }
}

# Migrate away the pre-v3 stable location.
if (Test-Path -LiteralPath $oldStableDir -PathType Container) {
    Remove-Item -LiteralPath $oldStableDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------
# Registry
# ------------------------------------------------------------------
$parentBase = "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell"

# Child key names carry a numeric prefix (01-..20-) so Explorer lists the colors
# in icon-library order (dark grey -> green -> mint -> maroon) instead of
# alphabetically. MUIVerb is what the user reads; the key name only sorts.
$colors = @(
    @{ Key = "01-DarkGrey";  Name = "Dark Grey";  Index = 0 },
    @{ Key = "02-Grey";      Name = "Grey";       Index = 1 },
    @{ Key = "03-White";     Name = "White";      Index = 2 },
    @{ Key = "04-Red";       Name = "Red";        Index = 3 },
    @{ Key = "05-Brown";     Name = "Brown";      Index = 4 },
    @{ Key = "06-Orange";    Name = "Orange";     Index = 5 },
    @{ Key = "07-Yellow";    Name = "Yellow";     Index = 6 },
    @{ Key = "08-Lime";      Name = "Lime";       Index = 7 },
    @{ Key = "09-Olive";     Name = "Olive";      Index = 8 },
    @{ Key = "10-Green";     Name = "Green";      Index = 9 },
    @{ Key = "11-Mint";      Name = "Mint";       Index = 10 },
    @{ Key = "12-Teal";      Name = "Teal";       Index = 11 },
    @{ Key = "13-LightBlue"; Name = "Light Blue"; Index = 12 },
    @{ Key = "14-Blue";      Name = "Blue";       Index = 13 },
    @{ Key = "15-Navy";      Name = "Navy";       Index = 14 },
    @{ Key = "16-SpaceBlue"; Name = "Space Blue"; Index = 15 },
    @{ Key = "17-RacerBlue"; Name = "Racer Blue"; Index = 16 },
    @{ Key = "18-Purple";    Name = "Purple";     Index = 17 },
    @{ Key = "19-Pink";      Name = "Pink";       Index = 18 },
    @{ Key = "20-Maroon";    Name = "Maroon";     Index = 19 }
)

function Set-RegistryStringValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
}

function Set-RegistryDefaultValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-Item -LiteralPath $Path -Value $Value -Force
}

# Remove keys from older versions of this installer: the single 21-item
# submenu (FolderColorMenu), the old direct GUI picker entry and the two
# pre-submenu flat lists.
foreach ($legacy in @("FolderColorMenu", "FolderColorPicker", "FolderColor1", "FolderColor2")) {
    $legacyPath = Join-Path $parentBase $legacy
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force
        Write-Host "Removed legacy menu key: $legacy"
    }
}

if ($usingRunner) {
    # Hidden native runner: no console flash for any menu action.
    $colorCommandTpl = "`"$exePath`" --run color `"%1`" {0}"
    $resetCommand = "`"$exePath`" --run reset `"%1`""
} else {
    # Fallback: PowerShell commands (console window appears briefly).
    $runnerScript = Join-Path $appDir "Run-MenuAction.ps1"
    $colorCommandTpl = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runnerScript`" -Mode color -Folder `"%1`" -IconIndex {0}"
    $resetCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runnerScript`" -Mode reset -Folder `"%1`""
}

# Windows hard-caps a static cascading submenu at 16 items per group, so a
# single 21-item flyout silently loses its last 5 entries. Colors therefore
# ship as TWO submenus of 10 (hue order) plus a separate top-level Reset entry.
# Key names sort Menu1 < Menu2 < Reset; MUIVerb is the visible label.
$menuGroups = @(
    @{ Key = "FolderColorMenu1"; Verb = "Set Folder Color (1/2): Dark to Green"; Colors = $colors[0..9] },
    @{ Key = "FolderColorMenu2"; Verb = "Set Folder Color (2/2): Mint to Maroon"; Colors = $colors[10..19] }
)

# SubCommands stays EMPTY: a non-empty list makes Explorer resolve verbs from
# Explorer\CommandStore (unused here) and yields an empty flyout.
foreach ($group in $menuGroups) {
    $menuPath = Join-Path $parentBase $group.Key
    Set-RegistryStringValue -Path $menuPath -Name "MUIVerb" -Value $group.Verb
    Set-RegistryStringValue -Path $menuPath -Name "Icon" -Value $menuIconPath
    Set-RegistryStringValue -Path $menuPath -Name "SubCommands" -Value ""

    # Remove children this version no longer ships (older key names, colors
    # moved to the other submenu, ...).
    $keepIds = @($group.Colors | ForEach-Object { $_.Key })
    $menuShellPath = Join-Path $menuPath "shell"
    if (Test-Path -LiteralPath $menuShellPath) {
        foreach ($child in (Get-ChildItem -LiteralPath $menuShellPath)) {
            if ($keepIds -notcontains $child.PSChildName) {
                Remove-Item -LiteralPath $child.PSPath -Recurse -Force
                Write-Host "Removed stale entry: $($group.Key)\$($child.PSChildName)"
            }
        }
    }

    foreach ($color in $group.Colors) {
        $itemPath = Join-Path (Join-Path $menuPath "shell") $color.Key
        Set-RegistryStringValue -Path $itemPath -Name "MUIVerb" -Value $color.Name
        Set-RegistryStringValue -Path $itemPath -Name "Icon" -Value "$iconLibraryPath,$($color.Index)"
        $cmd = $colorCommandTpl -f $color.Index
        if (-not $usingRunner) { $cmd = $cmd.Replace('"%1"', '"%1" ') }
        Set-RegistryDefaultValue -Path (Join-Path $itemPath "command") -Value $cmd
    }
}

# Reset is its own top-level entry (a plain command, no flyout) so it is
# reachable in one click and is not pushed out by the 16-item cap.
$resetItemPath = Join-Path $parentBase "FolderColorReset"
Set-RegistryStringValue -Path $resetItemPath -Name "MUIVerb" -Value "Reset Folder Color"
Set-RegistryStringValue -Path $resetItemPath -Name "Icon" -Value "shell32.dll,240"
Set-RegistryDefaultValue -Path (Join-Path $resetItemPath "command") -Value $resetCommand

# ------------------------------------------------------------------
# Optional: make the classic context menu the default right-click menu.
# The Windows 11 compact menu never shows static registry verbs directly;
# with the classic menu enabled, both Folder Colors entries (including the
# submenu arrow) appear on the FIRST right-click.
# ------------------------------------------------------------------
if ($ClassicMenu) {
    $clsidKey = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    if (-not (Test-Path -LiteralPath $clsidKey)) {
        New-Item -Path $clsidKey -Force | Out-Null
    }
    Set-Item -LiteralPath $clsidKey -Value "" -Force   # empty default value activates the classic menu
    Write-Host "Classic context menu enabled as default (applies after Explorer restart)."
    Write-Host "To undo: reg delete \"HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\" /f"
}

# ------------------------------------------------------------------
# Repair existing colored folders that point at any older icon location
# (repo copy, pre-v3 stable dir, ...) so their icons come back.
# ------------------------------------------------------------------
$repairScript = Join-Path $psDir "Repair-FolderColors.ps1"
if (Test-Path -LiteralPath $repairScript -PathType Leaf) {
    try {
        # Scope to the user profile: fast, and where colored folders realistically live.
        # (Scanning every fixed drive can hang for minutes on slow/network roots.)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $repairScript -Apply -Roots @($env:USERPROFILE) | Out-Null
    } catch {
        Write-Host "Note: automatic repair of existing colored folders failed: $_"
    }
}

Write-Host "Folder Colors installed to: $appRoot"
if ($usingRunner) {
    Write-Host "Context menu runs fully hidden via FolderColors.exe."
} else {
    Write-Host "Note: launcher exes not found next to this script; menu uses hidden PowerShell windows."
}
Write-Host "  Menu entries: 'Set Folder Color (1/2): Dark to Green' (10 colors),"
Write-Host "                'Set Folder Color (2/2): Mint to Maroon' (10 colors), and 'Reset Folder Color'."
Write-Host "  Split into two submenus because Windows caps a static flyout at 16 items."
if (-not $ClassicMenu) {
    Write-Host "Note: the Windows 11 compact menu cannot host registry verbs; entries appear under"
    Write-Host "'Show more options'. Re-run with -ClassicMenu to put them on the first right-click."
}
Write-Host "If the menu does not appear immediately, restart File Explorer once."

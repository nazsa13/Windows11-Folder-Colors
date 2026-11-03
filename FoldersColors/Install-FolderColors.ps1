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

$colors = @(
    @{ Id = "DarkGrey"; Name = "Dark Grey"; Index = 0 },
    @{ Id = "Grey"; Name = "Grey"; Index = 1 },
    @{ Id = "Red"; Name = "Red"; Index = 3 },
    @{ Id = "Brown"; Name = "Brown"; Index = 4 },
    @{ Id = "Orange"; Name = "Orange"; Index = 5 },
    @{ Id = "Lime"; Name = "Lime"; Index = 7 },
    @{ Id = "Olive"; Name = "Olive"; Index = 8 },
    @{ Id = "Green"; Name = "Green"; Index = 9 },
    @{ Id = "Mint"; Name = "Mint"; Index = 10 },
    @{ Id = "LightBlue"; Name = "Light Blue"; Index = 12 },
    @{ Id = "Blue"; Name = "Blue"; Index = 13 },
    @{ Id = "Navy"; Name = "Navy"; Index = 14 },
    @{ Id = "RacerBlue"; Name = "Racer Blue"; Index = 16 },
    @{ Id = "Purple"; Name = "Purple"; Index = 17 },
    @{ Id = "Pink"; Name = "Pink"; Index = 18 },
    @{ Id = "Maroon"; Name = "Maroon"; Index = 19 }
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

# Remove keys from older versions of this installer (the direct GUI picker
# entry was removed; delete any stale copy of it too).
foreach ($legacy in @("FolderColorPicker", "FolderColor1", "FolderColor2")) {
    $legacyPath = Join-Path $parentBase $legacy
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force
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

# Single entry: classic cascading submenu with all colors + Reset (arrow +
# flyout under "Show more options" on Windows 11; full menu when the classic
# menu is enabled). SubCommands stays EMPTY: a non-empty list makes Explorer
# resolve verbs from Explorer\CommandStore (unused here) and yields an empty flyout.
$menuPath = Join-Path $parentBase "FolderColorMenu"
Set-RegistryStringValue -Path $menuPath -Name "MUIVerb" -Value "Set Folder Color"
Set-RegistryStringValue -Path $menuPath -Name "Icon" -Value $menuIconPath
Set-RegistryStringValue -Path $menuPath -Name "SubCommands" -Value ""

# Remove color children that the menu no longer ships (older installs may have
# registered entries this version dropped).
$keepIds = @(($colors | ForEach-Object { $_.Id }) + "Reset")
$menuShellPath = Join-Path $menuPath "shell"
if (Test-Path -LiteralPath $menuShellPath) {
    foreach ($child in (Get-ChildItem -LiteralPath $menuShellPath)) {
        if ($keepIds -notcontains $child.PSChildName) {
            Remove-Item -LiteralPath $child.PSPath -Recurse -Force
            Write-Host "Removed stale color entry: $($child.PSChildName)"
        }
    }
}

foreach ($color in $colors) {
    $itemPath = Join-Path (Join-Path $menuPath "shell") $color.Id
    Set-RegistryStringValue -Path $itemPath -Name "MUIVerb" -Value $color.Name
    Set-RegistryStringValue -Path $itemPath -Name "Icon" -Value "$iconLibraryPath,$($color.Index)"
    $cmd = $colorCommandTpl -f $color.Index
    if (-not $usingRunner) { $cmd = $cmd.Replace('"%1"', '"%1" ') }
    Set-RegistryDefaultValue -Path (Join-Path $itemPath "command") -Value $cmd
}

$resetItemPath = Join-Path (Join-Path $menuPath "shell") "Reset"
Set-RegistryStringValue -Path $resetItemPath -Name "MUIVerb" -Value "Reset to Default"
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
Write-Host "  'Set Folder Color' - right-click submenu with all 16 colors + Reset to Default."
if (-not $ClassicMenu) {
    Write-Host "Note: the Windows 11 compact menu cannot host registry verbs; entries appear under"
    Write-Host "'Show more options'. Re-run with -ClassicMenu to put them on the first right-click."
}
Write-Host "If the menu does not appear immediately, restart File Explorer once."

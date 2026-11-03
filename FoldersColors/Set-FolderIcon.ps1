param(
    [Parameter(Mandatory=$true)][string]$Folder,
    [Parameter(Mandatory=$false)][int]$IconIndex,
    [Parameter(Mandatory=$false)][string]$IconPath,
    [switch]$Apply
)

# ------------------------------------------------------------------
# Folder resolution: always from -Folder (no dialogs).
# ------------------------------------------------------------------
$Folder = "$Folder".Trim('"')

if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    throw "Target is not a folder: $Folder"
}

# ------------------------------------------------------------------
# Icon library resolution: stable install location first, then this
# script's folder.
# ------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($IconPath)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $stablePath = Join-Path $env:LOCALAPPDATA "Programs\FolderColors\icons\Windows_11_coloured_icons.icl"
    $fallbackPath = Join-Path $scriptDirectory "Windows_11_coloured_icons.icl"
    if (Test-Path -LiteralPath $stablePath -PathType Leaf) {
        $IconPath = $stablePath
    } else {
        $IconPath = $fallbackPath
    }
}

$IconPath = [System.IO.Path]::GetFullPath($IconPath)

# ------------------------------------------------------------------
# Apply mode: write desktop.ini and refresh Explorer.
# ------------------------------------------------------------------
if (-not $Apply -or $IconIndex -lt 0) {
    throw "Nothing to do: pass -IconIndex with -Apply (use Reset-FolderIcon.ps1 to reset)."
}

if (-not (Test-Path -LiteralPath $IconPath -PathType Leaf)) {
    throw "Icon library not found: $IconPath"
}

$ErrorActionPreference = "Continue"

$desktopIni = Join-Path $Folder "desktop.ini"

$content = @"
[.ShellClassInfo]
IconResource=$IconPath,$IconIndex
IconFile=$IconPath
IconIndex=$IconIndex
"@

# Write desktop.ini (Unicode works well for desktop.ini)
Set-Content -LiteralPath $desktopIni -Value $content -Encoding Unicode -Force

# Mark folder as customizable and hide desktop.ini
attrib +s +r "$Folder"
attrib +h "$desktopIni"

# Refresh Explorer for the target folder
$shell = New-Object -ComObject Shell.Application
$ns = $shell.NameSpace($Folder)
if ($ns -and $ns.Self) { $ns.Self.InvokeVerb("refresh") }

# Notify shell that folder metadata changed (SHChangeNotify_RunDLL export was
# removed from shell32.dll on recent builds; rundll32 on it pops an error dialog).
if (-not ("FolderColors.ShellNotify" -as [type])) {
    Add-Type -Namespace FolderColors -Name ShellNotify -MemberDefinition '
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
    ' | Out-Null
}
# SHCNE_ASSOCCHANGED (0x08000000) with SHCNF_FLUSH (0x1000): rebuild icon cache now.
[FolderColors.ShellNotify]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)

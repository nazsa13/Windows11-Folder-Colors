param(
    [Parameter(Mandatory = $true)][ValidateSet("color", "reset")]
    [string]$Mode,
    [Parameter(Mandatory = $false)][string]$Folder,
    [Parameter(Mandatory = $false)][int]$IconIndex,
    [Parameter(Mandatory = $false)][string]$LogFile
)

# Hidden background worker used by FolderColors.exe --run.
# Never writes to a console and shows no UI; all diagnostics go to $LogFile.

function Write-Log([string]$message) {
    if ($LogFile) {
        try {
            Add-Content -LiteralPath $LogFile -Value ("[" + (Get-Date -Format "HH:mm:ss") + "] " + $message) -ErrorAction SilentlyContinue
        } catch { }
    }
}

# The folder is always supplied by the context menu ("%1"). No dialog fallback.
$Folder = "$Folder".Trim('"')
if ([string]::IsNullOrWhiteSpace($Folder)) {
    Write-Log "no folder passed - nothing to do"
    exit 1
}

if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    Write-Log "target is not a folder: $Folder"
    exit 1
}

$appRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)   # ...\FolderColors
$appDir  = Join-Path $appRoot "app"
$ps1Dir  = Join-Path $appRoot "ps1"      # original scripts, kept for repair/uninstall
# NOTE: do not name this $psHome - that collides with PowerShell's read-only $PSHOME.

# SHChangeNotify via P/Invoke (the SHChangeNotify_RunDLL rundll32 export was
# removed from shell32.dll on recent builds and pops an error dialog).
# Defined once at startup so both apply AND reset can use it - reset used to
# fail its cache flush when it was the first action in a fresh worker.
if (-not ("FolderColors.ShellNotify" -as [type])) {
    Add-Type -Namespace FolderColors -Name ShellNotify -MemberDefinition '
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
    ' | Out-Null
}

# ------------------------------------------------------------------
# Apply / reset helpers
# ------------------------------------------------------------------
function Invoke-ApplyIcon([string]$folder, [int]$iconIndex, [string]$iconLibraryPath) {
    $desktopIni = Join-Path $folder "desktop.ini"
    $content = "[.ShellClassInfo]`r`nIconResource=$iconLibraryPath,$iconIndex`r`nIconFile=$iconLibraryPath`r`nIconIndex=$iconIndex`r`n"
    Set-Content -LiteralPath $desktopIni -Value $content -Encoding Unicode -Force
    attrib +s +r "$folder"
    attrib +h "$desktopIni"
    $shell = New-Object -ComObject Shell.Application
    $ns = $shell.NameSpace($folder)
    if ($ns -and $ns.Self) { $null = $ns.Self.InvokeVerb("refresh") }
    # SHCNE_ASSOCCHANGED (0x08000000) with SHCNF_FLUSH (0x1000): rebuild icon cache now.
    [FolderColors.ShellNotify]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Log "applied index $iconIndex to $folder"
}

function Invoke-ResetFolder([string]$folder) {
    $desktopIni = Join-Path $folder "desktop.ini"
    if (Test-Path -LiteralPath $desktopIni -PathType Leaf) {
        attrib -h -s -r "$desktopIni"
        Remove-Item -LiteralPath $desktopIni -Force
    }
    attrib -r -s "$folder"
    $shell = New-Object -ComObject Shell.Application
    $ns = $shell.NameSpace($folder)
    if ($ns -and $ns.Self) { $null = $ns.Self.InvokeVerb("refresh") }
    [FolderColors.ShellNotify]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Log "reset $folder"
}

# Resolve the icon library.
$iconLibrary = Join-Path $env:LOCALAPPDATA "Programs\FolderColors\icons\Windows_11_coloured_icons.icl"
if (-not (Test-Path -LiteralPath $iconLibrary -PathType Leaf)) {
    $iconLibrary = Join-Path (Split-Path -Parent $ps1Dir) "Windows_11_coloured_icons.icl"
}
if (-not (Test-Path -LiteralPath $iconLibrary -PathType Leaf)) {
    $iconLibrary = Join-Path $appRoot "icons\Windows_11_coloured_icons.icl"
}

Write-Log "mode=$Mode folder=$Folder library=$iconLibrary"

switch ($Mode) {
    "color" {
        Invoke-ApplyIcon $Folder $IconIndex $iconLibrary
    }
    "reset" {
        Invoke-ResetFolder $Folder
    }
}

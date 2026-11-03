param(
    [Parameter(Mandatory=$true)][string]$Folder
)

$Folder = $Folder.Trim('"')

if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    throw "Target is not a folder: $Folder"
}

$desktopIni = Join-Path $Folder "desktop.ini"

if (Test-Path -LiteralPath $desktopIni -PathType Leaf) {
    attrib -h -s -r "$desktopIni" | Out-Null
    Remove-Item -LiteralPath $desktopIni -Force
}

attrib -r -s "$Folder" | Out-Null

$shell = New-Object -ComObject Shell.Application
$ns = $shell.NameSpace($Folder)
if ($ns -and $ns.Self) { $ns.Self.InvokeVerb("refresh") }

# SHChangeNotify_RunDLL export was removed from shell32.dll on recent builds;
# rundll32 on it pops an error dialog. Use the supported API directly.
if (-not ("FolderColors.ShellNotify" -as [type])) {
    Add-Type -Namespace FolderColors -Name ShellNotify -MemberDefinition '
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
    ' | Out-Null
}
# SHCNE_ASSOCCHANGED (0x08000000) with SHCNF_FLUSH (0x1000): rebuild icon cache now.
[FolderColors.ShellNotify]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)

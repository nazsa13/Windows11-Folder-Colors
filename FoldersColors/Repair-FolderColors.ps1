<#
.SYNOPSIS
    Repairs folder customizations whose desktop.ini points at a dead copy of
    Windows_11_coloured_icons.icl (typically after this project was moved).

.DESCRIPTION
    desktop.ini files store absolute icon paths. If the FolderColors project is
    moved, renamed, or re-synced (e.g. under OneDrive), every customized folder
    silently loses its icon. This script finds desktop.ini files whose
    IconResource/IconFile point at a Windows_11_coloured_icons.icl that no longer
    exists and re-points them at the live icon library.

    By default it runs in DRY-RUN mode and only prints what it would change.
    Pass -Apply to actually rewrite the files. All other desktop.ini content is
    preserved, encoding is kept (Unicode/ASCII), and file/folder attributes are
    restored afterwards.

.PARAMETER Apply
    Actually rewrite the broken desktop.ini files. Without this switch nothing
    is modified.

.PARAMETER Roots
    Root paths to scan recursively. Defaults to the user profile and all fixed
    local drives.

.EXAMPLE
    .\Repair-FolderColors.ps1            # show what would be repaired
    .\Repair-FolderColors.ps1 -Apply     # repair
#>
param(
    [switch]$Apply,
    [string[]]$Roots
)

$ErrorActionPreference = "Continue"

# Locate the live icon library: v3 installed app, v2 stable dir, then this script's folder.
$liveLibrary = Join-Path $env:LOCALAPPDATA "Programs\FolderColors\icons\Windows_11_coloured_icons.icl"
if (-not (Test-Path -LiteralPath $liveLibrary -PathType Leaf)) {
    $liveLibrary = Join-Path $env:LOCALAPPDATA "FolderColors\Windows_11_coloured_icons.icl"
}
if (-not (Test-Path -LiteralPath $liveLibrary -PathType Leaf)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $liveLibrary = Join-Path $scriptDirectory "Windows_11_coloured_icons.icl"
}
if (-not (Test-Path -LiteralPath $liveLibrary -PathType Leaf)) {
    throw "Live icon library not found. Run Install-FolderColors.ps1 first."
}
Write-Host "Live icon library: $liveLibrary"
Write-Host ""

if (-not $Roots) {
    $Roots = @("C:\Users\$env:USERNAME") + @(
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
            Where-Object { $_.DeviceID -ne "C:" } |
            ForEach-Object { $_.DeviceID + "\" }
    )
}

# Match IconResource=...Windows_11_coloured_icons.icl,<index> (also IconFile= lines)
$libraryName = "Windows_11_coloured_icons.icl"
$iconLinePattern = '^(IconResource|IconFile)=(.*[\\/]' + [regex]::Escape($libraryName) + ')(,\s*-?\d+)?$'

$broken = New-Object System.Collections.Generic.List[object]

foreach ($root in $Roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Write-Host "Scanning $root ..."
    $dirs = Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) {
        $ini = Join-Path $dir.FullName "desktop.ini"
        if (-not (Test-Path -LiteralPath $ini -PathType Leaf -ErrorAction SilentlyContinue)) { continue }

        $bytes = [System.IO.File]::ReadAllBytes($ini)
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $encoding = "Unicode" }
        elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $encoding = "UTF8" }
        else { $encoding = "Default" }

        $content = [System.IO.File]::ReadAllLines($ini)
        $iconLines = @($content | Where-Object { $_ -match $iconLinePattern })
        if ($iconLines.Count -eq 0) { continue }

        # Only a repair candidate if the referenced library does not exist anymore.
        $stillAlive = $true
        foreach ($line in $iconLines) {
            $target = ($line -split "=", 2)[1]
            if ($target -match ',\s*(-?\d+)\s*$') { $target = $target -replace ',\s*-?\d+\s*$', '' }
            $target = [Environment]::ExpandEnvironmentVariables($target.Trim())
            if ($target -ne $liveLibrary -and -not (Test-Path -LiteralPath $target -PathType Leaf)) {
                $stillAlive = $false
            }
        }
        if ($stillAlive) { continue }

        $broken.Add([pscustomobject]@{
            Folder   = $dir.FullName
            Ini      = $ini
            Encoding = $encoding
            Lines    = $iconLines
        })
    }
}

Write-Host ""
if ($broken.Count -eq 0) {
    Write-Host "No broken folder customizations found. Nothing to do."
    return
}

Write-Host "Found $($broken.Count) folder(s) with dead icon paths:"
foreach ($entry in $broken) {
    Write-Host ""
    Write-Host "  $($entry.Folder)"
    foreach ($line in $entry.Lines) { Write-Host "    now: $line" }
}

if (-not $Apply) {
    Write-Host ""
    Write-Host "DRY RUN - no files were modified. Re-run with -Apply to fix these."
    return
}

Write-Host ""
$folderAttribCache = @{}
foreach ($entry in $broken) {
    $ini = $entry.Ini
    $folder = $entry.Folder

    # Remember and strip attributes that block writing.
    if (-not $folderAttribCache.ContainsKey($folder)) {
        $folderAttribCache[$folder] = (Get-Item -LiteralPath $folder -Force).Attributes
    }
    $iniItem = Get-Item -LiteralPath $ini -Force
    $iniAttribsBefore = $iniItem.Attributes
    $iniItem.Attributes = 'Archive'
    $folderItem = Get-Item -LiteralPath $folder -Force
    $folderItem.Attributes = ($folderItem.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)) -bor [IO.FileAttributes]::Directory

    $content = [System.IO.File]::ReadAllLines($ini)
    $newContent = foreach ($line in $content) {
        if ($line -match $iconLinePattern) {
            $index = ""
            if ($line -match ',\s*(-?\d+)\s*$') { $index = $Matches[1] }
            $key = ($line -split "=", 2)[0]
            if ($key -eq "IconResource") { "$key=$liveLibrary,$index" }
            else { "$key=$liveLibrary" }   # IconFile must not carry an index
        } else {
            $line
        }
    }

    try {
        switch ($entry.Encoding) {
            "Unicode" { [System.IO.File]::WriteAllLines($ini, $newContent, (New-Object System.Text.UnicodeEncoding($false, $true))) }
            "UTF8"    { [System.IO.File]::WriteAllLines($ini, $newContent, (New-Object System.Text.UTF8Encoding($false, $true))) }
            default   { [System.IO.File]::WriteAllLines($ini, $newContent) }
        }
        # Restore attributes: ini hidden+system, folder system+readonly (required by Explorer).
        $iniItem.Attributes = 'Archive, Hidden, System'
        $folderItem.Attributes = $folderAttribCache[$folder]

        Write-Host "  repaired: $folder"
    } catch {
        Write-Warning "  FAILED: $folder -> $_"
        $iniItem.Attributes = $iniAttribsBefore
        $folderItem.Attributes = $folderAttribCache[$folder]
    }
}

# Nudge the shell so icons refresh without a logoff.
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

Write-Host ""
Write-Host "Done. Repaired $($broken.Count) folder(s)."
Write-Host "If any icon still looks stale, press F5 in that folder or restart File Explorer."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------------
# Registry cleanup: current + every legacy layout this project ever used.
# ------------------------------------------------------------------
$registryPaths = @(
    "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\FolderColorPicker",
    "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\FolderColorMenu",
    "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\FolderColor1",
    "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\FolderColor2",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.DarkGrey",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Grey",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.White",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Red",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Brown",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Orange",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Yellow",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Lime",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Olive",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Green",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Mint",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Teal",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.LightBlue",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Blue",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Navy",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.SpaceBlue",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.RacerBlue",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Purple",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Pink",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Maroon",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\FolderColor.Reset"
)

foreach ($path in $registryPaths) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

# ------------------------------------------------------------------
# Installed app directory (v3 layout).
# ------------------------------------------------------------------
$appRoot = Join-Path $env:LOCALAPPDATA "Programs\FolderColors"
if (Test-Path -LiteralPath $appRoot -PathType Container) {
    Remove-Item -LiteralPath $appRoot -Recurse -Force
    Write-Host "Removed installed app at $appRoot."
}

# Pre-v3 stable icon location, if it still exists.
$oldStableDir = Join-Path $env:LOCALAPPDATA "FolderColors"
if (Test-Path -LiteralPath $oldStableDir -PathType Container) {
    Remove-Item -LiteralPath $oldStableDir -Recurse -Force
    Write-Host "Removed legacy icon location $oldStableDir."
}

Write-Host "Folder colors context menu removed for current user."
Write-Host "If entries still appear, restart File Explorer once."
Write-Host ""
Write-Host "Note: folders you already colored keep their desktop.ini until you reset them."
Write-Host "Their icons now point at the removed library, so they fall back to the default folder icon."
Write-Host "To restore a folder cleanly, use the 'Reset to Default' menu action BEFORE uninstalling,"
Write-Host "or run Reset-FolderIcon.ps1 -Folder \"C:\path\to\folder\" from the repository copy."

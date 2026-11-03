@echo off
setlocal
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
    echo .NET Framework 4.x C# compiler not found.
    exit /b 1
)

set OUTDIR=%~dp0out
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

rem Embedded Win32 icon: MenuIcon.ico lives next to this script, or in ..\FoldersColors.
set ICON=%~dp0app.ico
if not exist "%ICON%" if exist "%~dp0..\FoldersColors\MenuIcon.ico" copy /y "%~dp0..\FoldersColors\MenuIcon.ico" "%ICON%" >nul
set ICONARG=
if exist "%ICON%" set ICONARG=/win32icon:"%ICON%"

rem One native app: the hidden context-menu runner (no installer UI, no picker,
rem no double-click behavior - install/uninstall is done by the PS scripts).
"%CSC%" /nologo /target:winexe /platform:anycpu /out:"%OUTDIR%\FolderColors.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll %ICONARG% "%~dp0AppLauncher.cs" "%~dp0versioninfo.cs"
if errorlevel 1 exit /b 1

rem Payload: the runner plus what it needs at runtime.
if not exist "%OUTDIR%\payload\icons" mkdir "%OUTDIR%\payload\icons"
copy /y "%OUTDIR%\FolderColors.exe" "%OUTDIR%\payload\FolderColors.exe" >nul
copy /y "%~dp0Run-MenuAction.ps1" "%OUTDIR%\payload\Run-MenuAction.ps1" >nul
copy /y "%~dp0..\FoldersColors\Windows_11_coloured_icons.icl" "%OUTDIR%\payload\icons\" >nul
copy /y "%~dp0..\FoldersColors\MenuIcon.ico" "%OUTDIR%\payload\icons\" >nul

echo Built:
dir /b "%OUTDIR%\*.exe"
echo Payload:
dir /b "%OUTDIR%\payload"
endlocal

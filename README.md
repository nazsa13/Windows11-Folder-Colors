# Windows 11 Folder Colors

Adds **two `Set Folder Color` submenus** — 10 colors each, **20 colored folder icons** in total — plus a **`Reset Folder Color`** action to the right-click menu of any folder in Windows Explorer.

Works fully in the background — no console flashes, no GUI popups, no installer windows. Menu-only by design.

![All 20 folder colors available from the right-click menu](docs/og-image.png)

**Note: The `.icl` file used in this Project is Not Made by me, i only made the codes.**
([.icl Source](https://www.deviantart.com/abs96/art/Windows-11-coloured-folder-icons-896431403))

---

## 1. What it looks like

Right-click any folder:

![Two screenshots of the real Windows 11 right-click menu: Set Folder Color (1/2): Dark to Green, Set Folder Color (2/2): Mint to Maroon and Reset Folder Color, with each submenu open showing ten colored folder icons](docs/menu-screenshot.png)

*The real right-click menu (two captures, one per submenu): **three entries**, each submenu holding exactly ten colors in hue order — Dark Grey → Green, then Mint → Maroon.*

- **20 colors in two submenus of 10**, each color child carries the real colored icon in the menu itself:
  - `Set Folder Color (1/2): Dark to Green` — Dark Grey, Grey, White, Red, Brown, Orange, Yellow, Lime, Olive, Green
  - `Set Folder Color (2/2): Mint to Maroon` — Mint, Teal, Light Blue, Blue, Navy, Space Blue, Racer Blue, Purple, Pink, Maroon
- **Why two submenus?** Windows hard-caps a registry-based static cascading submenu at **16 items**. A single 21-entry flyout silently loses its last five colors (that is the bug v3.1 had: only 16 of 21 showed). Splitting into 10 + 10 keeps every color reachable — well under the cap.
- `Reset Folder Color` is a **separate top-level entry** (no flyout, one click) and deletes the folder's `desktop.ini`, restoring the standard yellow folder icon.
- There is **no** separate one-click picker entry and **no** GUI dialog — the old `FolderColorPicker` entry was deliberately removed.

## 2. How it works (architecture)

The whole tool is four layers, each doing one job:

```
Explorer right-click
  → registry keys (HKCU\Software\Classes\Directory\shell\FolderColorMenu1, FolderColorMenu2, FolderColorReset)
      → FolderColors.exe  --run color <folder> <index>   (hidden native runner, NO console)
          → app\Run-MenuAction.ps1                        (hidden PowerShell worker)
              → writes <folder>\desktop.ini with IconResource=<library>,<colorIndex>
                  → SHChangeNotify() P/Invoke → Explorer notices → icon refreshes
```

1. **Registry** — static shell verbs. Three sibling keys under `Directory\shell`:
   - `FolderColorMenu1` — `MUIVerb = "Set Folder Color (1/2): Dark to Green"`, 10 children (icon indices 0–9)
   - `FolderColorMenu2` — `MUIVerb = "Set Folder Color (2/2): Mint to Maroon"`, 10 children (indices 10–19)
   - `FolderColorReset` — `MUIVerb = "Reset Folder Color"`, a plain `command` (no flyout)

   Both parents keep `SubCommands` **empty on purpose** (a non-empty value makes Explorer resolve verbs from Explorer's CommandStore and renders an empty flyout). Each child is `shell\<nn>-<ColorId>\command` with the runner command and color index; the numeric prefix is what makes Explorer list the colors in hue order instead of alphabetically. The 10-per-submenu split exists because Windows caps a registry cascading submenu at 16 items (see § 8).
2. **`FolderColors.exe`** — a small native C# runner (compiled from [launcher/AppLauncher.cs](launcher/AppLauncher.cs), no SDK needed). It is registered as the command for every menu item. It spawns PowerShell **with `CreateNoWindow = true`** — this is why nothing ever flashes. Double-clicking it deliberately does nothing (it has no GUI and refuses to act as an installer).
3. **`app\Run-MenuAction.ps1`** — the hidden worker. Applies (`--run color`) or resets (`--run reset`), writes `desktop.ini` as Unicode, sets folder attributes (`+s +r` on the folder, `+h` on the ini), then notifies the shell.
4. **Icon library** — `Windows_11_coloured_icons.icl` (6 MB, 20 colored folder icon resources indexed 0–19; the menu exposes all 20). Lives in the installed `icons\` folder; `desktop.ini` files point **absolute paths** at it.

### How each colored folder is stored

Every colored folder gets its own hidden `desktop.ini`:

```ini
[.ShellClassInfo]
IconResource=C:\Users\<you>\AppData\Local\Programs\FolderColors\icons\Windows_11_coloured_icons.icl,<index>
IconFile=C:\Users\<you>\AppData\Local\Programs\FolderColors\icons\Windows_11_coloured_icons.icl
IconIndex=<index>
```

### The classic-menu toggle (important on Windows 11)

Windows 11's default compact right-click menu **cannot host static registry verbs at all**. The tool sets a per-user toggle that re-enables the classic full menu as default:

```
HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32   (empty default value)
```

- With it: the submenu appears on the **first** right-click (this is how the owner runs it now).
- Without it: entries only appear under **Show more options** (Shift+F10).
- Without a signed/packaged MSIX shell extension there is no way into the compact menu itself — documented limitation, not a bug.

## 3. Verified working state (audit of the owner's current setup)

| Component | State on this device |
|---|---|
| OS / PowerShell | Windows 11 26300 (25H2), PowerShell 5.1 — supported and tested |
| Menu entries | `FolderColorMenu1` + `FolderColorMenu2` — **10 children each** (indices 0–9, 10–19) — plus `FolderColorReset` as its own command entry. No single flyout exceeds Windows' 16-item cap. |
| Legacy keys | `FolderColorMenu` (v3.1's 21-item flyout), `FolderColorPicker`, `FolderColor1/2` — **deleted by the installer** |
| GUI picker entry | **absent** (removed everywhere: registry, installer, worker, legacy .reg) |
| Installer exes | **none** (Setup/Uninstall/Install deleted from source, build and app dir; runner-only exe) |
| Classic menu | **enabled** (entries on first right-click) |
| Installed runner | `%LOCALAPPDATA%\Programs\FolderColors\FolderColors.exe` (51,200 bytes, Oct 2026 build) |
| rundll32 remnants | **zero invocations anywhere** — `SHChangeNotify_RunDLL` was removed from newer shell32.dll builds (caused the old "Error in shell32.dll / Missing entry" popup). All notify paths use the P/Invoke now. |
| Apply / Reset flow | round-trip tested: exit 0, `desktop.ini` written with stable `%LOCALAPPDATA%` path, reset removes it |
| Evidence it's working | `app\Logs\menu-action-YYYY-MM-DD.log` — every action is logged there |

## 4. File-by-file guide (which file is which)

| File | Role |
|---|---|
| `FoldersColors/Install-FolderColors.ps1` | **The installer.** Deploys the app to `%LOCALAPPDATA%\Programs\FolderColors`, registers the three menu entries (`FolderColorMenu1/2` + `FolderColorReset`), deletes legacy leftovers (old 21-item `FolderColorMenu`, GUI-picker key, FolderColor1/2, stub exes), re-points broken desktop.ini files, sets the classic-menu toggle with `-ClassicMenu`. Idempotent — re-run it any time. |
| `FoldersColors/install.cmd` | Double-click entry point shipped in the zip: runs the installer with `-ClassicMenu`. |
| `FoldersColors/Uninstall-FolderColors.ps1` | **The uninstaller.** Removes all menu keys (incl. every legacy layout), deletes the app dir, restarts Explorer. |
| `FoldersColors/FolderColors.exe` | The hidden runner (the only exe). Compiled output; never call it by hand — the menu does. |
| `FoldersColors/Windows_11_coloured_icons.icl` | The icon library — 20 color resources indexed 0–19, **all 20 now in the menu** — **third-party**, see the credit up top. |
| `FoldersColors/MenuIcon.ico` | Icon shown on the menu entry itself. |
| `FoldersColors/Repair-FolderColors.ps1` | Re-points broken `desktop.ini` files at the live library. Dry-run by default; pass `-Apply`. |
| `FoldersColors/Set-FolderIcon.ps1` | Apply a color from a script: `-Folder <path> -IconIndex 3 -Apply`. |
| `FoldersColors/Reset-FolderIcon.ps1` | Reset one folder from a script: `-Folder <path>`. |
| `FoldersColors/Install-FolderColors.reg`, `Uninstall-FolderColors.reg` | Legacy manual registry route (kept for reference; the PS installer is the real installer). |
| `FoldersColors/desktop.ini`, `FoldersColors/New folder/` | Marks the repo folder itself as colored — **not part of the tool**, ignore them. |
| `launcher/AppLauncher.cs` + `launcher/versioninfo.cs` | Runner source (C#, compiled with the in-box .NET 4 compiler). |
| `launcher/Run-MenuAction.ps1` | Worker source (copied to the app dir on install). |
| `launcher/build.cmd` | Rebuilds `FolderColors.exe` → `launcher/out/`. |
| `docs/og-image.png`, `docs/favicon.ico`, `README.md` | Docs and the release banner/favicon. The banner shows all 20 real library icons. |
| `%LOCALAPPDATA%\Programs\FolderColors\` | The **installed** copy (this is what actually runs; registry points here). |

## 5. Install on a NEW device

### Route A — release zip (recommended)

1. **Download** `FolderColors.zip` from the project's GitHub Releases page (the download page mirrors this guide). Extract it anywhere you like — e.g. `C:\Tools\FolderColors\`. Any folder works on disk; see § 7 before moving synced/cloud paths around later.
2. **Double-click `install.cmd`** inside the extracted folder. That's it — the console window shows progress and pauses at the end so you can read it. No admin rights, no execution-policy change (per-user HKCU only).
3. Right-click a folder: both `Set Folder Color` submenus (10 colors each) and `Reset Folder Color` are already there.

What `install.cmd` does: runs `Install-FolderColors.ps1 -ClassicMenu` (full right-click menu as default, same as this machine's setup). To install while keeping Windows 11's compact default menu, run the installer without `-ClassicMenu` from PowerShell instead.

### Route B — from a copy of this project (PowerShell)

```powershell
& "<path>\Windows11 Folder Colors\FoldersColors\Install-FolderColors.ps1" -ClassicMenu
```

### Install happens in 3 layers (all reversible)

| Layer | Location | Removed by |
|---|---|---|
| Program files | `%LOCALAPPDATA%\Programs\FolderColors` (runner, worker, icons, ps1 toolkit) | Uninstall-FolderColors.ps1 |
| Menu registry | `HKCU\Software\Classes\Directory\shell\FolderColorMenu1`, `...FolderColorMenu2`, `...FolderColorReset` (+ every legacy key) | Uninstall-FolderColors.ps1 |
| Classic menu toggle | `HKCU\...\CLSID\{86ca1a…34aa…}\InprocServer32` | kept by uninstaller on purpose; remove by hand: `reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f` |

### Uninstall

```powershell
& "%LOCALAPPDATA%\Programs\FolderColors\ps1\Uninstall-FolderColors.ps1"
```

Already-colored folders keep their `desktop.ini` (icons fall back to default since the library is gone). Run `Reset Folder Color` on them first if you want a clean restore.

## 6. Is it actually working? (how to tell)

The runner is silent by design, so verify like this:

1. **Logs are the smoke test** — after using any menu action, open `%LOCALAPPDATA%\Programs\FolderColors\app\Logs\menu-action-<today>.log`. A successful apply looks like:
   `[20:56:22] applied index 3 to C:\Users\you\Somewhere\MyFolder`
2. **desktop.ini exists** — show hidden system files (`Get-Item "<colored folder>\desktop.ini" -Force`) and you should see `IconResource=…` pointing at the installed `icons\` folder.
3. The menu entry itself — right-click a plain folder you never colored. The submenu is there whether or not the folder has a color yet.

## 7. Moving the tool afterwards = re-setup

`desktop.ini` files store **absolute paths** to the icon library. Therefore:

- **Do NOT move, rename, or OneDrive-sync `%LOCALAPPDATA%\Programs\FolderColors`** — that's the location everything points at, and it never moves.
- Moving/renaming the **extracted download folder** (the one with `install.cmd`) after installing is harmless — that copy was just the staging area; the live install lives in `%LOCALAPPDATA%` and the menu doesn't reference the staging copy at all. Still, keeping the extracted copy around is handy for uninstall/repair scripts; just don't rely on it after deleting it.
- If you ever break it anyway (renamed the library, moved the profile, etc.), run the repair script:
  ```powershell
  & "<staging folder>\Repair-FolderColors.ps1" -Apply -Roots @("C:\Users\you")
  ```
  or just reinstall — the installer auto-repairs broken `desktop.ini` files on every run.

## 8. Known behaviors and limitations

- **`desktop.ini` is applied instantly; Explorer is lazy.** Colors can take a few seconds (sometimes ~10) to *appear* — Explorer rebuilds its icon cache on its own schedule. The change itself already happened; clicking inside the folder, pressing F5, or restarting Explorer refreshes immediately. The owner has accepted this as-is (Windows behavior, tool already notifies the shell correctly).
- **Windows caps a static cascading submenu at 16 items.** That is why the colors ship as two submenus of 10 plus a separate reset entry; a single 21-item flyout (v3.1) truncated at 16 and hid White, Yellow, Teal, Space Blue and the rest. Any future additions must respect the same cap — add a third submenu rather than growing one past 16.
- **Right-click order is alphabetical by key.** The `01-…`–`20-…` child-key prefixes are deliberate: they make the flyout list colors in hue order instead of alphabetically. Do not rename them without also fixing the order.
- **One folder at a time** — the right-click verb hands the shortcut a single folder; multi-select is not supported by Explorer's verb mechanism.
- **Folders must be writable** (desktop.ini can be created/updated) — no effect on read-only system folders.
- **McAfee/AV false positives**: unsigned self-built exe → possibly quarantined. Add exclusions for `%LOCALAPPDATA%\Programs\FolderColors` and the staging folder; restore + rebuild once if it grabs the runner.

## 9. Building the runner from source

```cmd
launcher\build.cmd
```

Uses the in-box `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe` (C# 5). Output: `launcher\out\FolderColors.exe` + a payload copy. Rebuild only needed if you change the C# source or the worker script.

## 10. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Submenu missing entirely | Restart Explorer. Then re-run the installer; it logs exactly which keys it writes. |
| Entry only under "Show more options" | The classic-menu toggle isn't set (Windows 11). Re-install with `-ClassicMenu`. |
| Colors never appear at all, even after F5 | Check that `%LOCALAPPDATA%\Programs\FolderColors\icons\Windows_11_coloured_icons.icl` exists; if the folder was moved/rename = see § 7 repair. Check `app\Logs` for what actually ran. |
| "Error in shell32.dll / Missing entry" popup | This comes from running **old** copies that used the removed `SHChangeNotify_RunDLL` rundll32 export. Current installed scripts contain zero `rundll32` invocations (audited). Delete the stale copy and reinstall. |
| The old GUI picker opens | A legacy `FolderColorPicker` registry key survived somewhere. Uninstall, re-run the installer (it deletes that key), restart Explorer. |
| Only 16 of 20 colors show in one long list | Pre-v3.2 install: a single 21-item flyout hits Windows' 16-item cap. Re-run the installer from v3.2+ — it deletes the old `FolderColorMenu` key and writes the two 10-color submenus. |
| Console window flashes on every action | Registry points at `powershell.exe` fallback instead of the runner — that only happens when the runner exe was missing at install time. Reinstall so the runner gets deployed. |

# Windows11-Folder-Colors
This project lets you change the color of any folder in Windows via the right-click menu. It uses registry entries, a PowerShell script, and an icon library to apply colored folder icons with one click. Simple install/uninstall, customizable, and works on Windows 11.

# Folder Colors for Windows
Easily change the color of any folder in Windows via the right-click context menu.  
This project uses **Registry entries** + a **PowerShell script** to set custom folder icons with one click.
Note: The `.icl` file used in this Project is Not Made by me, i only made the codes.
[`.icl` Source](https://www.deviantart.com/abs96/art/Windows-11-coloured-folder-icons-896431403)

## ✨ Features
- Adds a **"Set Folder Color"** option to the right-click menu.
- Choose from multiple predefined colors (Dark Grey, Blue, Red, etc.).
- Works on any folder.
- Uses `.icl` icon library for consistent folder styles.
- Simple **install / uninstall** with `.reg` files.

---

## 📦 Installation

1. Download `FoldersColors.zip`.
2. Place it and Extract it Wherever you want (keep it in the same place forever).
3. copy your `.icl` Path and open `Set-FolderIcon.ps1`, Paste the path in its place (10th line).
4. Open `Install-FolderColors.reg` with Notepad and copy the whole thing then go to [Text Replacer](https://www.browserling.com/tools/text-replace).
5. Paste it There and now there is 3 stuff to replace, firstly replace the phrase `iclPath` with the same path you copied in step 3.
6. Now copy the path of `Set-FolderIcon.ps1` and replace the phrase `ps1Path` with it.
7. Now copy the path of `MenuIcon.ico` and replace the Phrase `MIconPath` with it.
8. Now run `Install-FolderColors.reg` once and now you can just right-click any folder to color it.
9. In case you want to Uninstall it you can just run `Uninstall-FolderColors.reg` once.
10. Note that when changing the Folder Color it takes up to 2 mins to update.
11. Have Fun!!

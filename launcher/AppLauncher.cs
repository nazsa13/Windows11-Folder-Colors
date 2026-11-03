// Folder Colors - hidden context-menu runner.
//
//  FolderColors.exe --run <mode> <folder> [iconIndex]
//
//    mode = "color" -> apply colored icon (index into the .icl library, 0..19)
//    mode = "reset" -> remove desktop.ini, restore the default folder icon
//
// This exe is started ONLY by the right-click menu commands registered by
// Install-FolderColors.ps1. It shows no window of its own; launching it
// directly (double-click, stale shortcut) exits silently. Installing and
// uninstalling is done with the PowerShell scripts in FoldersColors\
// (Install-FolderColors.ps1 / Uninstall-FolderColors.ps1).

using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace FolderColors {
    internal static class Program {
        private static string AppRoot {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "FolderColors"); }
        }

        [STAThread]
        private static int Main(string[] args) {
            // The hidden menu runner is the only supported entry point.
            if (args.Length > 0 && args[0] == "--run") {
                return RunMenuAction(args);
            }

            // Launched directly: do nothing, quietly. There is no installer
            // UI and no picker; the tool lives entirely in the right-click menu.
            return 0;
        }

        // ------------------------------------------------------------------
        // Hidden context-menu runner.
        // ------------------------------------------------------------------
        private static int RunMenuAction(string[] args) {
            try {
                string mode = args.Length > 1 ? args[1] : "";
                string folder = args.Length > 2 ? args[2] : "";
                string extra = args.Length > 3 ? args[3] : "";

                string appDir = Path.Combine(AppRoot, "app");
                string script = Path.Combine(appDir, "Run-MenuAction.ps1");
                if (!File.Exists(script)) {
                    MessageBox.Show("Installation is incomplete: missing " + script,
                        "Folder Colors", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 1;
                }

                string logsDir = Path.Combine(appDir, "Logs");
                Directory.CreateDirectory(logsDir);
                string logFile = Path.Combine(logsDir,
                    "menu-action-" + DateTime.Now.ToString("yyyy-MM-dd") + ".log");

                string quoted = "\"" + script + "\"";
                if (mode.Length > 0) quoted += " -Mode " + mode;
                if (folder.Length > 0) quoted += " -Folder \"" + folder.Trim('"') + "\"";
                if (mode == "color" && extra.Length > 0) quoted += " -IconIndex " + extra;
                quoted += " -LogFile \"" + logFile + "\"";

                var psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + quoted;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                // No stdout/stderr redirection: legacy rundll32 children could keep pipes
                // open forever. The worker logs everything itself.
                using (var p = Process.Start(psi)) {
                    if (!p.WaitForExit(20000)) {
                        p.Kill();
                        File.AppendAllText(logFile,
                            "[" + DateTime.Now.ToString("HH:mm:ss") + "] worker timed out after 20s\r\n");
                        return 1;
                    }
                    return p.ExitCode;
                }
            } catch (Exception ex) {
                try {
                    Directory.CreateDirectory(Path.Combine(AppRoot, "app", "Logs"));
                    File.AppendAllText(Path.Combine(AppRoot, "app", "Logs", "runner-crash.log"),
                        DateTime.Now + "\r\n" + ex + "\r\n");
                } catch { }
                return 1;
            }
        }
    }
}

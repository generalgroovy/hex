using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace Flux.Bootstrap
{
    internal static class Program
    {
        private const string ProductName = "FLUX";
        private const string LauncherFileName = "FLUX.exe";
        private const string PayloadResource = "Flux.Payload.zip";
        private const string PayloadVersion = "__PAYLOAD_VERSION__";
        private const string PayloadSha256 = "__PAYLOAD_SHA256__";
        private const string ManifestSha256 = "__MANIFEST_SHA256__";
        private const string OwnerMarkerName = ".flux-install-root";
        private const string OwnerMarkerValue = "FLUX-INSTALL-ROOT-V1";
        private const long MaximumExpandedBytes = 1024L * 1024L * 1024L;
        private const int MaximumEntries = 10000;
        private const int MaximumManifestBytes = 1024 * 1024;

        [STAThread]
        private static int Main(string[] args)
        {
            BootstrapOptions options = null;
            InstallerWindow window = null;
            string root = null;
            bool selected = false;
            bool quiet = Array.Exists(args, delegate(string value) { return String.Equals(value, "--quiet", StringComparison.OrdinalIgnoreCase); });
            try
            {
                options = BootstrapOptions.Parse(args);
                quiet = options.Quiet;
                root = ResolveInstallRoot(options);
                if (options.PrintInstallRoot)
                {
                    Console.Out.WriteLine("FLUX_INSTALL_ROOT=" + root);
                    return 0;
                }
                bool createdNew;
                using (Mutex mutex = new Mutex(true, "Local\\FLUX-Bootstrap-" + StableName(root), out createdNew))
                {
                    if (!createdNew)
                    {
                        Report(root, quiet, "FLUX is already checking, installing, or starting.", false);
                        return 3;
                    }
                    EnsureOwnedRoot(root, options.InstallRoot != null);
                    if (!quiet)
                    {
                        Application.EnableVisualStyles();
                        Application.SetCompatibleTextRenderingDefault(false);
                        window = new InstallerWindow();
                        window.Show();
                    }
                    SetStatus(window, quiet, "Checking the included build...");
                    string gamePath = InstallOrRepair(root, options, window);
                    CheckCancellation(window);
                    string launcherBackup = null;
                    bool launcherCreated = false;
                    try
                    {
                        SetStatus(window, quiet, "Installing the launcher...");
                        CheckCancellation(window);
                        InstallLauncher(root, out launcherBackup, out launcherCreated);
                        // No cancellation after this point: finish the short pointer transaction.
                        WriteState(root, new DirectoryInfo(Path.GetDirectoryName(gamePath)).Name);
                        selected = true;
                    }
                    catch
                    {
                        RestoreLauncher(root, launcherBackup, launcherCreated);
                        throw;
                    }
                    if (!options.NoShortcuts)
                    {
                        try { CreateShortcuts(root); }
                        catch (Exception error) { Report(root, true, "FLUX is installed; optional shortcuts could not be created: " + error.Message, true); }
                    }
                    if (!options.InstallOnly)
                    {
                        SetStatus(window, quiet, "Starting FLUX...");
                        LaunchGame(gamePath, options.GameArguments);
                    }
                    Report(root, true, "FLUX installed and selected: " + gamePath, false);
                    return 0;
                }
            }
            catch (OperationCanceledException)
            {
                Report(root, true, "Installation cancelled before selection. The previous selection was not changed.", false);
                return 4;
            }
            catch (ArgumentException error)
            {
                string detail = selected ? "FLUX is installed and selected, but its launch arguments failed. " : String.Empty;
                Report(root, quiet, detail + error.Message, true);
                return selected ? 1 : 2;
            }
            catch (Exception error)
            {
                string message = selected
                    ? "FLUX is installed and selected, but could not finish starting. No previous version was automatically selected."
                    : "FLUX could not complete installation. The previous selection was not changed; this does not certify that its files are playable.";
                Report(root, quiet, message + Environment.NewLine + error.Message, true);
                return 1;
            }
            finally
            {
                if (window != null) { window.FinishClose(); window.Dispose(); }
            }
        }

        private static string ResolveInstallRoot(BootstrapOptions options)
        {
            string root;
            if (options.InstallRoot != null)
            {
                if (String.IsNullOrWhiteSpace(options.InstallRoot)) throw new ArgumentException("Install root must not be empty.");
                root = NormalizeDirectory(options.InstallRoot);
            }
            else
            {
                string executable = Assembly.GetExecutingAssembly().Location;
                string ownDirectory = NormalizeDirectory(Path.GetDirectoryName(executable));
                root = String.Equals(Path.GetFileName(executable), LauncherFileName, StringComparison.OrdinalIgnoreCase)
                    && HasOwnerMarker(ownDirectory)
                    ? ownDirectory
                    : NormalizeDirectory(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), ProductName));
            }
            ValidateInstallRoot(root);
            return root;
        }

        private static string NormalizeDirectory(string path)
        {
            string full = Path.GetFullPath(path);
            string drive = Path.GetPathRoot(full);
            return full.Length > drive.Length ? full.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) : full;
        }

        private static void ValidateInstallRoot(string root)
        {
            if (root.StartsWith("\\\\", StringComparison.Ordinal) || String.Equals(root, Path.GetPathRoot(root), StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Choose a dedicated local FLUX folder, not a drive or network root.");
            List<string> broadRoots = new List<string>();
            foreach (Environment.SpecialFolder folder in new[] {
                Environment.SpecialFolder.UserProfile, Environment.SpecialFolder.DesktopDirectory,
                Environment.SpecialFolder.MyDocuments, Environment.SpecialFolder.LocalApplicationData,
                Environment.SpecialFolder.ApplicationData, Environment.SpecialFolder.ProgramFiles,
                Environment.SpecialFolder.ProgramFilesX86, Environment.SpecialFolder.Windows,
                Environment.SpecialFolder.Programs })
            {
                string path = Environment.GetFolderPath(folder);
                if (!String.IsNullOrEmpty(path)) broadRoots.Add(NormalizeDirectory(path));
            }
            broadRoots.Add(NormalizeDirectory(Path.GetTempPath()));
            foreach (string broad in broadRoots)
                if (String.Equals(root, broad, StringComparison.OrdinalIgnoreCase))
                    throw new ArgumentException("Refusing to install directly into a broad user, system, or working directory.");
            if (String.Equals(root, NormalizeDirectory(Directory.GetCurrentDirectory()), StringComparison.OrdinalIgnoreCase) && !HasOwnerMarker(root))
                throw new ArgumentException("Refusing to install into the current working directory unless it is already owned by FLUX.");
            if (Directory.Exists(Path.Combine(root, ".git")) || File.Exists(Path.Combine(root, ".git"))
                || File.Exists(Path.Combine(root, "project.godot")))
                throw new ArgumentException("Refusing to use a source workspace as an installation root.");
            AssertNoReparsePoints(root);
            if (File.Exists(root)) throw new ArgumentException("Install root must be a directory.");
        }

        private static bool HasOwnerMarker(string root)
        {
            string marker = Path.Combine(root, OwnerMarkerName);
            if (!File.Exists(marker)) return false;
            AssertNoReparsePoints(marker);
            return File.Exists(marker) && new FileInfo(marker).Length < 128
                && String.Equals(File.ReadAllText(marker).Trim(), OwnerMarkerValue, StringComparison.Ordinal);
        }

        private static void EnsureOwnedRoot(string root, bool explicitRoot)
        {
            ValidateInstallRoot(root);
            if (HasOwnerMarker(root)) return;
            if (Directory.Exists(root) && Directory.GetFileSystemEntries(root).Length != 0)
            {
                // Earlier installers had no marker. Adopt only a complete bounded
                // FLUX layout at its conventional location or an explicit custom root.
                string conventional = NormalizeDirectory(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), ProductName));
                bool legacy = (explicitRoot || String.Equals(root, conventional, StringComparison.OrdinalIgnoreCase))
                    && IsCompleteLegacyRoot(root);
                if (!legacy) throw new IOException("The destination is nonempty and is not an owned FLUX installation. Choose a new empty folder.");
                AssertNoReparsePoints(Path.Combine(root, "current.txt"));
                AssertNoReparsePoints(Path.Combine(root, "versions"));
            }
            Directory.CreateDirectory(root);
            string marker = Path.Combine(root, OwnerMarkerName);
            AssertNoReparsePoints(marker);
            using (FileStream stream = new FileStream(marker, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (StreamWriter writer = new StreamWriter(stream, new UTF8Encoding(false)))
                writer.WriteLine(OwnerMarkerValue);
        }

        private static bool IsCompleteLegacyRoot(string root)
        {
            HashSet<string> allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
                "versions", "current.txt", "current.backup.txt", "FLUX.exe", "FLUX Launcher.exe", "FLUX Launcher.previous.exe"
            };
            foreach (string child in Directory.GetFileSystemEntries(root))
            {
                AssertNoReparsePoints(child);
                if (!allowed.Contains(Path.GetFileName(child))) return false;
            }
            if (!File.Exists(SafeChild(root, LauncherFileName)) && !File.Exists(SafeChild(root, "FLUX Launcher.exe"))) return false;
            string current = ReadCurrentVersion(root);
            if (current == null) return false;
            string versions = SafeChild(root, "versions");
            if (!Directory.Exists(versions)) return false;
            AssertTreeNoReparsePoints(versions);
            string selected = SafeChild(versions, current);
            foreach (string required in new[] { "flux2.exe", "flux2.pck", "SHA256SUMS.txt" })
                if (!File.Exists(SafeChild(selected, required))) return false;
            return true;
        }

        private static string InstallOrRepair(string root, BootstrapOptions options, InstallerWindow window)
        {
            string versionsRoot = SafeChild(root, "versions");
            AssertNoReparsePoints(versionsRoot);
            Directory.CreateDirectory(versionsRoot);
            string current = ReadCurrentVersion(root);
            // A returning installed launcher honors a verified repair selection
            // instead of repeatedly selecting the original payload directory.
            if (!options.Repair && current != null)
            {
                string selectedDirectory = SafeChild(versionsRoot, current);
                if (VerifyInstall(selectedDirectory)) return Path.Combine(selectedDirectory, "flux2.exe");
            }
            string finalDirectory = SafeChild(versionsRoot, PayloadVersion);
            if (!options.Repair && VerifyInstall(finalDirectory))
                return Path.Combine(finalDirectory, "flux2.exe");

            EnsureNoRunningInstalledGame(root);
            if (options.Repair || Directory.Exists(finalDirectory) || File.Exists(finalDirectory))
                finalDirectory = SafeChild(versionsRoot, PayloadVersion + "-repair-" + Guid.NewGuid().ToString("N"));
            string stagingDirectory = SafeChild(versionsRoot, ".staging-" + Guid.NewGuid().ToString("N"));
            string payloadFile = SafeChild(root, ".payload-" + Guid.NewGuid().ToString("N") + ".zip");
            try
            {
                SetStatus(window, options.Quiet, "Verifying the included build...");
                CheckCancellation(window);
                CopyEmbeddedPayload(payloadFile);
                if (!String.Equals(Sha256(payloadFile), PayloadSha256, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("The included game payload failed its SHA-256 check.");
                SetStatus(window, options.Quiet, "Installing into a new version folder...");
                Directory.CreateDirectory(stagingDirectory);
                ExtractSafely(payloadFile, stagingDirectory, window);
                if (!VerifyInstall(stagingDirectory))
                    throw new InvalidDataException("The extracted game files or authenticated manifest failed verification.");
                CheckCancellation(window);
                AssertNoReparsePoints(stagingDirectory);
                AssertNoReparsePoints(finalDirectory);
                Directory.Move(stagingDirectory, finalDirectory);
                // Immutable versions: never rename, overwrite, or prune an old selection.
                return Path.Combine(finalDirectory, "flux2.exe");
            }
            finally
            {
                TryDeleteOwnedFile(payloadFile);
                if (Directory.Exists(stagingDirectory))
                {
                    try { DeleteDirectorySafely(stagingDirectory, versionsRoot); }
                    catch (Exception error) { Report(root, true, "Staging cleanup deferred: " + error.Message, true); }
                }
            }
        }

        private static void EnsureNoRunningInstalledGame(string root)
        {
            string prefix = root + Path.DirectorySeparatorChar;
            foreach (Process process in Process.GetProcessesByName("flux2"))
            {
                using (process)
                {
                    string path;
                    try { path = Path.GetFullPath(process.MainModule.FileName); }
                    catch (System.ComponentModel.Win32Exception) { continue; }
                    catch (InvalidOperationException) { continue; }
                    if (path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                        throw new IOException("Close the installed FLUX game normally before updating or repairing it. No running process was stopped.");
                }
            }
        }

        private static void CopyEmbeddedPayload(string destination)
        {
            AssertNoReparsePoints(destination);
            using (Stream source = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResource))
            {
                if (source == null) throw new InvalidDataException("The installer does not contain a FLUX payload.");
                using (FileStream target = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                    source.CopyTo(target);
            }
        }

        private static void ExtractSafely(string archivePath, string destination, InstallerWindow window)
        {
            long expandedBytes = 0;
            int entries = 0;
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using (ZipArchive archive = ZipFile.OpenRead(archivePath))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    CheckCancellation(window);
                    entries++;
                    if (entry.Length < 0 || entry.Length > MaximumExpandedBytes - expandedBytes || entries > MaximumEntries)
                        throw new InvalidDataException("The game payload exceeds its safe extraction limits.");
                    expandedBytes += entry.Length;
                    string relative = entry.FullName.TrimEnd('/', '\\');
                    string output = SafeRelativeFile(destination, relative);
                    if (!seen.Add(output)) throw new InvalidDataException("The game payload contains duplicate paths.");
                    AssertNoReparsePoints(output);
                    if (String.IsNullOrEmpty(entry.Name)) { Directory.CreateDirectory(output); continue; }
                    Directory.CreateDirectory(Path.GetDirectoryName(output));
                    AssertNoReparsePoints(output);
                    using (Stream input = entry.Open())
                    using (FileStream outputStream = new FileStream(output, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                        input.CopyTo(outputStream);
                }
            }
        }

        private static bool VerifyInstall(string directory)
        {
            try
            {
                AssertNoReparsePoints(directory);
                string manifest = SafeChild(directory, "SHA256SUMS.txt");
                AssertNoReparsePoints(manifest);
                if (!File.Exists(manifest) || new FileInfo(manifest).Length == 0 || new FileInfo(manifest).Length > MaximumManifestBytes)
                    return false;
                if (!IsSha256(ManifestSha256) || !String.Equals(Sha256(manifest), ManifestSha256, StringComparison.OrdinalIgnoreCase))
                    return false;
                HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                int entries = 0;
                foreach (string rawLine in File.ReadAllLines(manifest))
                {
                    if (String.IsNullOrWhiteSpace(rawLine)) continue;
                    if (++entries > MaximumEntries || rawLine.Length < 67 || !IsSha256(rawLine.Substring(0, 64))
                        || rawLine[64] != ' ' || (rawLine[65] != ' ' && rawLine[65] != '*')) return false;
                    string relative = rawLine.Substring(66);
                    string file = SafeRelativeFile(directory, relative);
                    if (!seen.Add(file) || !File.Exists(file)) return false;
                    AssertNoReparsePoints(file);
                    if (!String.Equals(Sha256(file), rawLine.Substring(0, 64), StringComparison.OrdinalIgnoreCase)) return false;
                }
                foreach (string required in new[] { "flux2.exe", "flux2.pck", "BUILD-STATE.json" })
                    if (!seen.Contains(SafeChild(directory, required))) return false;
                return entries >= 3;
            }
            catch (Exception) { return false; }
        }

        private static bool IsSha256(string value)
        {
            if (value == null || value.Length != 64) return false;
            foreach (char c in value)
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return false;
            return true;
        }

        private static string SafeRelativeFile(string parent, string relative)
        {
            if (String.IsNullOrEmpty(relative) || Path.IsPathRooted(relative) || relative.IndexOf(':') >= 0)
                throw new InvalidDataException("The payload contains an unsafe relative path.");
            string normalized = relative.Replace('/', Path.DirectorySeparatorChar);
            foreach (string part in normalized.Split(Path.DirectorySeparatorChar))
            {
                if (part.Length == 0 || part == "." || part == ".." || part.EndsWith(".", StringComparison.Ordinal)
                    || part.EndsWith(" ", StringComparison.Ordinal) || part.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
                    throw new InvalidDataException("The payload contains an ambiguous Windows path.");
                string stem = part.Split('.')[0].ToUpperInvariant();
                if (stem == "CON" || stem == "PRN" || stem == "AUX" || stem == "NUL"
                    || (stem.Length == 4 && (stem.StartsWith("COM", StringComparison.Ordinal) || stem.StartsWith("LPT", StringComparison.Ordinal))
                    && stem[3] >= '1' && stem[3] <= '9'))
                    throw new InvalidDataException("The payload contains a reserved Windows device path.");
            }
            return SafeChild(parent, normalized);
        }

        private static string Sha256(string path)
        {
            AssertNoReparsePoints(path);
            using (SHA256 hash = SHA256.Create())
            using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                StringBuilder text = new StringBuilder(64);
                foreach (byte value in hash.ComputeHash(stream)) text.Append(value.ToString("x2", CultureInfo.InvariantCulture));
                return text.ToString();
            }
        }

        private static void WriteState(string root, string currentVersion)
        {
            if (SafeVersion(currentVersion) == null) throw new InvalidDataException("Invalid selected version.");
            string state = SafeChild(root, "current.txt");
            AssertNoReparsePoints(state);
            string previous = ReadCurrentVersion(root);
            if (String.Equals(previous, currentVersion, StringComparison.OrdinalIgnoreCase)) previous = ReadPreviousVersion(root);
            string temporary = SafeChild(root, ".current-" + Guid.NewGuid().ToString("N") + ".tmp");
            try
            {
                File.WriteAllLines(temporary, new[] { currentVersion, previous ?? String.Empty }, new UTF8Encoding(false));
                if (File.Exists(state))
                {
                    string backup = SafeChild(root, "current.backup.txt");
                    AssertNoReparsePoints(backup);
                    File.Replace(temporary, state, backup, true);
                }
                else File.Move(temporary, state);
            }
            finally { TryDeleteOwnedFile(temporary); }
        }

        private static string ReadCurrentVersion(string root) { return ReadStateVersion(root, 0); }
        private static string ReadPreviousVersion(string root) { return ReadStateVersion(root, 1); }

        private static string ReadStateVersion(string root, int index)
        {
            string state = SafeChild(root, "current.txt");
            AssertNoReparsePoints(state);
            if (!File.Exists(state)) return null;
            if (new FileInfo(state).Length > 4096) throw new InvalidDataException("Installed version state is oversized.");
            string[] lines = File.ReadAllLines(state);
            return lines.Length > index ? SafeVersion(lines[index]) : null;
        }

        private static string SafeVersion(string value)
        {
            if (String.IsNullOrEmpty(value) || value.Length > 160 || value.StartsWith(".", StringComparison.Ordinal)) return null;
            foreach (char c in value)
                if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_')) return null;
            return value;
        }

        private static void InstallLauncher(string root, out string backup, out bool created)
        {
            backup = null;
            created = false;
            string launcher = SafeChild(root, LauncherFileName);
            string currentExecutable = Assembly.GetExecutingAssembly().Location;
            AssertNoReparsePoints(launcher);
            if (String.Equals(Path.GetFullPath(currentExecutable), launcher, StringComparison.OrdinalIgnoreCase)) return;
            string temporary = SafeChild(root, ".launcher-" + Guid.NewGuid().ToString("N") + ".exe");
            try
            {
                File.Copy(currentExecutable, temporary, false);
                if (File.Exists(launcher))
                {
                    backup = SafeChild(root, ".launcher-backup-" + Guid.NewGuid().ToString("N") + ".exe");
                    File.Replace(temporary, launcher, backup, true);
                }
                else { File.Move(temporary, launcher); created = true; }
            }
            finally { TryDeleteOwnedFile(temporary); }
        }

        private static void RestoreLauncher(string root, string backup, bool created)
        {
            string launcher = SafeChild(root, LauncherFileName);
            AssertNoReparsePoints(launcher);
            if (backup != null && File.Exists(backup))
            {
                AssertNoReparsePoints(backup);
                File.Replace(backup, launcher, SafeChild(root, ".launcher-unselected-" + Guid.NewGuid().ToString("N") + ".exe"), true);
            }
            else if (created) TryDeleteOwnedFile(launcher);
        }

        private static void CreateShortcuts(string root)
        {
            string launcher = SafeChild(root, LauncherFileName);
            string startMenu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), ProductName);
            AssertNoReparsePoints(startMenu);
            Directory.CreateDirectory(startMenu);
            CreateShortcut(Path.Combine(startMenu, "FLUX.lnk"), launcher, root);
            string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            if (!String.IsNullOrEmpty(desktop)) CreateShortcut(Path.Combine(desktop, "FLUX.lnk"), launcher, root);
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string workingDirectory)
        {
            AssertNoReparsePoints(shortcutPath);
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null) throw new IOException("Windows shortcut service is unavailable.");
            object shell = Activator.CreateInstance(shellType);
            object shortcut = null;
            try
            {
                shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath }, CultureInfo.InvariantCulture);
                Type type = shortcut.GetType();
                type.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetPath }, CultureInfo.InvariantCulture);
                type.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { JoinArguments(new[] { "--install-root=" + workingDirectory }) }, CultureInfo.InvariantCulture);
                type.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { workingDirectory }, CultureInfo.InvariantCulture);
                type.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { "Play FLUX; run a newer FLUX.exe to update offline" }, CultureInfo.InvariantCulture);
                type.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null, CultureInfo.InvariantCulture);
            }
            finally
            {
                if (shortcut != null && System.Runtime.InteropServices.Marshal.IsComObject(shortcut)) System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shortcut);
                if (System.Runtime.InteropServices.Marshal.IsComObject(shell)) System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
            }
        }

        private static void LaunchGame(string gamePath, string[] gameArguments)
        {
            AssertNoReparsePoints(gamePath);
            if (!File.Exists(gamePath)) throw new FileNotFoundException("The installed FLUX game is missing.", gamePath);
            ProcessStartInfo start = new ProcessStartInfo();
            start.FileName = gamePath;
            start.WorkingDirectory = Path.GetDirectoryName(gamePath);
            start.UseShellExecute = false;
            start.Arguments = JoinArguments(gameArguments);
            using (Process launched = Process.Start(start))
                if (launched == null) throw new IOException("Windows did not create the FLUX process.");
        }

        private static string JoinArguments(string[] arguments)
        {
            if (arguments == null || arguments.Length == 0) return String.Empty;
            List<string> quoted = new List<string>();
            foreach (string argument in arguments)
            {
                StringBuilder item = new StringBuilder("\"");
                int slashes = 0;
                foreach (char c in argument ?? String.Empty)
                {
                    if (c == '\\') { slashes++; continue; }
                    if (c == '"') { item.Append('\\', slashes * 2 + 1); item.Append('"'); }
                    else { item.Append('\\', slashes); item.Append(c); }
                    slashes = 0;
                }
                item.Append('\\', slashes * 2);
                item.Append('"');
                quoted.Add(item.ToString());
            }
            return String.Join(" ", quoted.ToArray());
        }

        private static string SafeChild(string parent, string child)
        {
            string root = NormalizeDirectory(parent) + Path.DirectorySeparatorChar;
            string result = Path.GetFullPath(Path.Combine(root, child));
            if (!result.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Refusing a path outside the dedicated FLUX folder.");
            AssertNoReparsePoints(result);
            return result;
        }

        private static void AssertNoReparsePoints(string path)
        {
            string current = Path.GetFullPath(path);
            while (!String.IsNullOrEmpty(current))
            {
                try
                {
                    if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                        throw new IOException("Refusing an install path containing a reparse point: " + current);
                }
                catch (FileNotFoundException) { }
                catch (DirectoryNotFoundException) { }
                string parent = Path.GetDirectoryName(current);
                if (String.Equals(parent, current, StringComparison.OrdinalIgnoreCase)) break;
                current = parent;
            }
        }

        private static void AssertTreeNoReparsePoints(string directory)
        {
            AssertNoReparsePoints(directory);
            foreach (string child in Directory.GetFileSystemEntries(directory))
            {
                AssertNoReparsePoints(child);
                if (Directory.Exists(child)) AssertTreeNoReparsePoints(child);
            }
        }

        private static void DeleteDirectorySafely(string path, string parent)
        {
            string safe = SafeChild(parent, Path.GetFileName(NormalizeDirectory(path)));
            if (!String.Equals(safe, NormalizeDirectory(path), StringComparison.OrdinalIgnoreCase)
                || !Path.GetFileName(safe).StartsWith(".staging-", StringComparison.Ordinal))
                throw new InvalidOperationException("Refusing to remove a non-staging directory.");
            AssertTreeNoReparsePoints(safe);
            Directory.Delete(safe, true);
        }

        private static void TryDeleteOwnedFile(string path)
        {
            try { AssertNoReparsePoints(path); if (File.Exists(path)) File.Delete(path); }
            catch { /* Only attempt cleanup of the specific temporary file; preserve on failure. */ }
        }

        private static string StableName(string value)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(NormalizeDirectory(value).ToUpperInvariant());
            using (SHA256 hash = SHA256.Create())
                return Convert.ToBase64String(hash.ComputeHash(bytes)).Replace('/', '_').Replace('+', '-').TrimEnd('=');
        }

        private static void CheckCancellation(InstallerWindow window)
        {
            if (window == null) return;
            Application.DoEvents();
            if (window.CancelRequested) throw new OperationCanceledException();
        }

        private static void SetStatus(InstallerWindow window, bool quiet, string text)
        {
            if (quiet) Console.Out.WriteLine(text);
            if (window != null) window.SetStatus(text);
        }

        private static void Report(string root, bool quiet, string message, bool error)
        {
            if (error) Console.Error.WriteLine(message); else Console.Out.WriteLine(message);
            try
            {
                if (root != null && HasOwnerMarker(root))
                {
                    string log = SafeChild(root, "bootstrap.log");
                    File.AppendAllText(log, DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture) + " " + message + Environment.NewLine, new UTF8Encoding(false));
                }
            }
            catch { /* Diagnostics must not replace the original failure. */ }
            if (!quiet) MessageBox.Show(message, ProductName, MessageBoxButtons.OK, error ? MessageBoxIcon.Error : MessageBoxIcon.Information);
        }

        private sealed class BootstrapOptions
        {
            public bool InstallOnly;
            public bool NoShortcuts;
            public bool Repair;
            public bool Quiet;
            public bool PrintInstallRoot;
            public string InstallRoot;
            public string[] GameArguments = new string[0];

            public static BootstrapOptions Parse(string[] args)
            {
                BootstrapOptions options = new BootstrapOptions();
                List<string> gameArgs = new List<string>();
                bool passthrough = false;
                foreach (string argument in args)
                {
                    if (passthrough) { gameArgs.Add(argument); continue; }
                    if (argument == "--") { passthrough = true; continue; }
                    if (String.Equals(argument, "--install-only", StringComparison.OrdinalIgnoreCase)) options.InstallOnly = true;
                    else if (String.Equals(argument, "--no-shortcuts", StringComparison.OrdinalIgnoreCase)) options.NoShortcuts = true;
                    else if (String.Equals(argument, "--repair", StringComparison.OrdinalIgnoreCase)) options.Repair = true;
                    else if (String.Equals(argument, "--quiet", StringComparison.OrdinalIgnoreCase)) options.Quiet = true;
                    else if (String.Equals(argument, "--print-install-root", StringComparison.OrdinalIgnoreCase)) options.PrintInstallRoot = true;
                    else if (argument.StartsWith("--install-root=", StringComparison.OrdinalIgnoreCase))
                        options.InstallRoot = argument.Substring("--install-root=".Length);
                    else throw new ArgumentException("Unknown setup option: " + argument);
                }
                options.GameArguments = gameArgs.ToArray();
                return options;
            }
        }

        private sealed class InstallerWindow : Form
        {
            private readonly Label status;
            private bool allowClose;
            public bool CancelRequested { get; private set; }

            public InstallerWindow()
            {
                Text = ProductName;
                ClientSize = new Size(420, 132);
                FormBorderStyle = FormBorderStyle.FixedDialog;
                MaximizeBox = false;
                MinimizeBox = false;
                StartPosition = FormStartPosition.CenterScreen;
                BackColor = Color.FromArgb(22, 27, 36);
                ForeColor = Color.FromArgb(235, 222, 180);
                UseWaitCursor = true;
                Label title = new Label();
                title.Text = ProductName;
                title.Font = new Font("Segoe UI", 22F, FontStyle.Bold);
                title.AutoSize = true;
                title.Location = new Point(24, 18);
                title.ForeColor = Color.FromArgb(105, 213, 224);
                Controls.Add(title);
                status = new Label();
                status.Text = "Preparing...";
                status.Font = new Font("Segoe UI", 10F, FontStyle.Regular);
                status.Location = new Point(27, 76);
                status.Size = new Size(365, 32);
                Controls.Add(status);
                FormClosing += delegate(object sender, FormClosingEventArgs e)
                {
                    if (!allowClose) { CancelRequested = true; e.Cancel = true; status.Text = "Cancelling before selection..."; }
                };
            }

            public void SetStatus(string text) { status.Text = text; status.Refresh(); Refresh(); Application.DoEvents(); }
            public void FinishClose() { allowClose = true; Close(); }
        }
    }
}

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

namespace Hex.Bootstrap
{
    internal static class Program
    {
        private const string ProductName = "H.E.X.";
        private const string InstallFolderName = "HEX";
        private static readonly string[] DefaultGameArguments = new[] { __DEFAULT_GAME_ARGUMENTS__ };
        private const string StateFileName = "selection.dat";
        private static readonly byte[] StateEntropy = Encoding.UTF8.GetBytes("HEX-SELECTION-V1");
        private const string LauncherFileName = "HEX.exe";
        private const string PayloadResource = "Hex.Payload.zip";
        private const string PayloadVersion = "__PAYLOAD_VERSION__";
        private const string PayloadSha256 = "__PAYLOAD_SHA256__";
        private const string ManifestSha256 = "__MANIFEST_SHA256__";
        private const string OwnerMarkerName = ".hex-install-root";
        private const string OwnerMarkerValue = "HEX-INSTALL-ROOT-V1";
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
            bool quiet = Array.Exists(args, delegate(string value) { return value == "--quiet"; });
            try
            {
                options = BootstrapOptions.Parse(args);
                quiet = options.Quiet;
                root = ResolveInstallRoot(options);
                if (options.PrintInstallRoot)
                {
                    Console.Out.WriteLine("HEX_INSTALL_ROOT=" + root);
                    return 0;
                }
                if (!quiet && !options.InstallOnly && !options.Previous)
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    using (LaunchWindow menu = new LaunchWindow(root))
                    {
                        if (menu.ShowDialog() != DialogResult.OK) return 4;
                        options.Previous = menu.Previous;
                    }
                }
                bool createdNew;
                using (Mutex mutex = new Mutex(true, "Local\\HEX-Bootstrap-" + StableName(root), out createdNew))
                {
                    if (!createdNew) throw new IOException("H.E.X. is already checking, installing, or starting.");
                    EnsureOwnedRoot(root, options.InstallRoot != null);
                    EnsureNoRunningInstalledGame(root);
                    if (!quiet)
                    {
                        window = new InstallerWindow();
                        window.Show();
                    }
                    Selection old = ReadSelection(root, false);
                    Selection chosen;
                    string gamePath;
                    if (options.Previous)
                    {
                        chosen = ReadSelection(root, true);
                        if (chosen == null) throw new IOException("There is no retained previous build to select.");
                        string directory = SafeChild(SafeChild(root, "versions"), chosen.Version);
                        if (!VerifyInstall(directory, chosen.ManifestHash))
                            throw new InvalidDataException("The previous build failed verification. Nothing was selected.");
                        gamePath = SafeChild(directory, "hex.exe");
                    }
                    else
                    {
                        SetStatus(window, quiet, "Checking the included build...");
                        gamePath = InstallOrRepair(root, options, window);
                        string version = new DirectoryInfo(Path.GetDirectoryName(gamePath)).Name;
                        chosen = old != null && old.Version == version
                            ? old : new Selection(version, ManifestSha256, DefaultGameArguments);
                    }
                    CheckCancellation(window);
                    string launcherBackup = null;
                    bool launcherCreated = false;
                    try
                    {
                        if (!options.Previous) InstallLauncher(root, out launcherBackup, out launcherCreated);
                        // The protected selection is the only authority; replace it atomically.
                        WriteState(root, chosen);
                        selected = true;
                    }
                    catch
                    {
                        if (!options.Previous) RestoreLauncher(root, launcherBackup, launcherCreated);
                        throw;
                    }
                    if (!options.NoShortcuts)
                    {
                        try { CreateShortcuts(root); }
                        catch (Exception error) { Report(root, true, "Installed; optional shortcuts could not be created: " + error.Message, true); }
                    }
                    if (!options.InstallOnly)
                    {
                        SetStatus(window, quiet, "Starting H.E.X...");
                        List<string> launchArguments = new List<string>();
                        if (options.EngineArguments) launchArguments.AddRange(options.GameArguments);
                        else
                        {
                            launchArguments.Add("--");
                            launchArguments.AddRange(chosen.Arguments);
                            launchArguments.AddRange(options.GameArguments);
                        }
                        LaunchGame(gamePath, launchArguments.ToArray());
                    }
                    Report(root, true, "HEX_SELECTED=" + gamePath, false);
                    return 0;
                }
            }
            catch (OperationCanceledException)
            {
                Report(root, true, "Cancelled before selection. The previous selection was not changed.", false);
                return 4;
            }
            catch (ArgumentException error)
            {
                Report(root, quiet, error.Message, true);
                return 2;
            }
            catch (Exception error)
            {
                Report(root, quiet, (selected ? "The build is selected, but starting failed. " :
                    "No replacement build was selected. ") + error.Message, true);
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
                    : NormalizeDirectory(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), InstallFolderName));
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
                throw new ArgumentException("Choose a dedicated local HEX folder, not a drive or network root.");
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
                throw new ArgumentException("Refusing to install into the current working directory unless it is already owned by HEX.");
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
                throw new IOException("The destination is nonempty and is not an owned H.E.X. installation. Choose a new empty folder.");
            }
            Directory.CreateDirectory(root);
            string marker = Path.Combine(root, OwnerMarkerName);
            AssertNoReparsePoints(marker);
            using (FileStream stream = new FileStream(marker, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (StreamWriter writer = new StreamWriter(stream, new UTF8Encoding(false)))
                writer.WriteLine(OwnerMarkerValue);
        }

        private static string InstallOrRepair(string root, BootstrapOptions options, InstallerWindow window)
        {
            string versionsRoot = SafeChild(root, "versions");
            AssertNoReparsePoints(versionsRoot);
            Directory.CreateDirectory(versionsRoot);
            Selection current = ReadSelection(root, false);
            bool storedLauncher = String.Equals(Path.GetFullPath(Assembly.GetExecutingAssembly().Location),
                SafeChild(root, LauncherFileName), StringComparison.OrdinalIgnoreCase);
            if (!options.Repair && current != null && (storedLauncher || current.ManifestHash == ManifestSha256))
            {
                string selectedDirectory = SafeChild(versionsRoot, current.Version);
                if (VerifyInstall(selectedDirectory, current.ManifestHash)) return Path.Combine(selectedDirectory, "hex.exe");
            }
            string finalDirectory = SafeChild(versionsRoot, PayloadVersion);
            if (!options.Repair && VerifyInstall(finalDirectory))
                return Path.Combine(finalDirectory, "hex.exe");

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
                return Path.Combine(finalDirectory, "hex.exe");
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
            string prefix = SafeChild(root, "versions") + Path.DirectorySeparatorChar;
            foreach (Process process in Process.GetProcessesByName("hex"))
            {
                using (process)
                {
                    string path;
                    try { path = Path.GetFullPath(process.MainModule.FileName); }
                    catch (System.ComponentModel.Win32Exception) { continue; }
                    catch (InvalidOperationException) { continue; }
                    if (path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                        throw new IOException("Close the installed HEX game normally before updating or repairing it. No running process was stopped.");
                }
            }
        }

        private static void CopyEmbeddedPayload(string destination)
        {
            AssertNoReparsePoints(destination);
            using (Stream source = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResource))
            {
                if (source == null) throw new InvalidDataException("The installer does not contain a HEX payload.");
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

        private static bool VerifyInstall(string directory) { return VerifyInstall(directory, ManifestSha256); }

        private static bool VerifyInstall(string directory, string manifestHash)
        {
            try
            {
                AssertNoReparsePoints(directory);
                string manifest = SafeChild(directory, "SHA256SUMS.txt");
                AssertNoReparsePoints(manifest);
                if (!File.Exists(manifest) || new FileInfo(manifest).Length == 0 || new FileInfo(manifest).Length > MaximumManifestBytes)
                    return false;
                if (!IsSha256(manifestHash) || !String.Equals(Sha256(manifest), manifestHash, StringComparison.OrdinalIgnoreCase))
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
                foreach (string required in new[] { "hex.exe", "hex.pck", "BUILD-STATE.json" })
                    if (!seen.Contains(SafeChild(directory, required))) return false;
                // Unexpected adjacent DLLs/executables must not become a launch path.
                AssertTreeNoReparsePoints(directory);
                foreach (string file in Directory.GetFiles(directory, "*", SearchOption.AllDirectories))
                    if (!String.Equals(file, manifest, StringComparison.OrdinalIgnoreCase) && !seen.Contains(file)) return false;
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

        private sealed class Selection
        {
            public readonly string Version;
            public readonly string ManifestHash;
            public readonly string[] Arguments;
            public Selection(string version, string manifestHash, string[] arguments)
            {
                if (SafeVersion(version) == null || !IsSha256(manifestHash))
                    throw new InvalidDataException("Invalid build selection.");
                foreach (string argument in arguments)
                    if (argument != "--fullbody-art" && argument != "--pixel-cast" && argument != "--pixel-body-pilot")
                        throw new InvalidDataException("Unsupported presentation argument.");
                Version = version; ManifestHash = manifestHash; Arguments = arguments;
            }
            public string Encode() { return Version + "|" + ManifestHash + "|" + String.Join(",", Arguments); }
            public static Selection Decode(string value)
            {
                if (String.IsNullOrEmpty(value)) return null;
                string[] parts = value.Split('|');
                if (parts.Length != 3) throw new InvalidDataException("Malformed build selection.");
                return new Selection(parts[0], parts[1], parts[2].Length == 0 ? new string[0] : parts[2].Split(','));
            }
        }

        private static Selection ReadSelection(string root, bool previous)
        {
            string state = SafeChild(root, StateFileName);
            if (!File.Exists(state)) return null;
            if (new FileInfo(state).Length > 16384) throw new InvalidDataException("Installed selection is oversized.");
            byte[] plaintext = ProtectedData.Unprotect(File.ReadAllBytes(state), StateEntropy, DataProtectionScope.CurrentUser);
            string[] lines = Encoding.UTF8.GetString(plaintext).Split('\n');
            if (lines.Length != 3 || lines[0] != "HEX-SELECTION-V1")
                throw new InvalidDataException("Installed selection is malformed.");
            return Selection.Decode(lines[previous ? 2 : 1]);
        }

        private static void WriteState(string root, Selection selected)
        {
            Selection old = ReadSelection(root, false);
            Selection previous = old != null && old.Version != selected.Version ? old : ReadSelection(root, true);
            string content = "HEX-SELECTION-V1\n" + selected.Encode() + "\n" + (previous == null ? "" : previous.Encode());
            byte[] data = ProtectedData.Protect(Encoding.UTF8.GetBytes(content), StateEntropy, DataProtectionScope.CurrentUser);
            string state = SafeChild(root, StateFileName);
            string temporary = SafeChild(root, ".selection-" + Guid.NewGuid().ToString("N") + ".tmp");
            try
            {
                using (FileStream file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                { file.Write(data, 0, data.Length); file.Flush(true); }
                if (File.Exists(state)) File.Replace(temporary, state, SafeChild(root, "selection.backup.dat"), true);
                else File.Move(temporary, state);
            }
            finally { TryDeleteOwnedFile(temporary); }
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
            string startMenu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), InstallFolderName);
            AssertNoReparsePoints(startMenu);
            Directory.CreateDirectory(startMenu);
            CreateShortcut(Path.Combine(startMenu, "H.E.X.lnk"), launcher, root);
            string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            if (!String.IsNullOrEmpty(desktop)) CreateShortcut(Path.Combine(desktop, "H.E.X.lnk"), launcher, root);
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
                type.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { "Play H.E.X.; run a trusted newer HEX-Setup to update offline" }, CultureInfo.InvariantCulture);
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
            if (!File.Exists(gamePath)) throw new FileNotFoundException("The installed HEX game is missing.", gamePath);
            ProcessStartInfo start = new ProcessStartInfo();
            start.FileName = gamePath;
            start.WorkingDirectory = Path.GetDirectoryName(gamePath);
            start.UseShellExecute = false;
            start.Arguments = JoinArguments(gameArguments);
            using (Process launched = Process.Start(start))
                if (launched == null) throw new IOException("Windows did not create the HEX process.");
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
                throw new InvalidOperationException("Refusing a path outside the dedicated HEX folder.");
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
            public bool Previous;
            public bool EngineArguments;
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
                    else if (argument == "--previous") options.Previous = true;
                    else if (argument == "--engine-args") options.EngineArguments = true;
                    else if (String.Equals(argument, "--quiet", StringComparison.OrdinalIgnoreCase)) options.Quiet = true;
                    else if (String.Equals(argument, "--print-install-root", StringComparison.OrdinalIgnoreCase)) options.PrintInstallRoot = true;
                    else if (argument.StartsWith("--install-root=", StringComparison.OrdinalIgnoreCase))
                        options.InstallRoot = argument.Substring("--install-root=".Length);
                    else throw new ArgumentException("Unknown setup option: " + argument);
                }
                if (options.Previous && options.Repair) throw new ArgumentException("Previous and repair cannot be combined.");
                options.GameArguments = gameArgs.ToArray();
                return options;
            }
        }

        private sealed class LaunchWindow : Form
        {
            public bool Previous { get; private set; }
            private static string DisplayBuildId(string version)
            {
                int first = version.IndexOf('-');
                int second = first < 0 ? -1 : version.IndexOf('-', first + 1);
                return second < 0 ? version : version.Substring(0, second);
            }
            public LaunchWindow(string root)
            {
                Text = Program.ProductName;
                ClientSize = new Size(480, 272);
                FormBorderStyle = FormBorderStyle.FixedDialog;
                MaximizeBox = false;
                StartPosition = FormStartPosition.CenterScreen;
                Font = new Font("Segoe UI", 10F);
                BackColor = Color.FromArgb(22, 27, 36);
                ForeColor = Color.FromArgb(235, 232, 223);
                Label title = new Label { Text = "H.E.X.", Font = new Font("Segoe UI", 25F, FontStyle.Bold),
                    ForeColor = Color.FromArgb(105, 213, 224), Location = new Point(24, 18), AutoSize = true };
                Controls.Add(title);
                Selection current = HasOwnerMarker(root) ? ReadSelection(root, false) : null;
                Selection previous = HasOwnerMarker(root) ? ReadSelection(root, true) : null;
                bool externalUpdate = current != null && current.ManifestHash != ManifestSha256 &&
                    !String.Equals(Path.GetFullPath(Assembly.GetExecutingAssembly().Location), SafeChild(root, LauncherFileName), StringComparison.OrdinalIgnoreCase);
                Controls.Add(new Label { Text = externalUpdate ? "Included update: " + DisplayBuildId(PayloadVersion) : current == null ? "Install the included build, then play." :
                    "Selected build: " + DisplayBuildId(current.Version), Location = new Point(27, 80), Size = new Size(426, 40) });
                Button play = new Button { Text = externalUpdate ? "Update and play" : current == null ? "Install and play" : "Play", Location = new Point(27, 130),
                    Size = new Size(426, 44), BackColor = Color.FromArgb(105, 213, 224), ForeColor = Color.Black, FlatStyle = FlatStyle.Flat };
                play.Click += delegate { DialogResult = DialogResult.OK; Close(); };
                Controls.Add(play);
                AcceptButton = play;
                Button update = new Button { Text = "Get updates...", Location = new Point(27, 186), Size = new Size(207, 34),
                    BackColor = Color.FromArgb(52, 62, 77), FlatStyle = FlatStyle.Flat };
                update.Click += delegate {
                    if (MessageBox.Show("Automatic updates are not configured. Open the project's fixed GitHub Releases page? It may not have a public installer yet.\n\nWhen a newer HEX-Setup is available, download it, close H.E.X., and run it yourself. Only run files whose source you trust. Windows security checks remain enabled.\n\nOffline updates retain the previous build and keep your saved settings.",
                        "H.E.X. manual updates", MessageBoxButtons.OKCancel, MessageBoxIcon.Information) == DialogResult.OK)
                    {
                        try { Process.Start(new ProcessStartInfo("https://github.com/generalgroovy/hex/releases") { UseShellExecute = true }); }
                        catch (Exception error) { MessageBox.Show("The browser could not open. Visit github.com/generalgroovy/hex/releases manually.\n\n" + error.Message, Program.ProductName); }
                    }
                };
                Controls.Add(update);
                Button rollback = new Button { Text = "Previous build", Enabled = previous != null,
                    Location = new Point(246, 186), Size = new Size(207, 34), BackColor = Color.FromArgb(52, 62, 77), FlatStyle = FlatStyle.Flat };
                rollback.Click += delegate {
                    if (MessageBox.Show("Switch to the retained, verified previous build? Your saved settings will not be removed.",
                        "H.E.X.", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes)
                    { Previous = true; DialogResult = DialogResult.OK; Close(); }
                };
                Controls.Add(rollback);
                Controls.Add(new Label { Text = "Local playtest  |  No online update feed", Location = new Point(27, 235),
                    Size = new Size(426, 22), ForeColor = Color.FromArgb(172, 180, 191) });
            }
        }

        private sealed class InstallerWindow : Form
        {
            private readonly Label status;
            private bool allowClose;
            public bool CancelRequested { get; private set; }

            public InstallerWindow()
            {
                Text = Program.ProductName;
                ClientSize = new Size(420, 132);
                FormBorderStyle = FormBorderStyle.FixedDialog;
                MaximizeBox = false;
                MinimizeBox = false;
                StartPosition = FormStartPosition.CenterScreen;
                BackColor = Color.FromArgb(22, 27, 36);
                ForeColor = Color.FromArgb(235, 222, 180);
                UseWaitCursor = true;
                Label title = new Label();
                title.Text = Program.ProductName;
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

H.E.X. WINDOWS DELIVERY

FOR PLAYERS
Run the HEX-Setup-<build>.exe received directly from the developer. The window
offers Install and play; later the installed H.E.X. shortcut offers Play.
The complete game is included. Installation does not need a download or an
administrator prompt. The installation lives in %LOCALAPPDATA%\HEX.

Updates are currently OFFLINE. Get the newer setup file from the developer,
close the game, and run the newer setup. Its Update and play action verifies
and stages the included package before switching builds. The Update button in
the installed launcher explains this process and can open only the fixed
https://github.com/generalgroovy/hex/releases page in your browser. That page
may not have a public installer yet; there is no online update feed. The
launcher never downloads or runs an arbitrary selected update executable.

Previous build selects the retained prior build only after checking its
protected checksum record and every packaged file. A subsequent Play honors
that selection. Switching again returns to the other retained build. If a
prior build was damaged, rollback refuses it instead of launching unchecked
files. Keep the trusted setup file in case you need to reinstall or repair.

Saved controls and personal weaves remain in the existing Godot user profile
(%APPDATA%\Godot\app_userdata\FLUX 2); this delivery tool does not delete or
rewrite those saves. It never prunes prior version folders automatically.
Different game versions may still have their own save compatibility limits.

The current installer is unsigned. Windows may warn or block it. Only run a
file whose source you trust; do not disable security controls. Published
checksums help verify a file obtained from the same trusted source, but a
checksum alone does not identify its publisher. Distribution signing and a
trusted online update feed are not configured.

This is a local playtest delivery system. Installation success does not certify
gameplay, internet multiplayer, performance, human feel, or two-PC acceptance.
There is no registered Windows uninstall entry yet. No service, scheduled task,
firewall change, machine-wide registry entry, or administrator installation is
created. To remove the game manually, first close it and remove only the HEX
installation folder and its two optional shortcuts; keep the Godot save folder.

FOR DEVELOPERS
Build from an already verified portable Windows folder:
  pwsh -NoProfile -File scripts/build-hex-installer.ps1 -PackageDir <windows>
An optional -OutputDir must not already exist. Existing packages are never
rewritten. The builder authenticates all package entries against SHA256SUMS,
checks the PCK/build identity, and derives presentation defaults from the
authenticated PLAY-HEX.cmd. It uses the installed .NET Framework compiler;
no downloaded build tools or SDK are required. Windows x64 / .NET Framework
4.8 is the supported target for this slice.

Mechanism checks (native game stubs; no Godot):
  pwsh -NoProfile -File scripts/test-hex-installer.ps1
Optionally append -Installer <setup.exe> to verify a real payload installation
without starting it. All writes stay in unique exports/hex-installer-tests
children. Test failures and receipts are retained. Shortcuts are disabled.
Do not lower execution policy or bypass Windows application controls to test.

Automation / isolated smoke options:
  --quiet --install-only --no-shortcuts --install-root=<absolute dedicated dir>
  --quiet --print-install-root --install-root=<absolute dedicated dir>
  --quiet --no-shortcuts --install-root=<dir> --previous --install-only
Arguments after -- normally become game-specific options after the packaged
presentation defaults. To provide a complete Godot argument vector instead:
  --quiet --no-shortcuts --install-root=<dir> --engine-args -- <engine args>
With --engine-args, include the engine/game separator and presentation flags
yourself. The launcher inherits APPDATA; set an isolated APPDATA in the parent
process before a real game smoke. It does not redirect normal players' saves.

SECURITY AND FAILURE MODEL
Installation is per-user and asInvoker. ZIP extraction is bounded and rejects
traversal, duplicate paths, device names, alternate streams, and reparse paths.
The EXE pins the embedded ZIP and checksum-manifest hashes. Selection records
are protected with Windows DPAPI CurrentUser and replaced atomically. Rollback
uses those retained hashes; it never trusts an arbitrary editable manifest or
runs a backup installer. Unknown files adjacent to game binaries invalidate the
version. New payloads use new immutable directories; failed final selection
restores the launcher and preserves the selected previous build. A cancelled
or interrupted install may leave a harmless staged/new version or backup file;
this tool favors preservation over automatic cleanup.

DPAPI prevents other accounts or accidental edits from forging selections; it
is not a sandbox against malicious code already running as this same Windows
user. Unsigned initial installer authenticity still depends on trusted delivery.
Network updating, authenticated public distribution, installer signing,
registered uninstall, and clean-machine UI/SmartScreen acceptance remain open.

Official implementation references:
https://learn.microsoft.com/en-us/windows/win32/sbscs/application-manifests
https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace
https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.protecteddata
https://learn.microsoft.com/en-us/windows/apps/develop/smart-app-control/code-signing-for-smart-app-control

# Windows portrait build: install, launch and update

Status: verified local portrait delivery; preceding the momentum/roster source refinement.

Local delivery for **H.E.X. — Help, Everything eXploded!**, October 8, 2026.
Build **`p57-30b90507f932`**, protocol 57 / snapshot 23. The setup and portable
contain the same verified source as the detailed 30-champion Gallery checkpoint.
These are local files, not published download URLs or a signed public release.

## Play

| Choice | Action |
|---|---|
| Recommended: one-file setup | Run [HEX-Setup-p57-30b90507f932.exe](../exports/hex-setup-portraits-20261008/HEX-Setup-p57-30b90507f932.exe), choose **Install and play**, then use the H.E.X. shortcut or `%LOCALAPPDATA%\HEX\HEX.exe` |
| Already extracted | Run [PLAY-HEX.cmd](../exports/hex-portraits-20261008/windows/PLAY-HEX.cmd); the wrapper selects pixel character art |
| Portable / shareable archive | Extract the entire [Windows x64 ZIP](../exports/hex-portraits-20261008/HEX-p57-30b90507f932-Windows-x64.zip), then run **PLAY-HEX.cmd**; keep `hex.exe` and `hex.pck` together |

The setup contains the game and needs no Git, development Godot installation or
administrator installation. Send friends the single setup EXE, or the complete
portable ZIP, not a lone game EXE. All peers must use the **same exact build**.
Different-home Internet connection/relay acceptance is still open; an installer
does not solve connectivity by itself. See the [player guide](../README.md).

The installer is **unsigned**. Windows may warn or block it; verify its origin and
hash rather than disabling security protections. Allow comfortable free disk
space for extraction and retained versions; roughly 1 GiB free is a practical
minimum for this build, and 2 GiB or more is preferable. This is guidance, not an
installer-enforced capacity guarantee. Existing unrelated applications can also
consume space while installation is running.

## Launcher and updates

| Control / workflow | Behavior and limit |
|---|---|
| Play | Verifies and launches the selected installed payload |
| Install and play / Update and play | A trusted newer setup installs its bundled payload and retains the previous selection |
| Previous build | Verifies and swaps current/previous selections; ordinary Play respects that selection |
| Automatic payload repair | Verification/installation can recover damaged game files from the embedded payload; there is no separate Repair button, and damaged protected selection data is not automatically repaired |
| Get updates | Explains manual updating and offers the fixed GitHub releases page; no configured automatic update feed/download |
| Safe close | Game flushes local state and closes its network peer; updating while an installed game runs is refused without killing it |

For the next release, obtain and run its newer setup. Controls and weaves remain
in the existing Godot profile (`Godot/app_userdata/FLUX 2`). Build selection is
protected per Windows user; game versions are immutable and checksum-verified.
There is no background update service, silent download, administrator elevation,
automatic pruning, registered uninstaller or new online publishing in this slice.
The launcher does not enforce chronological version ordering: an older trusted
setup can explicitly select its older payload.

## What to test in game

Use 1280×720 or larger for the present playtest. Open Academy → Champions;
select a character, then click its portrait or press **P / controller Start**.
All 30 detailed portraits are included. **Esc / B / Back** returns to the roster;
**Attune** is separate. The body preview and HUD still use gameplay sprite art.
Try movement/casting, configure a weave, and close normally.

## Acceptance ledger

| Gate | Result |
|---|---|
| Frozen source, preceding source slice | 222 suites / 4,166,699 assertions; focused 3 / 2,619; import/identity/configured 120 Hz boot. Source evidence was completed before packaging, not rerun in full by this delivery task |
| Portable | Export, exact PCK identity, native startup, 30 identity/action-key admissions and normal safe close passed |
| Installer safety suite | 33 checks passed, including clean actual-payload install; synthetic repair, rollback, running-game refusal, state tampering and unsafe archive tests |
| Installed native launch | Both clean install and updated/rollback/forward install: actual stored launcher → selected new game; rendered startup, identity/art markers and safe close passed with empty stderr and no forced stop, in isolated profiles |
| Exported portraits | 30 actual imported 512px textures, exact catalog IDs, compiled packed scripts, two-entry LRU and Gallery-close release passed outside the checkout; no loose asset fallback. This is resource acceptance, not 30 rendered-image review |
| Real previous-build update | Passed old `p57-a41d15007f8c` → new `p57-30b90507f932` → rollback → forward; both actual payloads and exact protected selections/arguments verified; saved-profile sentinel unchanged. The successful resumed run reused the intact old fixture and preserved all original failure receipts/logs |
| Failure preservation | After disk exhaustion, old protected selection, all 9 payload hashes, launcher hash and saved-profile sentinel remained correct; original failed receipt retained |
| Fixture correction | First packed-portrait isolation probe incorrectly required a physical exported `res://` root; corrected fixture validates the actual isolated process directory and compiled pack resources; production payload unchanged |
| Not claimed | Human art/feel/balance acceptance; sustained dense 120 Hz; physical two-PC Internet play; code signing; automatic online updating; public release |

[Source/art evidence](portrait-gallery-evidence-20261008/README.md) ·
[Delivery evidence](portrait-windows-evidence-20261008/README.md).
Tests used isolated installation/profile folders and did not install into the
user's normal profile or create desktop/start-menu shortcuts. Shortcut creation
and physical user interaction with Windows security dialogs were not tested.
Existing team/fallback packages and the historical `current-checkpoint.json`
remain preserved; this document selects the newest **local** delivery only.

## Exact files

| Artifact | SHA-256 |
|---|---|
| Setup EXE | `526ded2ddbe167645ae2ca622bedd7844329ea38116ac8e99a4e750deb6b6a8b` |
| Portable ZIP / embedded payload ZIP | `4174801e8f41880bf9d41bddf0e0f464c04e506cf1ccf0c76ffc4c5826d9c1d8` |
| Game PCK | `391fa75efe7d22432bb3c99327bc2aa6e095459d2443d2f7b112b420090e423a` |
| Runtime source | `30b90507f932d595b030f3d7ab347537120234b1aec687ec8bfc1beb29f0d2bc` |

No commit, push, installer signing, online publication or public update feed was
performed. The preserved dirty checkout and prior working builds are untouched.

# Windows installer, launcher and offline updater

Status: local Windows playtest delivery, 2026-09-08; isolated installer journey passed.

**Historical receipt.** September9's latest exported game and policy-blocked new
installer are recorded in [the current checkpoint](TEMPLATE-DELIVERY-CHECKPOINT.md).
The [QV installer](evidence/template-delivery-v1/delivery/README.md) is newer than
this September8 artifact and has a passed isolated journey; neither older
installer includes the latest reaction-batch optimization. Do not treat the
historical current/player wording below as the latest-build pointer.

## Delivery

The current player artifact is
`exports/windows-cast-gallery-p47-20260908/release/FLUX.exe`.
It embeds the complete Windows game; no Git, Godot editor, Python or development
environment is needed on the player's computer. It installs per-user, creates
Desktop/Start Menu shortcuts and starts the game. Administrative elevation is
not requested. Source checkout and older release files are preserved.

| Action | Player workflow |
|---|---|
| Install and play | Open the provided `FLUX.exe` |
| Play again | Use the FLUX shortcut or `%LOCALAPPDATA%\FLUX\FLUX.exe` |
| Update offline | Close FLUX normally, obtain a newer `FLUX.exe` from the maintainer, then open it |
| Repair | Modified/missing game files are detected on startup; `FLUX.exe --repair` explicitly stages another verified copy |
| Custom install | `FLUX.exe --install-root="D:\Games\FLUX"`; copied launcher/shortcuts retain that location |
| Stop setup | Close the installer window; cancellation is honored before the final short selection transaction |
| Stop the game | Close normally; the existing game saves preferences and closes its session peer |

**This is not an automatic internet updater.** No update feed or public release
was published. Existing launchers do not silently download arbitrary executables.
The package is unsigned: Windows may warn about an unknown publisher or an
organization may block it. Do not disable security to run it. Hash verification
detects corruption; it does not establish a trusted publisher certificate.

## Included game state

The exported PCK was executed independently of the checkout. Its BUILD-STATE
reports protocol 47, snapshot 18, preferences 11, 120 Hz simulation, 8-player capacity,
27 named playable profiles, 57 runtime spells, 12 slots and 36 reaction definitions.
22 character profiles still have clearly labeled temporary body art. A 120 Hz
configuration is not proof of sustained 120 FPS under load.

| Artifact | Exact identity |
|---|---|
| `FLUX.exe` | 95,535,104 bytes; SHA256 `95f1b3086d56f1a944cc6d8cc6257b8b93f3812b5fdebc11c71c24deba0dedb0` |
| `FLUX2-Windows-x86_64.zip` | 95,509,480 bytes; SHA256 `060129406889159172df7d8375f218119884971cb7295431c4d6f0ecd7a98882` |
| Embedded version | `0.1.0-dev-a1aa028076-0601294068`; payload hash distinguishes this uncommitted source build |
| `flux2.pck` | SHA256 `19adcd8e3e24a9d7f25a1a3943f80b8b1e40802c1ccafb8538a6fc4e1236edeb` |

## Safety changes

| Boundary | Implementation |
|---|---|
| Corrupted manifest | Exact manifest SHA256 is embedded in the executable; empty/truncated/modified manifests cannot bypass verification |
| Payload extraction | SHA256, bounded archive size/count, safe Windows names, no traversal/device/alternate-stream paths or reparse points |
| Repair/update | New immutable version folder, verified files, launcher transaction and atomic selected-version pointer |
| Recoverability | Previous version directories remain; no automatic pruning or claimed automatic rollback |
| Installation ownership | Marked app roots, rejection of broad/source/unowned nonempty folders; narrow complete-legacy migration |
| Active game | Repair/update refuses to replace a running installation and asks for ordinary close; no external game process is killed |
| Path/arguments | Copied launcher preserves custom roots; canonical Windows quoting preserves spaces, literal slashes and quotes |
| Failure reporting | Distinguishes failed selection from a successfully selected build that failed to launch |
| Test isolation | Quiet mode, bounded owned processes, isolated app-data and no real shortcuts or user installation changes |

## Verification ledger

| Check | Result |
|---|---|
| Current source baseline | 90 game suites / 398,091 assertions passed in prior cast checkpoint; not rerun as part of packaging |
| Windows export | Export and executed PCK content report pass; no rejected character/pixel-v2 drafts packaged |
| C# compiler | .NET Framework compilation with warnings treated as errors passes |
| Native executable preflight | Quiet root-resolution command exits 0 on this machine |
| Native installer journey | 16 recorded gates pass: clean install, stored-root inference/reuse, immutable corrupt-PCK and empty-manifest repairs, invalid/unowned-root refusals, distinct-baseline update/previous retention, isolated user data, installed content identity and actual launcher/game boot |
| Argument integrity | 20 assertions using the compiled installer's formatter and native Windows `CommandLineToArgvW`; empty strings, spaces, quotes and backslash boundaries |
| Installed game boot | Actual installed `FLUX.exe` starts the release game headlessly for 3 frames; protocol 47 / 120 Hz initialization, clean game log, no remaining test game process |
| Isolation | Test-root preferences verified; no real home install or shortcuts requested |
| Trusted signing, public online updates, internet play, sustained 120 FPS | Not accepted by this delivery |

Retained [receipt and logs](evidence/windows-delivery-v1/README.md) identify the
exact installer above. Successful process stderr is empty; negative-root tests
intentionally emit refusal diagnostics. This is not a fresh rendered playthrough,
a Windows X-button shutdown test, a real Desktop/Start Menu shortcut test or a
physical two-PC connection test. Those player acceptance boundaries remain open.

The update baseline used by tests is explicitly a current-game fixture with an
extra authenticated marker file, not a falsely labeled historical release.
The first test harness attempted a tools-only `--script` flag with the release
binary; the corrected harness uses the pinned editor only for its no-write
user-data probe and exact installed-PCK inspection, then the actual stored
launcher for release-game startup. Earlier failed harness receipts are retained.
No release source was committed or pushed. Keep supplied SHA256SUMS with the
artifact and use the same build on all peers. Remote internet hosting still
requires the existing network arrangement, such as allowing UDP 24872 at the host
or using a private network overlay; the installer does not silently change router
or firewall policy.

## Rebuild and retest

```powershell
.\scripts\package.ps1 -Target Windows -ExportRoot C:\path\to\new-build
.\scripts\test-windows-bootstrap.ps1 -Installer C:\path\to\new-build\release\FLUX.exe
```

To include the update gate, pass `-BaselineInstaller` with a different hardened
build that supports quiet testing. Without it, the script explicitly records
that update acceptance was skipped. Do not pass the old pre-quiet launcher.

Use a new output directory to preserve previous artifacts. Test scripts and
authored source are in `packaging/windows-bootstrap/` and `scripts/`; final
artifact hashes and validation receipts belong with the delivery evidence.

Known follow-up: repeatedly opening the identical external installer retains
another launcher backup. Use the installed shortcut for ordinary play. Old
versions are intentionally not automatically pruned, and this build does not
include a rollback picker or clean-uninstall interface.

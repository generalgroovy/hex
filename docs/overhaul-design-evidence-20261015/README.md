# October 15 overhaul design inputs

These are the final Gameplay, Experience and Technical specialist drafts used
for the cross-reviewed [consolidated proposal](../OVERHAUL-DESIGN-20261015.md).
They preserve source anchors, design reasoning, budgets and narrower contracts.
The consolidated proposal resolves cross-review findings and takes precedence;
the [single queue](../../.agent/OVERHAUL-IMPLEMENTATION.md) is the only active task
ledger. These drafts do not imply runtime implementation or fresh acceptance.

| Input | SHA-256 of preserved bytes |
|---|---|
| [Gameplay](gameplay.md) | `b3d715800da49fac4fed7aed0fdb1d693db2a1c2ae9338973740b1f6e65dc253` |
| [Experience](experience.md) | `c82c4d155fae69066d80d7860acd01a665aa51cff5408926dfacb8da301502a8` |
| [Technical](technical.md) | `0445c56ee805a617eaeac0ecea03b647aca2f9143d257d83455f3d4290c3743f` |

The drafts were copied byte-for-byte from the Windows agents' local working
directory, `.godot/overhaul-design-20261015/`. Their absolute source links starting
with `C:/Users/sende/Projects/hex/` map to the same relative path under the receiving
Linux checkout; a trailing `:N` is a source line reference. Windows wrapper,
local export and capture-cache paths retain their historical meaning and may be
absent on Linux. Do not import the working cache or mistake unavailable local
captures for portable qualification. Follow the [Linux handoff](../../.agent/LINUX-HANDOFF.md)
for platform-specific acceptance limits.

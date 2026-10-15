# Eight-peer publication failure diagnosis

Status: Prepared source only. No engine execution and no tracked test changes.

The active Full run rejected one production publication in the eight-player
outage_return scenario. Queue peak 138 and zero socket-send failures narrow the
failure to capture, but the exact rejected invariant was not logged. Source
bytes for the fixture, transport, authority, world and snapshot codecs match
the prior qualified d6d1 inputs. Host memory pressure and slower timings are
context, not a proved cause and not grounds to relax the 2700-second Full cap.

`network-impairment-failure.patch` changes only the existing test fixture. Root
may apply it after the current Full reaches terminal disposition and the exact
patch is peer reviewed. The initial review is preserved in `before-entry-proof`.
`prepare_patch.py` then `add_entry_envelope.py` reproduce the proposed source.
Neither script writes the tracked test.

The original capture factory is called once at every original publication.
Its original result, broadcast and assertion remain authoritative. The fixture
retains at most 241 ordered `take_inputs`/sent/applied command batches. It does
not sort incoming packets or reconstruct inputs from the injected delay model.
The initial detached publication envelope supplies entry hash, epoch, tick and
authority without recapture. The first failure prints a small JSON context,
then up to 4 MiB of typed Variant bytes as numbered hex chunks with SHA-256,
before calling deeper diagnostic validators. Overflow is explicit. No resume
tokens, private profiles, additional full captures or success retries appear.
Do not deserialize Variant bytes with object deserialization enabled.

The deeper checks distinguish actor/shot rows, ledger validity, world/chemistry
relations, conservation, session shape, chemistry encoding shape and size.
The raw witness survives a later validator error. `court.cells` is never read,
so diagnosis does not materialize sealed topology through that getter. A raw
witness is the state after the original failed capture attempt; it is not a
claim that every strict codec has no internal memoization. The full field and
packet checks remain unchanged.

The patch can run in ordinary Full CI: witness lines are part of `suite.log`,
which the current CI artifact step preserves on failure. The extra trace work
can change poll/batch timing. A rerun pass does not explain the historical
failure, and these diagnostic p95 timings are not performance evidence.

`diagnose-outage.gd` executes only the original complete eight-player
outage_return scenario: 240 impaired ticks, final input drain, full recovery
and actual disconnect/reconnect. It does not call the inherited matrix `run`.
The original fixture's explicit test handshake identity remains explicit; the
runner separately pins current production source and the generated identity.

`run-network-capture.ps1` is a fixed desktop Diagnostic route. It refuses the
unchanged old test until the exact reviewed patch has been applied, checks the
input inventory before and after, preserves the current default delivery, uses
an isolated APPDATA and the checkout engine lease, and retains failures/logs.
Its strict parser bound is 180 seconds; its one scenario uses the existing
Full 2700-second envelope. No test tier or production limit changes.

Root-only command after terminal Full, application, parser approval and final
runner hash admission (substitute the exact final runner SHA):

```powershell
& 'C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd' -Mode Diagnostic -DiagnosticRunner '.godot/iteration-20261015/network-capture-diagnostic/run-network-capture.ps1' -DiagnosticRunnerSha256 '95e9c37be54ce6e347d6fa04441d40b34ca907f299f89d874ff75de91bef23ab' -DiagnosticCase outage-eight -OutputDirectory '.godot/iteration-20261015/network-capture-diagnostic/runs/outage-eight-a'
```

Root may instead run a fresh Windows CI Full on the explicitly published
candidate while this local scenario uses the other host. That is separate
evidence. Neither result promotes the portable, merges a branch, or replaces
the preserved failed Full output.

# Terminal confirmation reproduction — ignored, corrected admission pending

This is one bounded investigation of the existing earned-confirmation cue. It is
not a repair or a listening/mixing test. Canonical `p61-500be306a26a` is unchanged.

The first `probe-a` run passed parsing but stopped before the encounter because
the helper tried to find consumed engine options in `OS.get_cmdline_args()`.
Its exact helper/checkpoint/wrapper/logs/receipt are preserved in
`backend-admission-failed-1/`. It is a rejected fixture admission, not audio
behavior evidence. The corrected helper queries the selected backend through
`AudioServer.get_driver_name()` and records it in `result.audio_driver`. This is
the same API already used by `tests/unit/test_element_audio.gd:306` and documented
in the [official Godot AudioServer API](https://docs.godotengine.org/en/4.6/classes/class_audioserver.html#class-audioserver-method-get-driver-name).
Only this guard/diagnostic changed; the paid route and premature-stop witness
remain exact. A fresh root-owned run is still required.

The second `probe-b` run admitted the actual Dummy backend and passed 75 checks
before failing session binding. Its 20-character fixture name exceeded the
existing 15-character name limit. Exact failed bytes and logs are retained in
`session-binding-failed-2/`. The next helper uses `Audio probe`, records the
binding result and `last_error`, and requires binding to preserve the entire
world hash and original hostile teams `[1,2]`. Default charter binding only
reapplies host team 1, so it must not alter the copied challenge route; the
fixture does not repair teams or change challenge/binding order. No encounter
or confirmation playback has yet been reached.

The helper copies exactly `_campus_encounter` and `_counter_command` from the
existing `test_signature_progression.gd`; startup strips/extracts and compares
those bodies against pinned current source. One actual Wa Bidi district challenge
uses full-health authored profiles, its normal rival AI and ordinary held Fire
Bolt counter. It permits at most 8,641 successful-attempt iterations. No health,
resource, clock, cooldown, source, reward or victory event is granted during the
route. If it cannot win, `reproduced` stays false and the investigation stops.

Every paid step reaches the real expansion controller's `after_step`. Immediately
before observing an actual lethal paid boundary, the helper empties **only audio**
as a declared voice-availability control. It does not claim that the normal mixed
pool is always available. The controller must earn and save the real reward.
Four real `AudioStreamPlayer` children run with the explicitly required **Dummy**
audio driver. A subclass records calls around the unchanged audio methods; there
are no fake voices or overridden playback semantics.

The primary witness is an admitted, playing `confirmed` voice followed by its
stop at the next actual inherited Bootstrap frozen-result callback, before its
220 ms clip could finish. The stop itself must record reserved confirmation
voice 3 still playing with `result_confirmed`, at an age below the actual clip
length; a pre-callback timestamp alone is insufficient. Three callbacks must reach the true freeze
predicate, preserve authority/events/paid metrics and leave reward/save bytes
unchanged. The saved signature must reload and the terminal packet must pass
strict capture. The prepared minimal Bootstrap omits boot/rendering/art and
uses synthetic application eligibility; it does not prove physical focus, menu
navigation or full player lifecycle.

After that primary proof, four **synthetic presentation-only controls** reuse
the same genuine saved result: focus notification, actual Controls editor state,
mute and the existing trial input-handoff reset. They re-arm only `_last_reward`,
the controller's notice deduplication marker. They do not reset the challenge,
guide, world or earned reward, and are not four additional victories. Admission
and stop outcomes are recorded; mute must reject, reset/blocked processing must
stop, and regain must not replay. The handoff control is the existing audio/input
reset seam, **not a complete world-replacement test**. A full reset remains a
separate integration boundary if a repair is later selected.

Fresh output is restricted to a direct `probe-*` child of this helper's `runs`.
All progression writes use an explicit path there. Ordinary preference writes
are transient and must stay zero. InputMap events and mouse state are restored;
the owned session/node/audio children are freed on normal or failed completion.
Pinned sources are rechecked, and receipt bytes are read back. `integrity_passed`
and `reproduced` are separate: an unreachable route is not a game defect proof.

Root only, after source review and strict parse, with a bounded external watchdog:

```text
--headless --path C:/Users/sende/Projects/hex --audio-driver Dummy --script res://.godot/iteration-20261013/terminal-audio/probe-terminal-audio.gd -- --no-lan-discovery --output=res://.godot/iteration-20261013/terminal-audio/runs/probe-c
```

No audible waveform, comfort, loudness, performance, FPS or human cue-recognition
claim can be made from Dummy-backed admission/stop calls.

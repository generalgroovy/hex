from pathlib import Path

root = Path(__file__).parent
path = root / 'src/app/bootstrap.gd'
s = path.read_text(encoding='utf-8')

# Scenario presentation is distinct from the shared chemistry authority.
for old, new in [
    ('if world.hex_court != null:\n\t\t\t\tvar opened', 'if _is_hex_practice():\n\t\t\t\tvar opened'),
    ('if world.hex_court != null:\n\t\t\t\t\t_start_hex_court()', 'if _is_hex_practice():\n\t\t\t\t\t_start_hex_court()'),
    ('(interception_practice_active or world.hex_court != null)', '(interception_practice_active or _is_hex_practice())'),
    ('if interception_practice_active or world.hex_court != null:', 'if interception_practice_active or _is_hex_practice():'),
    ('if world.hex_court != null:\n\t\tdraw_rect(get_viewport_rect()', 'if _is_hex_practice():\n\t\tdraw_rect(get_viewport_rect()'),
    ('campus_renderer.natural_kit != null and world.hex_court == null', 'campus_renderer.natural_kit != null and not _is_hex_practice()'),
    ('if world.hex_court != null:\n\t\tlocation_name', 'if _is_hex_practice():\n\t\tlocation_name'),
    ('if world.hex_court != null:\n\t\t_draw_hex_court_help()', 'if _is_hex_practice():\n\t\t_draw_hex_court_help()'),
    ('if world.hex_court != null and session_transport.mode', 'if _is_hex_practice() and session_transport.mode'),
    ('if world.hex_court == null: character_weaves.remember_actor(state)', 'if not _is_hex_practice(): character_weaves.remember_actor(state)'),
    ('if world != null and world.hex_court != null:\n\t\tfocused_station_id', 'if _is_hex_practice():\n\t\tfocused_station_id'),
    ('world != null and world.hex_court == null and not interception_practice_active', 'world != null and not _is_hex_practice() and not interception_practice_active'),
    ('if world.hex_court != null:\n\t\ttarget_definitions.append', 'if _is_hex_practice():\n\t\ttarget_definitions.append'),
    ('if world != null and world.hex_court != null:\n\t\treturn camera_origin_for', 'if _is_hex_practice():\n\t\treturn camera_origin_for'),
]:
    assert old in s, old
    s = s.replace(old, new)

old = '''\tif world.hex_court != null:
\t\thex_court_presenter.draw_ground(self, world.hex_court, float(world.tick) + alpha, _reduced_effects_enabled())
\telse:
\t\tcampus_renderer.draw(self, campus_layout, roundi(visual_tick), camera_focus_position, _reduced_effects_enabled())'''
new = '''\tif not _is_hex_practice():
\t\tcampus_renderer.draw(self, campus_layout, roundi(visual_tick), camera_focus_position, _reduced_effects_enabled())
\tif world.hex_court != null:
\t\thex_court_presenter.draw_ground(self, world.hex_court, float(world.tick) + alpha, _reduced_effects_enabled(), _is_hex_practice())'''
assert old in s
s = s.replace(old, new)

old = '''\tworld = SimWorld.new(
\t\ttick_rate,
\t\t8675309,
\t\tcampus_layout.build_collision_world(),
\t\tString(campus_layout.data.get("id", "")),
\t\tcampus_layout.content_hash,
\t)'''
assert old in s
s = s.replace(old, '''\tworld = _new_wellspring_world(tick_rate)
\tif world == null: return false''')

begin = s.index('func _restart_shared_seed(')
end = s.index('\n\nfunc _begin_shared_practice()', begin)
s = s[:begin] + '''func _restart_shared_seed(requested_tick_rate: int) -> bool:
\tif session_transport == null or not session_transport.is_host():
\t\treturn _start_match(requested_tick_rate)
\tvar candidate := _new_wellspring_world(requested_tick_rate)
\tif candidate == null: return false
\t_spawn_practice_targets(candidate)
\tif not authoritative_session.replace_world(candidate, campus_layout.spawn): return false
\tworld = authoritative_session.world
\tif not session_transport.configure_world_epoch(authoritative_session.world_epoch): return false
\tsession_names_by_entity = authoritative_session.names_by_entity.duplicate()
\tsession_hearth_values = authoritative_session.hearth.capture(world.tick, SessionCharter.maximum_players(selected_charter_id))
\tsession_round_values = authoritative_session.session_round.capture(world)
\temote_ready_tick_by_entity.clear()
\tsocial_bubbles.clear()
\tcombat_cues.clear()
\tinput_router.discard_transient_movement_input()
\t_reset_motion_history()
\treturn true
''' + s[end:]

s = s.replace('func _spawn_practice_targets() -> void:\n', 'func _spawn_practice_targets(destination: SimWorld = null) -> void:\n\tif destination == null: destination = world\n')
begin = s.index('func _spawn_practice_targets(')
end = s.index('\n\nfunc ', begin)
part = s[begin:end].replace('world.players.append(target)', 'destination.players.append(target)')
s = s[:begin] + part + s[end:]
s = s.replace('session_transport.broadcast_snapshot(authoritative_session.capture_snapshot())', 'session_transport.broadcast_envelope(authoritative_session.capture_envelope())')
s = s.replace('var last_client_snapshot_tick: int = -1', 'var last_client_snapshot_tick: int = -1\nvar last_client_world_epoch: int = -1\nvar trusted_hex_template: SimWorld = null')
s = s.replace('\t\tlast_client_snapshot_tick = -1', '\t\tlast_client_snapshot_tick = -1\n\t\tlast_client_world_epoch = -1')
s = s.replace('\n\tlast_client_snapshot_tick = -1', '\n\tlast_client_snapshot_tick = -1\n\tlast_client_world_epoch = -1')
s = s.replace('var snapshots := session_transport.take_snapshots()', 'var snapshots := session_transport.poll_envelopes()')
s = s.replace('if int(snapshot.get("tick", -1)) > last_client_snapshot_tick and SessionSnapshot.apply_to_world(snapshot, world):', 'if _apply_world_envelope(snapshot):')
s = s.replace('var overflow: PackedInt32Array = snapshot.get("overflow", PackedInt32Array([0, 0, 0]))', 'var overflow: PackedInt32Array = WorldSnapshotEnvelope.overflow(snapshot)')
s = s.replace('session_names_by_entity = SessionSnapshot.names(snapshot)', 'session_names_by_entity = _envelope_names(snapshot)')
s = s.replace('session_hearth_values = SessionSnapshot.hearth_values(snapshot)', 'session_hearth_values = WorldSnapshotEnvelope.hearth(snapshot)')
s = s.replace('session_round_values = SessionSnapshot.round_values(snapshot)', 'session_round_values = WorldSnapshotEnvelope.round_state(snapshot)')

s += '''

func _is_hex_practice() -> bool:
\treturn world != null and world.map_id == "hex-court-v1"


func _new_wellspring_world(rate: int) -> SimWorld:
\tvar candidate := SimWorld.new(rate, 8675309, campus_layout.build_collision_world(), String(campus_layout.data.id), campus_layout.content_hash)
\tvar definition := HexWorldDefinition.from_campus(campus_layout)
\tif definition == null or not definition.bind_world(candidate): return null
\treturn candidate


func _envelope_names(envelope: Dictionary) -> Dictionary[int, String]:
\tvar result: Dictionary[int, String] = {}
\tfor row: Array in WorldSnapshotEnvelope.names(envelope): result[int(row[0])] = String(row[1])
\treturn result


func _apply_world_envelope(envelope: Dictionary) -> bool:
\tif not WorldSnapshotEnvelope.validate(envelope): return false
\tvar epoch := int(envelope.world_epoch)
\tvar next_tick := int(envelope.tick)
\tif epoch < last_client_world_epoch or (epoch == last_client_world_epoch and next_tick <= last_client_snapshot_tick): return false
\tvar candidate: SimWorld = null
\tif int(envelope.world_kind) == WorldSnapshotEnvelope.WORLD_HEX:
\t\t# Remote metadata only selects the trusted local campus; it supplies no topology.
\t\tif String(envelope.authority.map_id) != String(campus_layout.data.id): return false
\t\tif trusted_hex_template == null: trusted_hex_template = _new_wellspring_world(tick_rate)
\t\tif trusted_hex_template == null: return false
\t\tcandidate = HexWorldSnapshot.prepare(envelope.authority, trusted_hex_template)
\telse:
\t\tcandidate = SimWorld.new(tick_rate, 8675309, campus_layout.build_collision_world(), String(campus_layout.data.id), campus_layout.content_hash)
\t\tif not SessionSnapshot.apply_to_world(envelope.authority, candidate): return false
\tif candidate == null: return false
\tfor row: Array in WorldSnapshotEnvelope.names(envelope):
\t\tvar actor := candidate.player(int(row[0]))
\t\tif actor == null: return false
\t\tactor.last_event = String(row[2])
\tcandidate.combat_events.clear()
\tfor row: PackedInt64Array in WorldSnapshotEnvelope.events(envelope):
\t\tvar event := SessionSnapshot.decode_event(row)
\t\tif not event.is_empty(): candidate.combat_events.append(event)
\tvar changed_epoch := epoch != last_client_world_epoch
\tworld = candidate
\tlast_client_world_epoch = epoch
\tif changed_epoch:
\t\tcombat_cues.clear()
\t\tsocial_bubbles.clear()
\t\temote_ready_tick_by_entity.clear()
\t\tclient_prediction.reset()
\t\t_reset_motion_history()
\tif not _is_spectating():
\t\tif client_prediction.local_entity_id != session_transport.local_entity_id:
\t\t\tclient_prediction.configure(world.config, world.collision, session_transport.local_entity_id)
\t\tclient_prediction.bind_hex_world(world)
\treturn true
'''
path.write_text(s, encoding='utf-8', newline='\n')
print('Staged shared Wellspring and epoch-aware Bootstrap integration')

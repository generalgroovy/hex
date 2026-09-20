extends RefCounted
@warning_ignore_start("integer_division")

# Diagnostic-only mirror of ElementChemistrySystem.step at source hash
# bad2bbd7841d1c1b3d857115bce574e78b9a82eaee29fd3d4721e894ee9f9896.
# Run only on the separate RuntimeStressProbe mirror world. The order below
# intentionally keeps clear_line before the occupied-cell check so it remains
# a frozen observer for the proposed future reorder.
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")

const SUBPHASES := [
	"deposit_cleanup",
	"reaction_cleanup",
	"deposit_sort",
	"reaction_sort",
	"occupied_build",
	"pair_admission",
	"pair_gate_clear_line",
	"consumed_cleanup",
	"actor_sort",
	"update_geometry",
	"apply_result",
]


static func measured_step(
	deposits: Array,
	reactions: Array,
	actors: Array,
	collision: CollisionWorld,
	config: SimConfig,
	tick: int,
	next_reaction_id: int,
	events: Array,
) -> Dictionary:
	var times := {}
	for phase: String in SUBPHASES:
		times[phase] = 0
	var counts := {
		"deposits_before": deposits.size(),
		"reactions_before": reactions.size(),
		"expired_or_empty_deposits": 0,
		"expired_reactions": 0,
		"occupied_cells": 0,
		"pair_visits": 0,
		"outer_capacity_breaks": 0,
		"left_empty_rejects": 0,
		"pair_identity_rejects": 0,
		"trail_chronology_rejects": 0,
		"reach_rejects": 0,
		"reach_qualified_pairs": 0,
		"pair_gate_clear_line_calls": 0,
		# Each call can exit early. This is the exact sum of the production
		# per-call sample bounds, not a measured allocator/collision sample count.
		"pair_gate_clear_line_sample_upper_bound": 0,
		"line_of_sight_rejects": 0,
		"occupied_cell_rejects_after_los": 0,
		"recipe_rejects": 0,
		"reactions_formed": 0,
		"consumed_deposits_removed": 0,
		"actors_sorted": actors.size(),
		"update_geometry_calls": 0,
		"active_reactions": 0,
		"apply_result_calls": 0,
	}
	var total_started := Time.get_ticks_usec()

	var started := Time.get_ticks_usec()
	for index: int in range(deposits.size() - 1, -1, -1):
		if tick >= int(deposits[index].expiry_tick) or int(deposits[index].strength) <= 0:
			deposits.remove_at(index)
			counts.expired_or_empty_deposits += 1
	times.deposit_cleanup = Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	for index: int in range(reactions.size() - 1, -1, -1):
		if tick >= int(reactions[index].expiry_tick):
			reactions.remove_at(index)
			counts.expired_reactions += 1
	times.reaction_cleanup = Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	deposits.sort_custom(func(a: ElementDepositState, b: ElementDepositState) -> bool: return a.entity_id < b.entity_id)
	times.deposit_sort = Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	reactions.sort_custom(func(a: ElementReactionState, b: ElementReactionState) -> bool: return a.entity_id < b.entity_id)
	times.reaction_sort = Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	var occupied := {}
	for existing: ElementReactionState in reactions:
		occupied[Chemistry.cell(Vector2i(existing.origin_x, existing.origin_y))] = true
	counts.occupied_cells = occupied.size()
	times.occupied_build = Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	# Keep this block byte-for-byte equivalent in decision order to the frozen
	# production observer. Counter and timer work is diagnostic overhead.
	for left: int in range(deposits.size()):
		if reactions.size() >= Chemistry.MAX_REACTIONS or actors.size() > Chemistry.MAX_TRACKED_ACTORS:
			counts.outer_capacity_breaks += 1
			break
		var a: ElementDepositState = deposits[left]
		if a.strength <= 0:
			counts.left_empty_rejects += 1
			continue
		for right: int in range(left + 1, deposits.size()):
			counts.pair_visits += 1
			var b: ElementDepositState = deposits[right]
			if b.strength <= 0 or a.source_cast_id == b.source_cast_id or (a.is_trail() and b.is_trail()):
				counts.pair_identity_rejects += 1
				continue
			if (a.is_trail() and b.created_tick <= a.created_tick) or (b.is_trail() and a.created_tick <= b.created_tick):
				counts.trail_chronology_rejects += 1
				continue
			var apos := Vector2i(a.position_x, a.position_y)
			var bpos := Vector2i(b.position_x, b.position_y)
			var reach := a.radius + b.radius
			var distance_squared := (apos - bpos).length_squared()
			if distance_squared > reach * reach:
				counts.reach_rejects += 1
				continue
			counts.reach_qualified_pairs += 1
			counts.pair_gate_clear_line_calls += 1
			var distance := SimCommand._integer_square_root(distance_squared)
			counts.pair_gate_clear_line_sample_upper_bound += mini(512, maxi(1, (distance + 1999) / 2000))
			var line_started := Time.get_ticks_usec()
			var line_clear := Chemistry.clear_line(apos, bpos, collision)
			times.pair_gate_clear_line += Time.get_ticks_usec() - line_started
			if not line_clear:
				counts.line_of_sight_rejects += 1
				continue
			var center := Chemistry.midpoint(apos, bpos)
			if occupied.has(Chemistry.cell(center)):
				counts.occupied_cell_rejects_after_los += 1
				continue
			var wire := Chemistry.recipe_wire(a.element_wire_id, b.element_wire_id)
			if wire == 0:
				counts.recipe_rejects += 1
				continue
			var result := Chemistry.form_reaction(a, b, next_reaction_id, tick, config)
			Chemistry._build_path(result, deposits, collision)
			reactions.append(result)
			occupied[Chemistry.cell(center)] = true
			for fragment: ElementDepositState in deposits:
				if fragment.source_cast_id == a.source_cast_id or fragment.source_cast_id == b.source_cast_id:
					fragment.strength = 0
			next_reaction_id += 1
			events.append({"type":"chemistry_formed", "reaction_id":result.entity_id, "recipe_wire_id":wire, "owner_id":result.owner_id})
			counts.reactions_formed += 1
			break
	times.pair_admission = Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	for index: int in range(deposits.size() - 1, -1, -1):
		if int(deposits[index].strength) <= 0:
			deposits.remove_at(index)
			counts.consumed_deposits_removed += 1
	times.consumed_cleanup = Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	var ordered := actors.duplicate()
	ordered.sort_custom(func(a: PlayerState, b: PlayerState) -> bool: return a.entity_id < b.entity_id)
	times.actor_sort = Time.get_ticks_usec() - started

	for result: ElementReactionState in reactions:
		started = Time.get_ticks_usec()
		Chemistry._update_geometry(result, collision, config, tick)
		times.update_geometry += Time.get_ticks_usec() - started
		counts.update_geometry_calls += 1
		if not result.active(tick):
			continue
		counts.active_reactions += 1
		started = Time.get_ticks_usec()
		Chemistry._apply_result(result, deposits, reactions, ordered, collision, config, tick, events)
		times.apply_result += Time.get_ticks_usec() - started
		counts.apply_result_calls += 1

	counts.deposits_after = deposits.size()
	counts.reactions_after = reactions.size()
	return {
		"ok": true,
		"next_reaction_id": next_reaction_id,
		"times": times,
		"counts": counts,
		"total_us": Time.get_ticks_usec() - total_started,
	}

extends FluxTestSuite


const Demo = preload("res://src/app/hex_playground_demo.gd")
const TARGET := Vector2i(1_504_000, 1_344_000)
var catalog := AbilityCatalog.new()
var layout := SanctumCampusLayout.new()
var definition: HexWorldDefinition


func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "paid demo uses the production ability catalog")
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "paid demo uses the production Wellspring campus")
	definition = HexWorldDefinition.from_campus(layout)
	check(definition != null, "paid demo has the normal campus whole-hex definition")
	if definition == null:
		return finish("hex-playground-demo")
	_test_different_pair()
	_test_mirror_pair()
	_test_cancel_does_not_rollback_payment()
	_test_insufficient_flux_is_atomic()
	return finish("hex-playground-demo")


func _world(seed: int) -> SimWorld:
	var world := SimWorld.new(120, seed, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	check(definition.bind_world(world), "paid demo binds the normal campus whole-hex authority")
	world.player().reset_for_spawn(Vector2i(1_504_000, 1_440_000))
	world.player().spawn_protection_ticks = 0
	return world


func _customize(actor: PlayerState) -> Dictionary:
	var custom := actor.spell_wire_ids.duplicate()
	custom.reverse()
	check(CharacterWeavePolicy.apply(actor, custom), "fixture applies a valid custom twelve-spell weave")
	actor.set_spell_cooldown(custom[0], 400)
	actor.set_spell_cooldown(custom[5], 177)
	return {
		"wires": actor.spell_wire_ids.duplicate(),
		"cooldowns": actor.spell_cooldown_ticks.duplicate(),
		"primary": actor.primary_wire_id,
		"active_1": actor.active_1_wire_id,
		"active_2": actor.active_2_wire_id,
		"primary_cooldown": actor.primary_cooldown_ticks,
		"active_1_cooldown": actor.active_1_cooldown_ticks,
		"active_2_cooldown": actor.active_2_cooldown_ticks,
	}


func _drive(world: SimWorld, demo: HexPlaygroundDemo, limit: int = 600) -> int:
	var start := world.tick
	for unused: int in limit:
		if not demo.is_active():
			break
		var command := demo.command(world)
		if command == null:
			break
		equal(Vector2i(command.move_x, command.move_y), Vector2i.ZERO, "guided paid-demo commands keep movement neutral")
		equal(Vector2i(command.aim_target_x, command.aim_target_y), TARGET, "guided paid-demo commands keep the authored target")
		check(world.step([command]), "ordinary authority accepts each guided command")
	check(not demo.is_active(), "paid demo reaches a finite terminal state")
	return world.tick - start


func _product(world: SimWorld, recipe_wire: int) -> Dictionary:
	for candidate: Dictionary in world.hex_court.products.values():
		if int(candidate.recipe_wire_id) == recipe_wire:
			return candidate
	return {}


func _assert_restored(actor: PlayerState, saved: Dictionary, elapsed: int) -> void:
	equal(actor.spell_wire_ids, saved.wires, "the exact custom twelve-position weave is restored")
	equal(actor.primary_wire_id, int(saved.primary), "the original primary channel is restored")
	equal(actor.active_1_wire_id, int(saved.active_1), "the original active-one channel is restored")
	equal(actor.active_2_wire_id, int(saved.active_2), "the original active-two channel is restored")
	for index: int in PlayerState.SPELL_SLOT_COUNT:
		var wire := int(saved.wires[index])
		var expected := maxi(0, int(saved.cooldowns[index]) - elapsed)
		# The demo waits for either selected Bolt's real cooldown before restoring.
		equal(actor.spell_cooldown_for_wire(wire), expected, "cooldown for restored spell %d advances with world time" % wire)


func _test_different_pair() -> void:
	var world := _world(8101)
	var actor := world.player()
	var saved := _customize(actor)
	var flux_before := actor.flux
	var paid_before := int(world.hex_court.metrics.matter_paid)
	var demo := Demo.new()
	check(demo.begin(world, actor.entity_id, "water", "fire", catalog), "different-element paid demo begins from a legal grounded actor")
	equal(Vector2i(actor.position_x, actor.position_y), Vector2i(1_504_000, 1_440_000), "demo uses the existing clear experiment bench")
	var elapsed := _drive(world, demo)
	equal(int(world.hex_court.metrics.matter_paid), paid_before + 1_200, "different pair pays two real 600-matter admissions")
	check(actor.flux < flux_before, "different pair pays positive real Flux")
	var product := _product(world, HexRecipePolicy.recipe_wire(3, 2))
	check(not product.is_empty(), "Water plus Fire forms an observable production product")
	if not product.is_empty():
		equal(int(product.quantity), 1_200, "different pair product contains both finite paid budgets")
		equal(product.source_ids.size(), 2, "different pair product records two paid sources")
		check(product.source_ids[0] != product.source_ids[1], "different pair never reacts one source with itself")
	check(demo.status().contains("complete") and demo.status().contains("1200"), "completion status reports the observable paid result")
	_assert_restored(actor, saved, elapsed)


func _test_mirror_pair() -> void:
	var world := _world(8102)
	var actor := world.player()
	var saved := _customize(actor)
	var flux_before := actor.flux
	var demo := Demo.new()
	check(demo.begin(world, actor.entity_id, 1, 1, catalog), "mirror paid demo accepts element-wire selection")
	var temporary := actor.spell_wire_ids.duplicate()
	equal(temporary.count(int(catalog.ability(catalog.spell_id_at("earth", "bolt")).wire_id)), 1, "mirror demo equips one unique Bolt slot and reuses it")
	var elapsed := _drive(world, demo)
	equal(int(world.hex_court.metrics.matter_paid), 1_200, "mirror pair pays two separate 600-matter admissions")
	check(actor.flux < flux_before, "mirror pair pays positive real Flux")
	var product := _product(world, HexRecipePolicy.recipe_wire(1, 1))
	check(not product.is_empty(), "mirror pair forms an observable production product")
	if not product.is_empty():
		equal(int(product.quantity), 1_200, "mirror product contains two finite paid budgets")
		equal(product.source_ids.size(), 2, "mirror product records two distinct paid source IDs")
		check(product.source_ids[0] != product.source_ids[1], "mirror pair cannot react one cast with itself")
	_assert_restored(actor, saved, elapsed)


func _test_cancel_does_not_rollback_payment() -> void:
	var world := _world(8103)
	var actor := world.player()
	var saved := _customize(actor)
	var demo := Demo.new()
	var start_tick := world.tick
	check(demo.begin(world, actor.entity_id, "earth", "wind", catalog), "cancel fixture begins")
	var first := demo.command(world)
	check(first != null and first.first_pressed_spell_slot() == 1, "first guided command is a real slot press")
	check(world.step([first]), "first paid cast admits before cancellation")
	equal(int(world.hex_court.metrics.matter_paid), 600, "one admitted cast owns one paid budget before cancellation")
	demo.cancel(world)
	_drive(world, demo)
	var elapsed := world.tick - start_tick
	equal(int(world.hex_court.metrics.matter_paid), 600, "cancel never refunds or invents a paid cast")
	check(world.hex_court.pending.is_empty() and world.projectiles.is_empty(), "cancel drains the already-paid startup and flight normally")
	check(demo.status().contains("no payment was rolled back"), "cancel status explains the paid-cast boundary")
	_assert_restored(actor, saved, elapsed)


func _test_insufficient_flux_is_atomic() -> void:
	var world := _world(8104)
	var actor := world.player()
	var saved_actor := actor.canonical_values()
	var position := Vector2i(actor.position_x, actor.position_y)
	var fields_before := world.fields.duplicate()
	var deposits_before := world.deposits.duplicate()
	var reactions_before := world.reactions.duplicate()
	var casts_before: Dictionary = world.hex_court.casts.duplicate(true)
	var products_before: Dictionary = world.hex_court.products.duplicate(true)
	actor.flux = 11_999
	saved_actor = actor.canonical_values()
	var demo := Demo.new()
	check(not demo.begin(world, actor.entity_id, "water", "fire", catalog), "insufficient total Flux refuses before setup")
	equal(actor.canonical_values(), saved_actor, "insufficient Flux changes no actor authority field")
	equal(Vector2i(actor.position_x, actor.position_y), position, "insufficient Flux does not move the actor")
	equal(world.fields, fields_before, "insufficient Flux injects no legacy field")
	equal(world.deposits, deposits_before, "insufficient Flux injects no legacy deposit")
	equal(world.reactions, reactions_before, "insufficient Flux injects no legacy reaction")
	equal(world.hex_court.casts, casts_before, "insufficient Flux creates no paid whole-hex source")
	equal(world.hex_court.products, products_before, "insufficient Flux injects no whole-hex product")
	equal(int(world.hex_court.metrics.matter_paid), 0, "insufficient Flux records no matter payment")

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
	_test_six_element_admission()
	_test_different_pair()
	_test_mirror_pair()
	_test_cancel_does_not_rollback_payment()
	_test_insufficient_flux_is_atomic()
	_test_cancel_before_payment_and_invalidation()
	_test_abort_retains_paid_outcome()
	_test_shared_payment_receipt()
	_test_defeat_after_paid_startup_expires()
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
	var result := demo.terminal_result()
	equal(String(result.outcome), "complete", "successful terminal outcome survives the demo becoming inactive")
	equal(int(result.paid_casts), 2, "result retains two actual paid admissions")
	equal(int(result.paid_matter), 1_200, "result retains paid matter, not inferred free ingredients")
	equal(int(result.paid_flux), 12_000, "result reports gross paid Flux, unaffected by recovery during the run")
	equal(int(result.observed_product.id), int(product.id), "result is the actual observed product identity")
	equal(result.observed_product.source_ids, product.source_ids, "result keeps this run's exact two source IDs")
	var unrelated := Demo.new()
	unrelated._recipe_wire_id = int(product.recipe_wire_id)
	unrelated._paid_receipts.append({"source_id": 900_001})
	unrelated._paid_receipts.append({"source_id": 900_002})
	check(unrelated._matching_product(world).is_empty(), "another run cannot claim this matching recipe and quantity without its source IDs")
	equal(int(result.observed_product.cell_count), product.cells.size(), "result reports actual selected whole hexes")
	check(bool(result.weave_restored), "result confirms restoration after it has happened")
	result.observed_product.quantity = 999
	equal(int(demo.terminal_result().observed_product.quantity), 1_200, "reading the result cannot mutate its retained receipt")
	var retained := demo.terminal_result()
	check(demo.command(world) == null, "a completed demo never issues another command")
	demo.cancel(world)
	equal(demo.terminal_result(), retained, "repeat terminal commands and cancel are idempotent")
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
	var result := demo.terminal_result()
	equal(String(result.outcome), "canceled", "drained cancel is not presented as successful chemistry")
	equal(int(result.paid_casts), 1, "cancel immediately after admission still observes the paid receipt")
	equal(int(result.paid_matter), 600, "cancel card reports the actual unrefunded matter")
	check(result.observed_product.is_empty(), "one-source cancellation invents no reaction")
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
	check(not demo.has_terminal_result(), "a refused start does not fabricate a run result")


func _test_cancel_before_payment_and_invalidation() -> void:
	var world := _world(8105)
	var actor := world.player()
	var saved := _customize(actor)
	var demo := Demo.new()
	check(demo.begin(world, actor.entity_id, "water", "fire", catalog), "zero-payment cancellation fixture begins")
	demo.cancel(world)
	equal(String(demo.terminal_result().outcome), "canceled", "cancel before command is a retained canceled result")
	equal(int(demo.terminal_result().paid_casts), 0, "unissued demo reports zero paid casts")
	equal(int(demo.terminal_result().paid_flux), 0, "unissued demo reports zero paid Flux")
	_assert_restored(actor, saved, 0)
	check(demo.validate_result(world, actor.entity_id), "same practice context retains the learning card")
	check(not demo.validate_result(world, actor.entity_id, false), "modal/round/spectator eligibility invalidates the card")
	check(not demo.has_terminal_result(), "invalidated result is not merely hidden")
	check(demo.begin(world, actor.entity_id, "water", "fire", catalog), "another finite run may begin after invalidation")
	demo.cancel(world)
	check(not demo.validate_result(_world(8106), actor.entity_id), "a new world cannot inherit stale result hints")
	check(demo.begin(world, actor.entity_id, "water", "fire", catalog), "actor identity invalidation fixture begins")
	demo.cancel(world)
	check(not demo.validate_result(world, actor.entity_id + 1), "different local actor cannot inherit the prior recipe card")
	check(demo.begin(world, actor.entity_id, "water", "fire", catalog), "dismissal fixture begins")
	demo.cancel(world)
	demo.dismiss_result()
	demo.dismiss_result()
	check(demo.terminal_result().is_empty(), "dismissing twice is safe and leaves no history")
	check(demo.begin(world, actor.entity_id, "water", "fire", catalog), "new-run replacement fixture begins")
	demo.cancel(world)
	check(demo.begin(world, actor.entity_id, "earth", "earth", catalog), "a new run can replace the prior terminal card")
	check(not demo.has_terminal_result(), "a new run never shows an older result")
	demo.cancel(world)
	world.players[0] = PlayerState.new(actor.entity_id)
	check(not demo.validate_result(world, actor.entity_id), "a replacement actor with the same ID cannot inherit stale retry context")


func _test_abort_retains_paid_outcome() -> void:
	var world := _world(8107)
	var actor := world.player()
	var saved := _customize(actor)
	var demo := Demo.new()
	check(demo.begin(world, actor.entity_id, "earth", "wind", catalog), "abort receipt fixture begins")
	check(world.step([demo.command(world)]), "abort fixture has an actual paid startup")
	var paid := int(world.hex_court.metrics.matter_paid)
	var pending := actor.pending_cast_wire_id
	check(demo.command(null) == null, "world change aborts without another command")
	var result := demo.terminal_result()
	equal(String(result.outcome), "aborted", "abort is distinct from cancel and completion")
	equal(int(result.paid_casts), 1, "abort captures payment before the next normal polling phase")
	check(String(result.message).contains("world changed"), "abort retains its actual reason")
	check(result.observed_product.is_empty(), "abort before contact makes no observed-reaction claim")
	equal(int(world.hex_court.metrics.matter_paid), paid, "abort does not refund paid authority")
	equal(actor.pending_cast_wire_id, pending, "abort does not silently clear the ordinary paid startup")
	equal(actor.spell_wire_ids, saved.wires, "abort retains no temporary loaner slots")
	var state := actor.canonical_values()
	demo.cancel(null)
	check(demo.command(world) == null, "aborted controller stays inactive")
	equal(actor.canonical_values(), state, "repeat abort/cancel does not restore over later actor state")
	equal(demo.terminal_result(), result, "terminal receipt is stable until dismissed")
	check(not demo.validate_result(null, actor.entity_id), "lost world invalidates the old card")


func _test_shared_payment_receipt() -> void:
	var world := _world(8108)
	var actor := world.player()
	var peer := PlayerState.new(2)
	peer.reset_for_spawn(Demo.BENCH + Vector2i(192_000, 0))
	peer.spawn_protection_ticks = 0
	world.players.append(peer)
	var wire := int(catalog.ability(catalog.spell_id_at("earth", "bolt")).wire_id)
	check(peer.place_proven_spell(0, wire), "shared receipt peer equips an ordinary Bolt")
	var demo := Demo.new()
	check(demo.begin(world, actor.entity_id, "earth", "wind", catalog), "shared receipt fixture begins")
	var own := demo.command(world)
	var peer_target := Vector2i(peer.position_x, peer.position_y - 96_000)
	var other := SimCommand.new(world.tick, peer.entity_id, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[0]), 0, -96_000, peer_target.x, peer_target.y)
	check(world.step([own, other]), "two actors pay ordinary Bolts on the same tick")
	equal(int(world.hex_court.metrics.matter_paid), 1_200, "shared fixture has both real payments")
	check(demo._cast_was_paid(world), "the demo's receipt survives unrelated concurrent payment")
	demo.cancel(null)
	equal(int(demo.terminal_result().paid_casts), 1, "terminal outcome counts only the local demo's admitted cast")
	equal(int(demo.terminal_result().paid_matter), 600, "peer payment is excluded from result cost")


func _test_defeat_after_paid_startup_expires() -> void:
	var world := _world(8109)
	var actor := world.player()
	var original := actor.spell_wire_ids.duplicate()
	var demo := Demo.new()
	check(demo.begin(world, actor.entity_id, "earth", "wind", catalog), "defeated startup fixture begins")
	check(world.step([demo.command(world)]), "defeated startup paid through ordinary authority")
	actor.health = 0
	world.hex_court.sync_flights(world.players, world.projectiles)
	check(world.hex_court.casts.is_empty(), "normal defeat cleanup has expired the paid reservation before the demo polls")
	check(world.hex_court.conservation_valid(), "expired startup still conserves its actual paid matter")
	check(demo.command(world) == null, "defeated demo aborts without another cast")
	var result := demo.terminal_result()
	equal(String(result.outcome), "aborted", "defeat has an explicit aborted result")
	equal(int(result.paid_casts), 1, "the real cast-start event retains payment even after reservation expiry")
	equal(int(result.paid_matter), 600, "expired paid startup is not advertised as refunded")
	check(String(result.message).contains("defeated"), "result preserves the defeat reason")
	equal(actor.spell_wire_ids, original, "defeat restores the exact original weave")


func _test_six_element_admission() -> void:
	for element: String in Demo.ElementRules.IDS:
		equal(Demo._element_id(element), element, "paid pair demo accepts every canonical element")
		equal(Demo._element_id(int(Demo.ElementRules.BY_ID[element])), element, "paid demo respects sparse live element wires")
	for retired: Variant in ["ice", "charge", 5, 6, 0, 9, "unknown"]:
		equal(Demo._element_id(retired), "", "derived effects and invalid inputs cannot become independent demo elements")
	var world := _world(990)
	var demo := Demo.new()
	var before_flux := world.player().flux
	var before_weave := world.player().spell_wire_ids.duplicate()
	check(demo.begin(world, world.player().entity_id, "light", "dark", catalog), "Light plus Dark reaches the same two paid cast flow")
	check(demo.is_active(), "six-element admission retains the existing two-cast state machine")
	equal(world.player().flux, before_flux, "preparing the two legal Bolt slots cannot pre-spend Flux")
	_drive(world, demo)
	var result := demo.terminal_result()
	equal(result.get("outcome"), "complete", "newly admitted Light/Dark pair finishes through ordinary casts")
	equal(result.get("paid_casts"), 2, "six-element availability does not introduce free or extra casts")
	check(int(result.get("paid_flux", 0)) > 0, "Light/Dark consumes real paid Flux")
	equal(world.player().spell_wire_ids, before_weave, "paid demo restores the original canonical twelve positions")

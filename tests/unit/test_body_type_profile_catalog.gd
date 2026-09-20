extends FluxTestSuite


func run() -> int:
	var catalog := BodyTypeProfileCatalog.new()
	check(catalog.load_from_file(), "body-type profiles validate: %s" % catalog.last_error)
	equal(catalog.profiles.keys().size(), 3, "exactly three reusable body profiles exist")
	equal(catalog.role("small"), "skirmisher", "small champions trade reserves for tempo")
	equal(catalog.role("middle"), "adapter", "middle champions own the balanced role")
	equal(catalog.role("large"), "anchor", "large champions trade speed for staying power")
	equal(int(catalog.shared_rules.get("competitive_budget", 0)), 100, "every size uses the same competitive budget")
	equal(String(catalog.shared_rules.get("collision_radius_policy", "")), "shared_foundation_radius", "size cannot create a hidden collision advantage")
	equal(catalog.shared_rules.get("visual_template_order", []), ["small", "middle", "large"], "body templates are promoted from smallest to largest")
	var visual_heights: Dictionary = catalog.shared_rules.get("visual_template_height_pixels", {})
	equal(int(visual_heights.get("small", 0)), 58, "small body owns the compact 58px silhouette")
	equal(int(visual_heights.get("middle", 0)), 68, "middle body owns the balanced 68px silhouette")
	equal(int(visual_heights.get("large", 0)), 76, "large body owns the bounded 76px silhouette")
	equal(String(catalog.shared_rules.get("visual_size_authority", "")), "presentation_only_no_hidden_reach_evasion_or_damage", "visual size cannot grant hidden combat authority")
	var movement: Array = catalog.shared_rules.get("universal_movement", [])
	for action_id: String in ["jump", "slide", "roll", "air_dodge", "wave_dash", "wall_kick"]:
		check(movement.has(action_id), "%s remains available to every size" % action_id)
	check(catalog.accepts("small", {"health_maximum": 90000, "health_recovery_per_second": 2200, "flux_maximum": 123200, "flux_recovery_per_second": 23000, "stamina_maximum": 620000, "stamina_recovery_per_second": 28000, "movement_speed_ratio": 1060}), "S. Wayne fits the small skirmisher envelope")
	check(catalog.accepts("middle", {"health_maximum": 108000, "health_recovery_per_second": 1800, "flux_maximum": 114400, "flux_recovery_per_second": 19000, "stamina_maximum": 660000, "stamina_recovery_per_second": 30000, "movement_speed_ratio": 980}), "Oh Tipi fits the middle adapter envelope")
	check(catalog.accepts("large", {"health_maximum": 132000, "health_recovery_per_second": 1200, "flux_maximum": 105600, "flux_recovery_per_second": 17000, "stamina_maximum": 700000, "stamina_recovery_per_second": 32000, "movement_speed_ratio": 910}), "The Red Baron fits the large anchor envelope")
	var stamina_envelopes := {"small": [610000, 640000], "middle": [645000, 680000], "large": [685000, 715000]}
	for body_type: String in stamina_envelopes:
		var current: Array = catalog.profiles[body_type]["stat_bounds"]["stamina_maximum"]
		var expected: Array = stamina_envelopes[body_type]
		equal(int(current[0]), int(expected[0]), body_type + " keeps the explicit modest-reserve lower bound")
		equal(int(current[1]), int(expected[1]), body_type + " keeps the explicit modest-reserve upper bound")
	for body_type: String in BodyTypeProfileCatalog.BODY_TYPES:
		var bounds: Dictionary = (catalog.profiles[body_type] as Dictionary)["stat_bounds"]
		for stat_name: String in BodyTypeProfileCatalog.STAT_NAMES:
			var interval: Array = bounds[stat_name]
			var global_bounds: Vector2i = ChampionCatalog.STAT_BOUNDS[stat_name]
			check(int(interval[0]) >= global_bounds.x and int(interval[1]) <= global_bounds.y, "%s %s stays inside the global champion safety envelope" % [body_type, stat_name])
	var invalid := catalog.data.duplicate(true)
	((invalid["profiles"] as Dictionary)["large"] as Dictionary)["role"] = ""
	var rejected := BodyTypeProfileCatalog.new()
	rejected.data = invalid
	check(not rejected.validate(), "roleless body profile fails closed")
	for body_type: String in BodyTypeProfileCatalog.BODY_TYPES:
		equal(catalog.hurt_radius(body_type), int(BodyTypeProfileCatalog.HURT_RADII[body_type]), "each body exposes its validated combat radius")
		for invalid_radius: Variant in [0, -1, 15_000, 21_000, 100_001, 18_000.5, "17000"]:
			var malformed := catalog.data.duplicate(true)
			malformed["profiles"][body_type]["hurt_radius"] = invalid_radius
			var invalid_catalog := BodyTypeProfileCatalog.new()
			invalid_catalog.data = malformed
			check(not invalid_catalog.validate(), "malformed or out-of-profile hurt radius fails closed")
	equal(catalog.hurt_radius("unknown"), 0, "unknown bodies do not silently inherit a combat profile")
	_test_body_hurtbox_and_shared_clearance()
	return finish("body-type-profile-catalog")


func _test_body_hurtbox_and_shared_clearance() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "hurtbox audit uses the live ability catalog")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "hurtbox audit uses every live champion")
	equal(champions.ordered_champion_ids().size(), 30, "all named current champions participate in body hurtbox proof")
	equal(MovementTuning.PLAYER_RADIUS, 18_000, "shared wall clearance remains exactly eighteen pixels")
	var collision := CollisionWorld.new(500_000, 500_000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, 300_000, 100_000, 320_000, 300_000))
	var center := Vector2i(200_000, 200_000)
	var bodies: Dictionary = {}
	var projectile := ProjectileState.new(1000, 999, 2, 101, 2, Vector2i.ZERO, Vector2i.ZERO, 5_000, 1_000, 10)
	for champion_id: String in champions.ordered_champion_ids():
		var actor := PlayerState.new(2)
		actor.team_id = 2
		check(champions.apply_to_player(actor, champion_id), champion_id + " applies its genuine body/core-stat profile")
		var body_type := String(champions.champion(champion_id).body_type)
		bodies[body_type] = true
		var expected_radius := int({"small": 17_000, "middle": 18_000, "large": 19_000}[body_type])
		actor.reset_for_spawn(center)
		equal(actor.radius, expected_radius, champion_id + " spawn preserves its fixed body hurt radius")
		# Test geometry independently of immunity/height eligibility. A dodge or
		# airborne clearance may reject damage, but never resizes the hurt circle.
		# Serialized legacy enum aliases are included without claiming they activate.
		for mode: int in PlayerState.MovementMode.values():
			actor.movement_mode = mode
			equal(actor.radius, expected_radius, champion_id + " mode cannot substitute animated dimensions for fixed hurt radius")
			actor.position_x = center.x
			actor.position_y = center.y
			actor.velocity_x = 24_000_000
			actor.velocity_y = 0
			MovementSystem._integrate(actor, SimConfig.new(120), collision)
			equal(Vector2i(actor.position_x, actor.position_y), Vector2i(282_000, 200_000), "production movement of every body/mode stops at the same exact worldbone face")
			check(collision.can_occupy(Vector2i(282_000, 200_000), MovementTuning.PLAYER_RADIUS), "all bodies may touch the same eighteen-pixel wall clearance")
			check(not collision.can_occupy(Vector2i(282_001, 200_000), MovementTuning.PLAYER_RADIUS), "all bodies reject one fixed-point unit of wall penetration")
			actor.position_x = center.x
			actor.position_y = center.y
			for facing: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				actor.facing_x = facing.x
				actor.facing_y = facing.y
				projectile.previous_x = center.x - 50_000
				projectile.position_x = center.x + 50_000
				projectile.previous_y = center.y + expected_radius + projectile.radius
				projectile.position_y = projectile.previous_y
				check(CombatSystem._segment_circle_hit(projectile, actor, actor.radius + projectile.radius), "every champion/mode/facing hits at its exact body-specific projectile tangent")
				projectile.previous_y += 1
				projectile.position_y += 1
				check(not CombatSystem._segment_circle_hit(projectile, actor, actor.radius + projectile.radius), "one unit outside the fixed body-specific boundary misses")
		# Actual movement integration also leaves radius unchanged while the
		# character walks, sprints, jumps and attempts paid airborne transitions.
		for tick: int in range(72):
			var pressed := SimCommand.PRESSED_JUMP if tick in [12, 32] else (SimCommand.PRESSED_EVADE if tick == 44 else 0)
			var held := SimCommand.HELD_SPRINT | (SimCommand.HELD_JUMP if tick >= 12 and tick < 40 and tick != 31 else 0)
			MovementSystem.step(actor, SimCommand.new(tick, 2, 0, 1000, held, pressed, 0, 1000), SimConfig.new(120), collision)
			equal(actor.radius, expected_radius, champion_id + " production movement never changes hurtbox size")
		actor.reset_for_spawn(center)
		var source := SimWorld.new(120, 7, collision)
		# Real damage distinguishes both one-pixel body steps: a 5px bolt at
		# 22.5px misses Small; at 23.5px only Large takes damage.
		for offset: int in [22_500, 23_500]:
			actor.reset_for_spawn(center)
			var incoming := ProjectileState.new(1001, 99, 1, CombatTuning.CINDERBOLT_WIRE_ID, 2, center + Vector2i(-50_000, offset), Vector2i(12_000_000, 0), 5_000, 1_000, 10)
			var hit_events: Array[Dictionary] = []
			var health_before := actor.health
			CombatSystem.advance_projectiles([incoming], [actor], SimConfig.new(120), collision, hit_events)
			var should_hit := expected_radius + incoming.radius >= offset
			equal(health_before - actor.health, 1_000 if should_hit else 0, "actual combat distinguishes each modest body hurt-circle step")
		for aim: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			actor.pending_cast_aim_x = aim.x
			actor.pending_cast_aim_y = aim.y
			var release_events: Array[Dictionary] = []
			var definition := CombatTuning.cast_definition(CombatTuning.CINDERBOLT_WIRE_ID)
			var released := CombatSystem._release_projectiles(actor, CombatTuning.CINDERBOLT_WIRE_ID, 1100, definition, SimConfig.new(120), collision, release_events)
			equal(released.size(), 1, "every body releases its single lane with common origin clearance")
			if not released.is_empty():
				var distance := MovementTuning.PLAYER_RADIUS + int(definition["radius"]) + CombatTuning.PROJECTILE_SPAWN_CLEARANCE
				@warning_ignore("integer_division")
				var expected_origin := center + Vector2i(aim.x * distance / 1000, aim.y * distance / 1000)
				equal(Vector2i(released[0].position_x, released[0].position_y), expected_origin, "hurt size never grants projectile reach or changes any of eight cast origins")
		actor.reset_for_spawn(center)
		check(champions.apply_to_player(source.player(), champions.default_champion_id), "snapshot host also uses a validated live champion")
		source.players.append(actor)
		var before_hash := source.state_hash()
		actor.radius += 1
		check(source.state_hash() != before_hash, "combat hurt radius participates in the canonical simulation hash")
		actor.radius = expected_radius
		var snapshot := SessionSnapshot.capture(source, {1: "Host", 2: champion_id})
		check(SessionSnapshot.validate(snapshot), "all body-specific radii fit the unchanged validated snapshot layout")
		var replica := SimWorld.new(120, 7, collision)
		check(SessionSnapshot.apply_to_world(snapshot, replica), "actual host snapshot restores the body hurt circle")
		if replica.player(2) != null:
			equal(replica.player(2).radius, expected_radius, "remote combat radius survives snapshot round-trip")
		var packet := ClientPrediction.capture_packet(actor, 0, -1)
		check(not packet.is_empty(), "all body-specific radii fit existing prediction safety bounds")
		var restored := ClientPrediction.restore_state(packet.get("values", PackedInt64Array()))
		check(restored != null, "prediction restores the complete movement state")
		if restored != null:
			equal(restored.radius, expected_radius, "prediction clone preserves combat radius without deriving identity")
			actor.radius = 99_000
			equal(restored.radius, expected_radius, "restored combat radius is independent of later source mutation")
	equal(bodies.size(), 3, "all three distinct combat radii retain common physical clearance")

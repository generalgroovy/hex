extends SceneTree



const SUITES: Array[Script] = [
	preload("res://tests/unit/test_completed_step_profile.gd"),
	preload("res://tests/unit/test_cast_startup_witness.gd"),
	preload("res://tests/unit/test_defeated_pending_capture.gd"),
	preload("res://tests/unit/test_projectile_speed_policy.gd"),
	preload("res://tests/unit/test_movement_route_decisions.gd"),
	preload("res://tests/network/test_network_impairment.gd"),
	preload("res://tests/unit/test_diagnostic_replay.gd"),
	preload("res://tests/unit/test_perk_benefit_audit.gd"),
	preload("res://tests/replay/test_current_world_replay.gd"),
	preload("res://tests/unit/test_spell_inspector.gd"),
	preload("res://tests/unit/test_session_admission_deadline.gd"),
	preload("res://tests/unit/test_signature_recovery.gd"),
	preload("res://tests/unit/test_signature_rival.gd"),
	preload("res://tests/unit/test_district_practice_coach.gd"),
	preload("res://tests/unit/test_hex_render_polygon_cache.gd"),
	preload("res://tests/unit/test_projectile_surface_depth.gd"),
	preload("res://tests/unit/test_wellspring_environment_details.gd"),
	preload("res://tests/unit/test_paid_field_rendering.gd"),
	preload("res://tests/unit/test_movement_hot_path.gd"),
	preload("res://tests/unit/test_sim_empty_work.gd"),
	preload("res://tests/unit/test_character_page_residency.gd"),
	preload("res://tests/unit/test_performance_presentation.gd"),
	preload("res://tests/unit/test_hex_stone_floor.gd"),
	preload("res://tests/unit/test_wellspring_terrain_stream.gd"),
	preload("res://tests/unit/test_wellspring_async_terrain_stream.gd"),
	preload("res://tests/unit/test_retained_campus_canvas.gd"),
	preload("res://tests/unit/test_range_target_scenario.gd"),
	preload("res://tests/unit/test_hex_avoidance_feedback.gd"),
	preload("res://tests/unit/test_element_garden_exhibition.gd"),
	preload("res://tests/unit/test_large_world_rendering.gd"),
	preload("res://tests/unit/test_local_navigation.gd"),
	preload("res://tests/unit/test_wellspring_map.gd"),
	preload("res://tests/unit/test_expanded_spell_network.gd"),
	preload("res://tests/unit/test_elemental_spell_expansion.gd"),
	preload("res://tests/unit/test_element_delivery_presentation.gd"),
	preload("res://tests/unit/test_signature_progression.gd"),
	preload("res://tests/unit/test_spell_testing_tools.gd"),
	preload("res://tests/unit/test_wallrun_presentation.gd"),
	preload("res://tests/unit/test_six_element_protocol.gd"),
	preload("res://tests/unit/test_hex_six_element_reactions.gd"),
	preload("res://tests/unit/test_six_element_cadence.gd"),
	preload("res://tests/unit/test_pixel_aerial_pose.gd"),
	preload("res://tests/unit/test_identity_perks.gd"),
	preload("res://tests/unit/test_character_movement_trail.gd"),
	preload("res://tests/unit/test_balance_audit.gd"),
	preload("res://tests/unit/test_demo_result_integration.gd"),
	preload("res://tests/unit/test_team_replication.gd"),
	preload("res://tests/unit/test_team_round.gd"),
	preload("res://tests/unit/test_team_match_presentation.gd"),
	preload("res://tests/unit/test_hex_demo_result_card.gd"),
	preload("res://tests/unit/test_hex_round_result.gd"),
	preload("res://tests/unit/test_session_round_label.gd"),
	preload("res://tests/unit/test_pov_terrain_context.gd"),
	preload("res://tests/unit/test_solo_duel_rival.gd"),
	preload("res://tests/unit/test_solo_duel_trial_panel.gd"),
	preload("res://tests/unit/test_solo_duel_world_tell.gd"),
	preload("res://tests/unit/test_solo_duel_trial.gd"),
	preload("res://tests/unit/test_solo_trial_process.gd"),
	preload("res://tests/unit/test_hex_projectile_facets.gd"),
	preload("res://tests/unit/test_hex_cast_release.gd"),
	preload("res://tests/unit/test_hex_contact_punctuation.gd"),
	preload("res://tests/unit/test_hex_material_surface.gd"),
	preload("res://tests/unit/test_spell_loom_input_handoff.gd"),
	preload("res://tests/unit/test_landing_airborne_contact.gd"),
	preload("res://tests/unit/test_pixel_cast_continuity.gd"),
	preload("res://tests/unit/test_hex_canonical_cell_rows.gd"),
	preload("res://tests/unit/test_spell_binding_labels.gd"),
	preload("res://tests/unit/test_character_attunement_recovery.gd"),
	preload("res://tests/unit/test_hex_owned_capture.gd"),
	preload("res://tests/unit/test_owned_publication.gd"),
	preload("res://tests/unit/test_hex_capture_callback_safety.gd"),
	preload("res://tests/unit/test_hex_canonical_topology_bytes.gd"),
	preload("res://tests/unit/test_hex_chemistry_prepare.gd"),
	preload("res://tests/unit/test_session_receive_freshness.gd"),
	preload("res://tests/unit/test_world_envelope_metadata.gd"),
	preload("res://tests/unit/test_session_broadcast_bytes.gd"),
	preload("res://tests/unit/test_hex_collision_topology.gd"),
	preload("res://tests/unit/test_hex_strict_wire_decode.gd"),
	preload("res://tests/unit/test_hex_cell_storage.gd"),
	preload("res://tests/unit/test_hex_sealed_snapshot.gd"),
	preload("res://tests/unit/test_hex_producer_topology_reuse.gd"),
	preload("res://tests/unit/test_world_publication_edges.gd"),
	preload("res://tests/unit/test_pixel_descriptor_reuse.gd"),
	preload("res://tests/unit/test_world_publication.gd"),
	preload("res://tests/unit/test_hex_immutable_topology_candidate.gd"),
	preload("res://tests/unit/test_hex_new_ground_workset.gd"),
	preload("res://tests/unit/test_character_viewport_policy.gd"),
	preload("res://tests/unit/test_pixel_action_bank.gd"),
	preload("res://tests/unit/test_hex_combat_labels.gd"),
	preload("res://tests/unit/test_pixel_cast.gd"),
	preload("res://tests/unit/test_pixel_flipbook_presenter.gd"),
	preload("res://tests/unit/test_hex_pressure_headroom.gd"),
	preload("res://tests/unit/test_hex_contact_workset.gd"),
	preload("res://tests/unit/test_hex_environment_layout.gd"),
	preload("res://tests/unit/test_player_camera_rig.gd"),
	preload("res://tests/unit/test_wellspring_service_buildings.gd"),
	preload("res://tests/unit/test_wellspring_service_directory.gd"),
	preload("res://tests/unit/test_building_directory_integration.gd"),
	preload("res://tests/unit/test_hex_sparse_storage.gd"),
	preload("res://tests/unit/test_fullbody_cast.gd"),
	preload("res://tests/unit/test_movement_checkpoint1.gd"),
	preload("res://tests/unit/test_movement_checkpoint1_integration.gd"),
	preload("res://tests/unit/test_movement_checkpoint1_visuals.gd"),
	preload("res://tests/unit/test_movement_checkpoint1_ground.gd"),
	preload("res://tests/unit/test_hex_render_frame.gd"),
	preload("res://tests/unit/test_hex_hash_specialization.gd"),
	preload("res://tests/unit/test_hex_water_pilot.gd"),
	preload("res://tests/unit/test_hex_clash_feedback.gd"),
	preload("res://tests/unit/test_hex_snapshot_optimization.gd"),
	preload("res://tests/unit/test_hex_branding.gd"),
	preload("res://tests/unit/test_hex_steam_occupation.gd"),
	preload("res://tests/unit/test_hex_handoff_presentation.gd"),
	preload("res://tests/unit/test_session_transport_admin_close_delivery.gd"),
	preload("res://tests/unit/test_hex_chemistry_knockouts.gd"),
	preload("res://tests/unit/test_hex_canonical_sort.gd"),
	preload("res://tests/unit/test_unified_reconciliation_order.gd"),
	preload("res://tests/unit/test_unified_enet.gd"),
	preload("res://tests/unit/test_hex_playground_panel.gd"),
	preload("res://tests/unit/test_hex_playground_demo.gd"),
	preload("res://tests/unit/test_unified_prediction.gd"),

	preload("res://tests/unit/test_hex_optics.gd"),
	preload("res://tests/unit/test_hex_trail_emitter.gd"),
	preload("res://tests/unit/test_unified_authoritative_session.gd"),
	preload("res://tests/unit/test_hex_actor_compat.gd"),
	preload("res://tests/unit/test_world_snapshot_envelope.gd"),
	preload("res://tests/unit/test_unified_hex_paid_matrix.gd"),
	preload("res://tests/unit/test_partitioned_strength_budget.gd"),
	preload("res://tests/unit/test_hex_cast_parts.gd"),
	preload("res://tests/unit/test_hex_recipe_policy.gd"),
	preload("res://tests/unit/test_hex_product_effects.gd"),
	preload("res://tests/unit/test_hex_shared_presenter.gd"),
	preload("res://tests/unit/test_hex_world_snapshot.gd"),
	preload("res://tests/unit/test_hex_authored_shapes.gd"),
	preload("res://tests/unit/test_hex_collision_world.gd"),
	preload("res://tests/unit/test_hex_chemistry_snapshot.gd"),
	preload("res://tests/unit/test_hex_world_definition.gd"),
	preload("res://tests/unit/test_hex_shared_authority.gd"),
	preload("res://tests/unit/test_hex_selection.gd"),
	preload("res://tests/unit/test_hex_whole_coverage.gd"),
	preload("res://tests/unit/test_character_weave_library.gd"),
	preload("res://tests/unit/test_character_weave_policy.gd"),
	preload("res://tests/unit/test_character_weave_integration.gd"),
	preload("res://tests/unit/test_weave_acknowledgement.gd"),

	preload("res://tests/unit/test_hex_field_interception.gd"),
	preload("res://tests/unit/test_hex_strength.gd"),
	preload("res://tests/unit/test_hex_projectile_combat.gd"),
	preload("res://tests/unit/test_strength_budget.gd"),
	preload("res://tests/unit/test_projectile_contact_order.gd"),
	preload("res://tests/unit/test_continuous_contact.gd"),
	preload("res://tests/unit/test_hex_footprint.gd"),
	preload("res://tests/unit/test_hex_court_presenter.gd"),
	preload("res://tests/unit/test_character_starter_kit.gd"),
	preload("res://tests/unit/test_hex_grid.gd"),
	preload("res://tests/unit/test_hex_court.gd"),
	preload("res://tests/unit/test_hex_chemistry.gd"),
	preload("res://tests/unit/test_spray_interception.gd"),
	preload("res://tests/unit/test_spray_contact_geometry.gd"),
	preload("res://tests/unit/test_interception_practice.gd"),
	preload("res://tests/unit/test_interception_feedback.gd"),
	preload("res://tests/unit/test_session_feedback_notice.gd"),
	preload("res://tests/unit/test_runtime_build_identity.gd"),
	preload("res://tests/unit/test_bootstrap_catch_up.gd"),
	preload("res://tests/unit/test_controls_round_trip.gd"),
	preload("res://tests/unit/test_authoritative_session.gd"),
	preload("res://tests/unit/test_action_transition_policy.gd"),
	preload("res://tests/integration/test_conservatory_route.gd"),
	preload("res://tests/unit/test_ability_content.gd"),
	preload("res://tests/unit/test_loadout_definition.gd"),
	preload("res://tests/unit/test_combat_definition_table.gd"),
	preload("res://tests/unit/test_champion_catalog.gd"),
	preload("res://tests/unit/test_champion_roster_plan.gd"),
	preload("res://tests/unit/test_character_overview_model.gd"),
	preload("res://tests/unit/test_character_selection_model.gd"),
	preload("res://tests/unit/test_character_selection_grid.gd"),
	preload("res://tests/unit/test_champion_portrait_library.gd"),
	preload("res://tests/unit/test_character_gallery_integration.gd"),
	preload("res://tests/unit/test_movement_guide_model.gd"),
	preload("res://tests/unit/test_movement_practice_coach.gd"),
	preload("res://tests/unit/test_practice_coach_integration.gd"),
	preload("res://tests/unit/test_player_compendium.gd"),
	preload("res://tests/unit/test_runtime_content_summary.gd"),
	preload("res://tests/unit/test_body_type_profile_catalog.gd"),
	preload("res://tests/unit/test_control_binding_editor.gd"),
	preload("res://tests/unit/test_spell_loom_editor.gd"),
	preload("res://tests/unit/test_combat.gd"),
	preload("res://tests/unit/test_four_delivery_admission.gd"),
	preload("res://tests/unit/test_reaction_strength_provenance.gd"),
	preload("res://tests/unit/test_collision_broadphase.gd"),
	preload("res://tests/unit/test_training_target_system.gd"),
	preload("res://tests/unit/test_elemental_bursts.gd"),
	preload("res://tests/unit/test_spell_delivery_expansion.gd"),
	preload("res://tests/unit/test_projectile_chemistry_integration.gd"),
	preload("res://tests/unit/test_reaction_catalog.gd"),
	preload("res://tests/unit/test_element_chemistry.gd"),
	preload("res://tests/unit/test_rampart_movement.gd"),
	preload("res://tests/unit/test_frostway_movement.gd"),
	preload("res://tests/unit/test_capacitor_movement.gd"),
	preload("res://tests/unit/test_capacitor_integration.gd"),
	preload("res://tests/unit/test_element_trails.gd"),
	preload("res://tests/unit/test_element_audio.gd"),
	preload("res://tests/unit/test_chemistry_practice_coach.gd"),
	preload("res://tests/unit/test_core.gd"),
	preload("res://tests/unit/test_canonical_bytes.gd"),
	preload("res://tests/unit/test_environment_kit_manifest.gd"),
	preload("res://tests/unit/test_visual_language.gd"),
	preload("res://tests/unit/test_element_glyph_renderer.gd"),
	preload("res://tests/unit/test_visual_accessibility_filter.gd"),
	preload("res://tests/unit/test_eight_direction_resolver.gd"),
	preload("res://tests/unit/test_compact_combat_hud.gd"),
	preload("res://tests/unit/test_wellspring_interaction_presenter.gd"),
	preload("res://tests/unit/test_cartoon_champion_presenter.gd"),
	preload("res://tests/unit/test_minimal_champion_motion.gd"),
	preload("res://tests/unit/test_natural_map_kit.gd"),
	preload("res://tests/unit/test_wellspring_wayfinding.gd"),
	preload("res://tests/unit/test_wellspring_environment_kit.gd"),
	preload("res://tests/unit/test_wellspring_architecture_kit.gd"),
	preload("res://tests/unit/test_wellspring_illustrated_kit.gd"),
	preload("res://tests/unit/test_foundation_spell_presenter.gd"),
	preload("res://tests/unit/test_heavy_blast_presenter.gd"),
	preload("res://tests/unit/test_spell_animation_skeleton_library.gd"),
	preload("res://tests/unit/test_burst_projectile_presenter.gd"),
	preload("res://tests/unit/test_element_chemistry_presenter.gd"),
	preload("res://tests/unit/test_pixel_magic_library.gd"),
	preload("res://tests/unit/test_pixel_effect_geometry.gd"),
	preload("res://tests/unit/test_pixel_map_library.gd"),
	preload("res://tests/unit/test_pixel_assets_export.gd"),
	preload("res://tests/unit/test_hub_definition.gd"),
	preload("res://tests/unit/test_input_router.gd"),
	preload("res://tests/unit/test_jump_presentation.gd"),
	preload("res://tests/unit/test_actor_motion_history.gd"),
	preload("res://tests/unit/test_landing_presentation.gd"),
	preload("res://tests/unit/test_material_content.gd"),
	preload("res://tests/unit/test_material_grid.gd"),
	preload("res://tests/unit/test_player_preferences.gd"),
	preload("res://tests/unit/test_sanctum_campus_layout.gd"),
	preload("res://tests/unit/test_sanctum_station_model.gd"),
	preload("res://tests/unit/test_session_transport.gd"),
	preload("res://tests/unit/test_lan_lobby.gd"),
	preload("res://tests/unit/test_session_steward.gd"),
	preload("res://tests/unit/test_spectator_focus.gd"),
	preload("res://tests/unit/test_session_charter.gd"),
	preload("res://tests/unit/test_session_hearth.gd"),
	preload("res://tests/unit/test_session_round.gd"),
	preload("res://tests/unit/test_session_snapshot.gd"),
	preload("res://tests/unit/test_client_prediction.gd"),
	preload("res://tests/unit/test_session_request_policy.gd"),
	preload("res://tests/unit/test_sanctum_runtime_kit.gd"),
	preload("res://tests/unit/test_sight_occlusion.gd"),
	preload("res://tests/unit/test_pov_presentation.gd"),
	preload("res://tests/unit/test_wireframe_body_presenter.gd"),
	preload("res://tests/unit/test_movement_response.gd"),
	preload("res://tests/unit/test_movement.gd"),
	preload("res://tests/unit/test_movement_revision.gd"),
	preload("res://tests/unit/test_movement_overhaul.gd"),
	preload("res://tests/unit/test_movement_height.gd"),
	preload("res://tests/unit/test_movement_float.gd"),
	preload("res://tests/unit/test_movement_practice_trace.gd"),
	preload("res://tests/unit/test_player_resources.gd"),
	preload("res://tests/unit/test_skeleton_animation_library.gd"),
	preload("res://tests/unit/test_visual_asset_registry.gd"),
	preload("res://tests/unit/test_image_asset_inspector.gd"),
	preload("res://tests/unit/test_wellspring_character_sprite.gd"),
	preload("res://tests/unit/test_complete_visual_catalog.gd"),
	preload("res://tests/unit/test_wellspring_visual_catalog.gd"),
	preload("res://tests/replay/test_replay.gd"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suites_by_id := _suite_registry()
	if suites_by_id.is_empty():
		print("FAIL: test suite registry is empty or contains duplicate IDs")
		quit(1)
		return
	if _should_list_suites():
		for suite_id: String in suites_by_id:
			print(suite_id)
		print("PASS: listed %d stable FLUX2 suite IDs" % suites_by_id.size())
		quit(0)
		return
	var requested_ids := _requested_suite_ids()
	for requested_id: String in requested_ids:
		if not suites_by_id.has(requested_id):
			print("FAIL: unknown test suite ID: %s" % requested_id)
			print("Available suite IDs: %s" % ",".join(suites_by_id.keys()))
			quit(2)
			return
	var failures: int = 0
	var executed: int = 0
	for suite_id: String in suites_by_id:
		if not requested_ids.is_empty() and suite_id not in requested_ids:
			continue
		var suite_script: Script = suites_by_id[suite_id]
		if not suite_script.can_instantiate():
			failures += 1
			print("FAIL: test suite script cannot instantiate: ", suite_id, " (", suite_script.resource_path, ")")
			continue
		var suite: FluxTestSuite = suite_script.new()
		if suite == null:
			failures += 1
			print("FAIL: test suite constructor returned null: ", suite_id, " (", suite_script.resource_path, ")")
			continue
		executed += 1
		var suite_started_usec := Time.get_ticks_usec()
		failures += suite.run()
		print("SUITE TIMING: %s %d ms" % [suite_id, (Time.get_ticks_usec() - suite_started_usec) / 1000])
	if failures == 0:
		if requested_ids.is_empty():
			print("PASS: all FLUX2 headless suites")
		else:
			print("PASS: %d selected FLUX2 headless suite(s): %s" % [executed, ",".join(requested_ids)])
		quit(0)
	else:
		print("FAIL: %d assertion(s) failed" % failures)
		quit(1)


func _suite_registry() -> Dictionary:
	var result: Dictionary = {}
	for suite_script: Script in SUITES:
		var suite_id := _suite_id(suite_script)
		if suite_id.is_empty() or result.has(suite_id):
			return {}
		result[suite_id] = suite_script
	return result


func _suite_id(suite_script: Script) -> String:
	var filename := suite_script.resource_path.get_file().trim_suffix(".gd")
	return filename.trim_prefix("test_").replace("_", "-")


func _requested_suite_ids() -> Array[String]:
	var result: Array[String] = []
	var environment_selection := OS.get_environment("FLUX2_TEST_SUITES")
	if not environment_selection.is_empty():
		_append_suite_ids(result, environment_selection)
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--suite="):
			continue
		_append_suite_ids(result, argument.trim_prefix("--suite="))
	return result


func _append_suite_ids(result: Array[String], encoded_ids: String) -> void:
	for raw_id: String in encoded_ids.split(",", false):
		var suite_id := raw_id.strip_edges().to_lower()
		if not suite_id.is_empty() and suite_id not in result:
			result.append(suite_id)


func _should_list_suites() -> bool:
	return OS.get_environment("FLUX2_TEST_MODE") == "list" \
		or OS.get_cmdline_user_args().has("--list-suites")


extends FluxTestSuite


const Compendium = preload("res://src/presentation/player_compendium.gd")
const ChemistryGuide = preload("res://src/presentation/chemistry_guide_model.gd")
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const HexPolicy = preload("res://src/sim/hex/hex_recipe_policy.gd")


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "compendium ability catalog loads")
	var spell_help := " ".join(Compendium.spell_catalog_lines())
	check(spell_help.contains("Fresh presses win") and spell_help.contains("lowest position wins"), "spell help teaches predictable fresh and held chord priority")
	check(spell_help.contains("Rapid 1440 / 1, Bolt 1260 / 5, Heavy 180 / 15") and spell_help.contains("HP damage is a separate value") and spell_help.contains("Field slows never increase power"), "spell comparison reports current tuned speed and clash strength while keeping damage separate from field slows")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "compendium champion catalog loads")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "compendium planned roster loads")
	var panel := Compendium.new()
	check(panel.configure(champions, roster), "compendium uses validated source models")
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"jump"] = KEY_J
	panel.open_panel(Compendium.MOVEMENT, preferences)
	check(panel.is_open, "open exposes reading state")
	equal(panel.row_count(), 16, "all active movement techniques are reachable")
	equal(panel.visible_row_indices().size(), 10, "row page stays comfortably bounded")
	panel.move_row(2)
	check(" ".join(panel.detail_paragraphs()).contains("Press J") and " ".join(panel.detail_paragraphs()).contains("release to launch"), "live guide resolves rebound press/release controls")
	panel.move_row(100)
	equal(panel.selected_row, 15, "row selection cannot exceed catalog")
	equal(panel.visible_row_indices(), [10, 11, 12, 13, 14, 15], "last page exposes remaining techniques")
	panel.move_row(-100)
	equal(panel.selected_row, 0, "row selection cannot underflow")
	var live_state := PlayerState.new(1)
	live_state.movement_chain_count = 3
	live_state.movement_chain_reset_ticks = 1
	panel.refresh_status(live_state)
	check(" ".join(panel.summary).contains("Next premium: 30%"), "open guide explains current chain premium")
	live_state.movement_chain_reset_ticks = 0
	panel.refresh_status(live_state)
	check(" ".join(panel.summary).contains("Next premium: 0%"), "guide updates when shared-world chain expires while reading")
	var font := ThemeDB.fallback_font
	for row: int in range(panel.row_count()):
		panel.selected_row = row
		var all_lines: Array[String] = []
		for paragraph: String in panel.detail_paragraphs():
			all_lines.append_array(Compendium.wrap_text(paragraph, font, Compendium.DETAIL_WIDTH))
		var paged_lines: Array[String] = []
		for page: int in range(panel.detail_pages(font)):
			panel.detail_page = page
			var lines: Array[String] = panel.visible_detail_lines(font)
			check(lines.size() <= Compendium.LINES_PER_PAGE, "movement detail page never overflows vertically")
			paged_lines.append_array(lines)
			_assert_widths(lines, font, Compendium.DETAIL_WIDTH)
		equal(paged_lines, all_lines, "all skill paragraphs survive pagination in order")
	var stubborn := "VeryLongUnbrokenReboundControllerButtonName123456789"
	var split := Compendium.wrap_text(stubborn, font, 60)
	_assert_widths(split, font, 60)
	equal("".join(split), stubborn, "long bind names wrap without truncation or lost characters")
	panel.handle_event(_key(KEY_TAB), font)
	equal(panel.tab, Compendium.CHARACTERS, "Tab changes section")
	equal(panel.selected_row, 0, "tab starts with alphabetical first race")
	equal(panel.row_count(), 21, "all race rows are reachable")
	var seen := 0
	for row: int in range(panel.row_count()):
		panel.selected_row = row
		panel.selected_character = 0
		var entries: Array = panel.overview["rows"][row]["champions"]
		if entries.is_empty():
			equal(panel.character_title(), "Race awaiting a champion", "only an empty race receives an empty title")
		for character: int in range(entries.size()):
			panel.selected_character = character
			seen += 1
			var entry: Dictionary = entries[character]
			check(panel.character_title().contains(String(entry["display_name"])), "single and multiple-character races preserve the selected name in the title")
			var paragraphs := panel.detail_paragraphs()
			check(not paragraphs.is_empty(), "every character has a readable record")
			var combined := " ".join(paragraphs)
			if "wind" in entry["affinities"]:
				check(combined.contains("Air %s" % str((entry["affinity_points"] as Dictionary).get("wind", 0))), "compendium renders the wind affinity with its player-facing Air label")
			if bool(entries[character]["stats_available"]):
				for obsolete: String in ["no unique ability", "no unique racial passive", "no race bonus", "race-bonus claim"]:
					check(not combined.to_lower().contains(obsolete), "compendium cannot deny the working identity perks: %s / %s" % [entry.id, obsolete])
				for scope: String in ["race", "character"]:
					var perk: Dictionary = entry.identity_perks[scope]
					for field: String in ["name", "summary", "window", "counter"]:
						check(combined.contains(String(perk[field])), "compendium retains complete %s perk %s for %s" % [scope, field, entry.id])
				check(combined.contains("Health") and combined.contains("Flux") and combined.contains("Stamina") and combined.contains("Walk speed"), "playable record exposes every stat family")
				check(combined.contains("Hurtbox radius: %d px" % (champions.body_type_profiles.hurt_radius(String(entries[character]["body_type"])) / 1000)), "compendium exposes source-derived combat footprint")
				check(combined.contains("Wall clearance: 18 px for every size"), "compendium distinguishes navigation clearance from hurtbox")
			else:
				check(combined.contains("cannot be selected") and not combined.contains("Health "), "planned record cannot imply fabricated playable stats")
			for page: int in range(panel.detail_pages(font)):
				panel.detail_page = page
				_assert_widths(panel.visible_detail_lines(font), font, Compendium.DETAIL_WIDTH)
	equal(seen, roster.ordered_ids.size(), "all current identities are accessible without a stale fixed cast count")
	panel.set_tab(Compendium.CHARACTERS)
	panel.move_character(-1)
	check(panel.selected_character >= 0, "character cycle never underflows")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	check(panel.handle_event(wheel, font), "wheel is consumed by reading overlay")
	equal(panel.selected_row, 1, "wheel navigates rows without a movement command")
	panel.handle_event(_key(KEY_PAGEDOWN), font)
	check(panel.detail_page < panel.detail_pages(font), "detail paging remains within content")
	panel.handle_event(_joy(JOY_BUTTON_LEFT_SHOULDER), font)
	equal(panel.tab, Compendium.MOVEMENT, "controller shoulder changes section")
	panel.handle_event(_joy(JOY_BUTTON_DPAD_DOWN), font)
	equal(panel.selected_row, 1, "controller d-pad moves row")
	panel.handle_event(_joy(JOY_BUTTON_BACK), font)
	check(not panel.is_open, "controller Back closes before any underlying action")
	check(not panel.handle_event(_key(KEY_DOWN), font), "closed overlay does not consume input")
	panel.open_panel(Compendium.MOVEMENT, preferences)
	panel.handle_event(_key(KEY_ESCAPE), font)
	check(not panel.is_open, "Escape closes overlay")
	var spell_copy := " ".join(Compendium.spell_catalog_lines())
	check(spell_copy.contains("surviving paid pulse leaves one finite terminal ingredient") and spell_copy.contains("ground target within reach"), "spell-family page teaches surviving Spray matter")
	check(spell_copy.contains("catches weaker Rapid") and spell_copy.contains("stronger Bolt or Heavy stops the pulse"), "spell-family page teaches only the current unequal Spray interception")
	check(spell_copy.contains("Unified Wellspring uses finite strength subtraction") and spell_copy.contains("surviving matter keeps only its paid remainder"), "spell-family page teaches the shared finite authority without reviving the legacy split")
	check(spell_copy.contains("two distinct paid sources") and spell_copy.contains("eligible clash") and spell_copy.contains("field contact") and spell_copy.contains("overlapping deposited matter"), "spell-family page names every current product trigger without reducing reactions to deposits")
	_test_chemistry(panel, preferences, font)
	_test_compact_overviews(panel, preferences, font)
	_test_selected_chemistry_details(panel, preferences, font)
	_test_first_ten_policy_copy()
	_test_current_link_and_vortex_guidance()
	_test_controller_and_physical_navigation(panel, preferences, font)
	return finish("player-compendium")


func _test_compact_overviews(panel: RefCounted, preferences: PlayerPreferences, font: Font) -> void:
	panel.open_panel(Compendium.MOVEMENT, preferences)
	check(panel.compact_overview(), "Movement opens with the all-technique table")
	for row: int in range(panel.movement_rows.size()):
		var rectangle := Compendium.movement_overview_rect(row)
		check(Compendium.PANEL.encloses(rectangle), "all sixteen movement rows fit inside the panel")
		if row > 0:
			check(not rectangle.intersects(Compendium.movement_overview_rect(row - 1)), "movement rows do not overlap")
		check(panel.overview_hit(rectangle.get_center()), "every compact movement row is pointer reachable")
		equal(panel.selected_row, row, "compact row selects exact source entry")
		var cells := MovementGuideModel.compact_cells(panel.movement_rows[row])
		equal(cells.size(), 6, "movement overview has six comparable columns")
		equal(cells[1], panel.movement_rows[row].binding, "compact input remains the current actual binding")
		equal(cells[2].to_float(), float(panel.movement_rows[row].cost_milli) / 1000.0, "compact start cost matches source units")
		equal(cells[3].trim_suffix("/s").to_float(), float(panel.movement_rows[row].sustain_milli_per_second) / 1000.0, "compact sustain matches source units")
		for line: String in panel.compact_summary(font):
			check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= 1136.01, "compact summary fits its exact visible width")
	panel.selected_row = 2
	check(MovementGuideModel.compact_cells(panel.movement_rows[2])[1].contains("J"), "compact jump respects user rebind")
	equal(MovementGuideModel.compact_cells(panel.movement_rows[2])[4], "Height clearance", "jump table distinguishes physical clearance from timed immunity")
	panel.handle_event(_key(KEY_ENTER), font)
	check(not panel.compact_overview(), "Enter exposes the unchanged full reader")
	check(" ".join(panel.detail_paragraphs()).contains("Press J") and " ".join(panel.detail_paragraphs()).contains("release to launch"), "full press/release execution remains available from compact selection")
	panel.handle_event(_joy(JOY_BUTTON_A), font)
	check(panel.compact_overview(), "controller A returns from reader to overview")
	panel.set_tab(Compendium.CHEMISTRY)
	check(panel.compact_overview(), "Chemistry opens with the whole pair matrix")
	var pairs := {}
	for row: int in range(6):
		for column: int in range(6):
			var rectangle := Compendium.chemistry_overview_rect(row, column)
			check(Compendium.PANEL.encloses(rectangle), "all thirty-six pair cells fit without scrolling")
			check(panel.overview_hit(rectangle.get_center()), "every reaction cell is pointer reachable")
			equal(panel.selected_row, row + 1, "matrix row maps to existing element reader")
			equal(panel.selected_element_column, column, "matrix column maps to exact second element")
			var cell := Compendium.hex_matrix_cell(row, column)
			var first_wire := ChemistryGuide.DISPLAY_WIRES[row]
			var second_wire := ChemistryGuide.DISPLAY_WIRES[column]
			var wire := HexPolicy.recipe_wire(first_wire, second_wire)
			var definition := HexPolicy.definition(wire)
			equal(cell.wire_id, wire, "matrix has current Hex Court reaction wire")
			equal(cell.name, definition.name, "matrix uses the current policy name")
			equal(cell.active_ticks, definition.active_ticks, "matrix timing uses exact policy ticks")
			equal(cell.purpose, definition.purpose, "matrix projects the current policy purpose")
			if wire != 322:
				equal(cell.counter, definition.counter, "matrix projects the current policy counter")
			equal(cell.wire_id, Compendium.hex_matrix_cell(column, row).wire_id, "matrix remains symmetric")
			check(Compendium.wrap_text(cell.name, font, rectangle.size.x - 12, 14).size() <= 2, "complete reaction name fits its cell in at most two lines")
			pairs[cell.wire_id] = true
			for line: String in panel.compact_summary(font):
				check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= 1136.01, "reaction summary fits without horizontal overflow")
	equal(pairs.size(), 21, "complete matrix represents exactly the current twenty-one pair/self reactions")
	equal(ChemistryGuide.DISPLAY_WIRES, [3, 2, 4, 1, 7, 8], "visible chemistry order does not change stable element wires")
	equal(ChemistryGuide.matrix_cell(0, 0).first, "Water", "chemistry display begins with Water")
	equal(ChemistryGuide.matrix_cell(2, 2).first, "Air", "wind wire four uses the player-facing Air label")
	equal(Compendium.hex_matrix_cell(-1, 0), {}, "invalid policy matrix index fails closed")
	panel.selected_row = 1
	panel.selected_element_column = 0
	panel.handle_event(_key(KEY_RIGHT), font)
	equal(panel.selected_element_column, 1, "keyboard selects second element independently")
	panel.handle_event(_joy(JOY_BUTTON_DPAD_DOWN), font)
	equal(panel.selected_row, 2, "controller selects first element independently")
	panel.handle_event(_joy(JOY_BUTTON_A), font)
	check(not panel.compact_overview(), "selected matrix pair opens its exact effect reader")
	panel.handle_event(_key(KEY_ENTER), font)
	check(panel.compact_overview(), "Enter returns to complete matrix")
	check(panel.overview_hit(Compendium.PRIMER_RECT.get_center()), "chemistry primer remains directly reachable")
	equal(panel.selected_row, 0, "primer is distinct from a selected reaction")
	panel.handle_event(_key(KEY_ENTER), font)
	var primer_copy := " ".join(panel.detail_paragraphs())
	check(primer_copy.contains("Cast them separately") and primer_copy.contains("Matching reaction strength"), "full chemistry primer remains available")
	panel.handle_event(_key(KEY_ESCAPE), font)
	check(not panel.is_open, "overview/reader flow retains established close behavior")


func _test_selected_chemistry_details(panel: RefCounted, preferences: PlayerPreferences, font: Font) -> void:
	panel.open_panel(Compendium.CHEMISTRY, preferences)
	var reached := {}
	for row: int in range(6):
		for column: int in range(6):
			check(panel.overview_hit(Compendium.chemistry_overview_rect(row, column).get_center()), "pair details begin at the actual clicked matrix cell")
			panel.handle_event(_key(KEY_ENTER), font)
			var first_wire := ChemistryGuide.DISPLAY_WIRES[row]
			var second_wire := ChemistryGuide.DISPLAY_WIRES[column]
			var wire := HexPolicy.recipe_wire(first_wire, second_wire)
			var definition := HexPolicy.definition(wire)
			var first := ChemistryGuide.ELEMENTS[first_wire]
			var second := ChemistryGuide.ELEMENTS[second_wire]
			equal(panel.chemistry_title(), "%s + %s = %s" % [first, second, definition.name], "detail title agrees with both selected matrix elements")
			var paragraphs: Array[String] = panel.detail_paragraphs()
			var cell := Compendium.hex_matrix_cell(row, column)
			equal(paragraphs[0], cell.effect, "the selected recipe's current policy behavior leads the details")
			var text := " ".join(paragraphs)
			check(text.contains(Compendium.sentence_text(String(cell.counter)).trim_suffix(".")), "pair details expose the same whole-hex-safe counter as the matrix")
			check(text.contains("forming %d ticks" % int(definition.formation_ticks)), "pair details expose formation ticks")
			check(text.contains("active %d ticks" % int(definition.active_ticks)), "pair details expose active ticks")
			check(text.contains("harmless decay %d ticks" % int(definition.decay_ticks)), "pair details expose decay ticks")
			var selection_radius := int(definition.get("selection_radius", definition.radius))
			match String(definition.selection_kind):
				"disk":
					check(text.contains("selection radius %.0f px" % (float(selection_radius) / 1000.0)), "disk details expose effective selection radius")
				"sector":
					check(text.contains("directional reach %.0f px" % (float(definition.length) / 1000.0)), "sector details expose directional reach")
				"capsule":
					check(text.contains("radius %.0f px / length %.0f px" % [float(definition.radius) / 1000.0, float(definition.length) / 1000.0]), "capsule details expose radius and length")
				"annulus":
					check(text.contains("inner radius %.0f px / outer radius %.0f px" % [float(definition.length) / 1000.0, float(definition.radius) / 1000.0]), "annulus details expose both bounds")
			if int(definition.pulse_ticks) > 0:
				check(text.contains("every %.2f s" % (float(definition.pulse_ticks) / HexPolicy.TICK_RATE)), "pair details preserve policy pulse cadence")
			var phases: Array[Dictionary] = panel.chemistry_phase_strip()
			equal(phases.size(), 3, "every recipe has a warning, active, harmless-decay visual sequence")
			var durations: Array[int] = [int(definition.formation_ticks), int(definition.active_ticks), int(definition.decay_ticks)]
			var labels := ["Warning", "Active effects", "Harmless decay"]
			var total := durations[0] + durations[1] + durations[2]
			for phase: int in range(3):
				equal(phases[phase].duration_ticks, durations[phase], "phase strip cannot invent lifecycle timings")
				equal(phases[phase].duration_ms, durations[phase] * 1000 / HexPolicy.TICK_RATE, "millisecond display derives from exact ticks")
				equal(phases[phase].label, labels[phase], "warning and decay cannot be mistaken for active effects")
				var rectangle: Rect2 = phases[phase].rectangle
				check(absf(rectangle.size.x / Compendium.PHASE_STRIP.size.x - float(durations[phase]) / total) < 0.00001, "phase width is proportional to the real duration")
				check(Compendium.PANEL.encloses(rectangle), "phase strip fits the actual reading panel")
				if phase > 0:
					# Rect2 stores float32 coordinates; tolerate less than 1/1000 px
					# when reconstructing an edge, not a visible pixel-sized gap.
					check(absf(rectangle.position.x - (phases[phase - 1].rectangle as Rect2).end.x) < 0.001, "phase segments have no visible gaps or overlaps")
			check(absf((phases[2].rectangle as Rect2).end.x - Compendium.PHASE_STRIP.end.x) < 0.0001, "phase sequence exactly fills its allotted width")
			var expected_lines: Array[String] = []
			for paragraph: String in paragraphs:
				expected_lines.append_array(Compendium.wrap_text(paragraph, font, Compendium.DETAIL_WIDTH))
			var actual_lines: Array[String] = []
			for page: int in range(panel.detail_pages(font)):
				panel.detail_page = page
				var lines: Array[String] = panel.visible_detail_lines(font)
				check(lines.size() <= Compendium.PAIR_LINES_PER_PAGE, "pair pages reserve space for the phase strip")
				_assert_widths(lines, font, Compendium.DETAIL_WIDTH)
				actual_lines.append_array(lines)
			equal(actual_lines, expected_lines, "exact pair details retain every paragraph across pages")
			reached[wire] = true
			panel.handle_event(_joy(JOY_BUTTON_A), font)
			check(panel.compact_overview(), "controller returns to the same matrix")
			equal([panel.selected_row, panel.selected_element_column], [row + 1, column], "overview/details switching preserves both selected elements")
			equal(panel.detail_page, 0, "returning to overview clears stale page selection")
	equal(reached.size(), 21, "all twenty-one exact pair/self recipes remain accessible")
	# Directly changing a column must also invalidate the wrapped cache; selection
	# restoration/capture callers do not necessarily go through move_column().
	panel.selected_row = 2 # Fire.
	panel.selected_element_column = 4 # Light: Solar Flare, not Fire + Water.
	panel.toggle_details()
	equal(panel.chemistry_title(), "Fire + Light = Solar Flare", "non-first column never falls back to its entire element row")
	check(" ".join(panel.visible_detail_lines(font)).contains(Compendium.sentence_text(String(HexPolicy.definition(314).counter)).trim_suffix(".")), "selected Solar Flare policy counter appears on the first page")
	panel.selected_element_column = 0 # Water: Steam.
	var steam_text := " ".join(panel.visible_detail_lines(font))
	check(steam_text.contains(Compendium.sentence_text(String(HexPolicy.definition(310).purpose)).trim_suffix(".")), "wrapped cache key includes Steam's transparent non-conceal contract")
	panel.detail_page = 1
	panel.handle_event(_key(KEY_RIGHT), font)
	equal(panel.selected_element_column, 1, "keyboard changes pair while details stay open")
	equal(panel.detail_page, 0, "changing pair resets its detail page")
	check(panel.show_details, "pair navigation never unexpectedly returns to overview")
	panel.handle_event(_joy(JOY_BUTTON_DPAD_LEFT), font)
	equal(panel.selected_element_column, 0, "controller has the same pair navigation in details")
	check(" ".join(panel.visible_detail_lines(font)).contains(Compendium.sentence_text(String(HexPolicy.definition(310).purpose)).trim_suffix(".")), "controller pair selection immediately refreshes exact Steam behavior")
	panel.move_column(-100)
	equal(panel.selected_element_column, 0, "detail pair selection cannot underflow")
	panel.move_column(100)
	equal(panel.selected_element_column, 5, "detail pair selection cannot exceed the element table")
	panel.selected_row = 0
	equal(panel.chemistry_phase_strip(), [], "primer is not falsely assigned a reaction timeline")
	equal(panel.detail_line_limit(), Compendium.LINES_PER_PAGE, "primer retains its full readable first page")
	check(" ".join(panel.visible_detail_lines(font)).contains("Cast them separately at the same nearby endpoint"), "full practical primer survives the exact-pair reader")
	equal(Compendium.hex_pair_lines(8, 0), [], "invalid current-policy pair details fail closed")
	panel.close_panel()


func _test_first_ten_policy_copy() -> void:
	for wire: int in HexPolicy.active_wire_ids():
		var definition := HexPolicy.definition(wire)
		var copy := " ".join(Compendium._first_ten_policy_lines(wire))
		check(copy.contains(String(definition.purpose)) and copy.contains(String(definition.counter)), "every live recipe projects its exact purpose and counter")
		check(copy.contains("TELL:") and copy.contains("harmless decay"), "warning and terminal phases remain explicit")
		check(copy.contains("TELL: nominal"), "recipe reference distinguishes authored duration from actual field timing")
		var inherits := HexPolicy.elements_for_mask(HexPolicy.mask_for_wire(wire)).size() > 1
		equal(copy.contains("COMBINING:"), inherits, "all distinct pairs and larger recipes explain inherited field timing")
		if inherits:
			check(copy.contains("shorten the active time") and copy.contains("change the fading time") and copy.contains("never lasts longer"), "inherited timing teaches both shorter attacks and variable harmless fade")
	equal(Compendium._first_ten_policy_lines(305), [], "retired Ice pair cannot appear as a live recipe")

func _test_current_link_and_vortex_guidance() -> void:
	var names := {}
	for mask: int in range(1, 64):
		var definition := Compendium.combination_definition(mask)
		check(not definition.is_empty(), "every nonempty six-element mask has an inspectable definition")
		names[int(definition.wire_id)] = true
		equal(definition, HexPolicy.definition(HexPolicy.recipe_wire_for_mask(mask)), "combination inspector cannot invent another recipe")
	equal(names.size(), 63, "all six self recipes and57 distinct-element combinations are accessible")
	for mask: int in [-1, 0, 64, 255]:
		equal(Compendium.combination_definition(mask), {}, "out-of-domain mask fails closed")

func _test_chemistry(panel: RefCounted, preferences: PlayerPreferences, font: Font) -> void:
	panel.open_panel(Compendium.CHARACTERS, preferences)
	panel.handle_event(_key(KEY_TAB), font)
	equal(panel.tab, Compendium.CHEMISTRY, "Chemistry is reachable through the existing Tab navigation")
	equal(panel.row_count(), 7, "primer and six element rows fit one readable list page")
	var primer := " ".join(panel.detail_paragraphs())
	check(primer.contains("3-5 seconds") and primer.contains("endpoint"), "primer explains current paid terminal matter and aim endpoints")
	check(primer.contains("separate from the reaction area's duration"), "deposit duration cannot be mistaken for a chemistry reaction area")
	check(primer.contains("SPELL IMPACT:") and primer.contains("REACTION AREA:") and primer.contains("PLAIN TERMINAL MATTER:"), "primer explicitly separates three visually similar gameplay concepts")
	check(primer.contains("surviving paid Spray pulse leaves one finite ingredient") and primer.contains("ground target within reach"), "guide teaches the current paid Spray terminal ingredient")
	check(primer.contains("catches weaker Rapid") and primer.contains("stronger Bolt or Heavy stops the pulse"), "guide teaches the bounded unequal Spray interception")
	check(primer.contains("Moving projectile-to-projectile clashes use ordered continuous contact"), "guide teaches the live ordered projectile clash system")
	check(primer.contains("reaction outcome") and primer.contains("not a selectable spell delivery"), "reaction-area teaching cannot imply a standalone Field spell")
	check(primer.contains("Fire becomes damaging burning ground") and primer.contains("ingredients do not automatically apply their reaction effects"), "guide distinguishes active Fire from other harmless ingredient layers")
	check(primer.contains("Fire Bolt + Water Bolt") and primer.contains("same-family spells make the direct match"), "guide turns the current distinct family strengths into an executable cross-element choice")
	check(primer.contains("one cast cannot react with itself") and primer.contains("finite 600-unit budget"), "guide teaches separate paid sources and finite whole-cast consumption")
	check(primer.contains("consume the smaller remaining strength from both sources") and primer.contains("stronger survivor"), "guide teaches subtractive strength and finite survivor material")
	check(primer.contains("All projectiles are trail-free") and primer.contains("remaining paid payload reaches impact"), "teaching matches trail-free flights and conserved impact payloads")
	check(primer.contains("lower cast identity") and primer.contains("only the active window"), "guide teaches stable ownership and harmless formation/decay")
	check(primer.contains("distinct paid ingredient") and not primer.contains("extra Charge"), "larger combinations use canonical paid ingredients, not retired selectors")
	check(primer.contains("reserves finite product capacity before payment") and primer.contains("refuses without spending Flux"), "finite reservation refusal is explained before payment")
	panel.detail_page = 0
	var first_page := " ".join(panel.visible_detail_lines(font))
	check(first_page.contains("Fire Bolt + Water Bolt") and first_page.contains("Heavy + Heavy") and first_page.contains("Rapid + Rapid") and first_page.contains("Spray + Spray"), "real-font first page gives source-valid same-family cross-element choices")
	check(first_page.contains("Water 6 seconds") and first_page.contains("Cast them separately"), "first page includes current source expiry and the separate-cast requirement")
	check(first_page.contains("Matching reaction strength") and first_page.contains("Overlapping matter") and first_page.contains("clear path"), "first page explains actual material admission conditions")
	check(first_page.contains("Watch formation -> active -> decay") and first_page.contains("only the active window"), "first page teaches the observable effect lifecycle")
	check(first_page.contains("element row") and first_page.contains("counters") and first_page.contains("host during Hearth free practice"), "first page states who can use the paid demonstration")
	check(first_page.contains("Reset Wellspring restarts shared practice") and first_page.contains("retains weaves") and first_page.contains("clears paid fields and practice targets"), "first page states the complete shared reset scope")
	check(primer.find("1. In the Spell Loom") < primer.find("SPELL IMPACT:"), "practical steps precede impact, reaction-area and matter definitions")
	_test_chemistry_source_values(ChemistryGuide.entries())
	_test_combination_navigation(panel, preferences, font)
	panel.open_panel(Compendium.CHEMISTRY, preferences)
	check(primer.contains("Every selected hex is affected") and primer.contains("Unselected neighbours stay clear"), "live primer teaches the approved whole-hex authority")
	check(not primer.contains("Steam conceals") and primer.contains("Steam is transparent capped scald"), "live primer cannot revive retired Steam concealment")
	var seen := {}
	for row: int in range(panel.row_count()):
		panel.selected_row = row
		for recipe: Dictionary in panel.chemistry_rows[row]["recipes"]:
			seen[int(recipe.wire_id)] = true
		var all_lines: Array[String] = []
		for paragraph: String in panel.detail_paragraphs():
			all_lines.append_array(Compendium.wrap_text(paragraph,font,Compendium.DETAIL_WIDTH))
		var reached: Array[String] = []
		for page: int in range(panel.detail_pages(font)):
			panel.detail_page = page
			var lines: Array[String] = panel.visible_detail_lines(font)
			check(lines.size() <= Compendium.LINES_PER_PAGE, "chemistry page stays vertically bounded")
			_assert_widths(lines,font,Compendium.DETAIL_WIDTH)
			reached.append_array(lines)
		equal(reached,all_lines,"every pair and effect remains reachable through detail paging")
	equal(seen.size(),21,"all twenty-one unique pairs are accessible in the live compendium")
	panel.handle_event(_joy(JOY_BUTTON_RIGHT_SHOULDER),font)
	equal(panel.tab,Compendium.MOVEMENT,"controller cycles Chemistry back to Movement")
	panel.handle_event(_joy(JOY_BUTTON_LEFT_SHOULDER),font)
	equal(panel.tab,Compendium.CHEMISTRY,"controller can cycle backwards to Chemistry")
	panel.handle_event(_key(KEY_ESCAPE),font)
	check(not panel.is_open,"Chemistry closes through the same safe modal exit")


func _test_chemistry_source_values(rows: Array[Dictionary]) -> void:
	equal(rows.size(), 7, "primer plus exactly six canonical ingredient rows")
	var unique := {}
	for row: int in range(6):
		equal(rows[row + 1].recipes.size(), 6, "each ingredient exposes every canonical pair")
		for column: int in range(6):
			var cell := ChemistryGuide.matrix_cell(row, column)
			var definition := HexPolicy.definition(int(cell.wire_id))
			unique[int(cell.wire_id)] = true
			equal(rows[row + 1].recipes[column], definition, "guide reads the live policy without a second effect table")
			var copy := " ".join(ChemistryGuide.pair_lines(row, column))
			check(copy.contains(String(definition.purpose)) and copy.contains(String(definition.counter)), "both behavior and counter survive projection")
			check(copy.contains("%s Bolt + %s Bolt" % [cell.first, cell.second]), "exact pair has an executable paid-cast example")
			check(copy.contains("TELL:") and copy.contains("harmless decay"), "formation and terminal timing remain readable")
	equal(unique.size(), 21, "pair guide has exactly21 canonical identities")
	for coordinate: Vector2i in [Vector2i(-1,0),Vector2i(6,0),Vector2i(0,6)]:
		equal(ChemistryGuide.matrix_cell(coordinate.x,coordinate.y), {}, "retired and invalid menu positions fail closed")

func _test_controller_and_physical_navigation(panel: RefCounted, preferences: PlayerPreferences, font: Font) -> void:
	panel.open_panel(Compendium.MOVEMENT, preferences, null, ControlBindingEditor.DEVICE_CONTROLLER)
	for value: float in [0.0, 0.2, -0.2, 0.6, -0.6]:
		check(panel.handle_event(_axis(JOY_AXIS_LEFT_Y, value), font), "open compendium owns resting controller motion")
	equal(panel.selected_row, 0, "resting drift and partial tilt do not move selection")
	panel.handle_event(_axis(JOY_AXIS_LEFT_Y, 0.8), font)
	equal(panel.selected_row, 1, "deliberate left stick selects the next movement row")
	for value: float in [0.95, 0.8, 0.5, -0.9]:
		panel.handle_event(_axis(JOY_AXIS_LEFT_Y, value), font)
	equal(panel.selected_row, 1, "held jitter and reversal cannot skip rows without returning to neutral")
	panel.handle_event(_axis(JOY_AXIS_LEFT_Y, 0.3), font)
	panel.handle_event(_axis(JOY_AXIS_LEFT_Y, -0.8), font)
	equal(panel.selected_row, 0, "neutral rearms the opposite direction")
	for axis: int in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		check(panel.handle_event(_axis(axis, 1.0), font), "aim and trigger axes remain owned by the menu")
	equal(panel.selected_row, 0, "aim and trigger axes cannot navigate or dispatch gameplay")
	panel.handle_event(_joy(JOY_BUTTON_DPAD_DOWN), font)
	equal(panel.selected_row, 1, "D-pad remains immediately usable alongside a latched stick")
	panel.close_panel()
	check(not panel.handle_event(_axis(JOY_AXIS_LEFT_Y, 0.9), font), "closed compendium does not consume stick input")
	panel.open_panel(Compendium.CHEMISTRY, preferences)
	panel.handle_event(_axis(JOY_AXIS_LEFT_X, 0.9), font)
	equal(panel.selected_row, 1, "horizontal stick moves from primer to an actual pair")
	equal(panel.selected_element_column, 1, "horizontal stick chooses the second element")
	panel.handle_event(_axis(JOY_AXIS_LEFT_Y, 0.9), font)
	equal(panel.selected_row, 2, "reopening releases old vertical latch and axes work independently")
	for step: int in range(10):
		panel.handle_event(_axis(JOY_AXIS_LEFT_X, 0.0), font)
		panel.handle_event(_axis(JOY_AXIS_LEFT_X, 1.0), font)
		panel.handle_event(_axis(JOY_AXIS_LEFT_Y, 0.0), font)
		panel.handle_event(_axis(JOY_AXIS_LEFT_Y, 1.0), font)
	equal(panel.selected_element_column, 5, "rightmost chemistry column clamps without wrapping")
	equal(panel.selected_row, 6, "last chemistry row clamps without wrapping")
	panel.handle_event(_joy(JOY_BUTTON_A), font)
	check(panel.show_details and panel.chemistry_title().contains("Dark + Dark"), "stick selection opens the same exact pair as button navigation")
	panel.open_panel(Compendium.CHARACTERS, preferences)
	# A two-character fixture isolates navigation from catalog row population.
	var original_overview: Dictionary = panel.overview
	panel.overview = {"rows": [{"champions": [{"display_name": "First"}, {"display_name": "Second"}]}]}
	panel.handle_event(_axis(JOY_AXIS_LEFT_X, 0.9), font)
	equal(panel.selected_character, 1, "character stick navigation follows the existing cycle")
	panel.handle_event(_axis(JOY_AXIS_LEFT_X, 0.0), font)
	panel.handle_event(_axis(JOY_AXIS_LEFT_X, 0.9), font)
	equal(panel.selected_character, 0, "character cycle retains its established wrap")
	panel.overview = original_overview
	panel.open_panel(Compendium.MOVEMENT, preferences)
	var physical := _key(KEY_UP)
	physical.physical_keycode = KEY_DOWN
	panel.handle_event(physical, font)
	equal(panel.selected_row, 1, "physical navigation matches other menus when logical code differs")
	physical.echo = true
	panel.handle_event(physical, font)
	physical.echo = false
	physical.pressed = false
	panel.handle_event(physical, font)
	equal(panel.selected_row, 1, "echo and release do not buy additional navigation")
	physical = _key(KEY_NONE)
	physical.physical_keycode = KEY_ESCAPE
	panel.handle_event(physical, font)
	check(not panel.is_open, "physical-only Escape retains the safe close path")


func _axis(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _assert_widths(lines: Array[String], font: Font, width: float) -> void:
	for line: String in lines:
		check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Compendium.FONT_SIZE).x <= width, "wrapped line fits the visible detail column")


func _key(key: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	return event


func _joy(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _test_combination_navigation(panel: RefCounted, preferences: PlayerPreferences, font: Font) -> void:
	panel.open_panel(Compendium.CHEMISTRY, preferences)
	panel.handle_event(_key(KEY_C), font)
	check(panel.combination_mode, "keyboard reaches the larger-combination inspector")
	var before: int = panel.combination_mask
	panel.handle_event(_key(KEY_ENTER), font)
	equal(panel.combination_mask, before ^ 4, "Enter toggles the focused Water bit only")
	panel.handle_event(_joy(JOY_BUTTON_DPAD_RIGHT), font)
	panel.handle_event(_joy(JOY_BUTTON_A), font)
	equal(panel.combination_mask, (before ^ 4) ^ 2, "controller toggles the next Fire bit only")
	panel.handle_event(_joy(JOY_BUTTON_RIGHT_STICK), font)
	check(not panel.combination_mode, "controller returns to the pair table")
	panel.handle_event(_key(KEY_C), font)
	for mask: int in range(1, 64):
		panel.combination_mask = mask
		var source: Array[String] = panel.detail_paragraphs()
		var shown: Array[String] = []
		var page_ends: Array[int] = []
		for page: int in range(panel.detail_pages(font)):
			panel.detail_page = page
			var lines: Array[String] = panel.visible_detail_lines(font)
			_assert_widths(lines,font,Compendium.DETAIL_WIDTH)
			check(lines.size() <= 12, "combination details reserve controls without vertical overflow")
			shown.append_array(lines)
			page_ends.append(shown.size())
		var expected: Array[String] = []
		for paragraph: String in source:
			var paragraph_lines := Compendium.wrap_text(paragraph,font,Compendium.DETAIL_WIDTH)
			var start := expected.size()
			expected.append_array(paragraph_lines)
			if paragraph_lines.size() <= 12:
				for page_end: int in page_ends:
					check(page_end <= start or page_end >= expected.size(), "one readable rule never breaks across combination pages")
		equal(shown, expected, "all combination text survives pagination and cache changes")
		var definition: Dictionary = Compendium.combination_definition(mask)
		if definition.get("elements", []).size() >= 3:
			check(" ".join(source).contains("nominal") and " ".join(source).contains("earliest parent expiry"), "composite timing distinguishes authored schedule from inherited actual expiry")
	equal(Compendium.sentence_text("Water slows physical projectiles"), "Water slows physical projectiles.", "sentence case preserves authored element names without capitalizing every word")
	equal(Compendium.sentence_text("leave the Fire lane."), "Leave the Fire lane.", "counter case preserves proper names and existing punctuation")
	panel.handle_event(_key(KEY_ESCAPE),font)
	check(not panel.is_open, "combination inspector retains modal close")

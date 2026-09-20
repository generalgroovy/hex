extends FluxTestSuite


const Compendium = preload("res://src/presentation/player_compendium.gd")
const ChemistryGuide = preload("res://src/presentation/chemistry_guide_model.gd")
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "compendium ability catalog loads")
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
	check(" ".join(panel.detail_paragraphs()).contains("Tap J"), "live guide resolves rebound controls")
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
	check(spell_copy.contains("this is not a projectile-to-projectile clash"), "spell-family page cannot imply general moving-shot clashes")
	_test_chemistry(panel, preferences, font)
	_test_compact_overviews(panel, preferences, font)
	_test_selected_chemistry_details(panel, preferences, font)
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
	check(MovementGuideModel.compact_cells(panel.movement_rows[2])[4].contains("opening"), "jump table cannot imply protection throughout the whole flight")
	panel.handle_event(_key(KEY_ENTER), font)
	check(not panel.compact_overview(), "Enter exposes the unchanged full reader")
	check(" ".join(panel.detail_paragraphs()).contains("Tap J"), "full execution remains available from compact selection")
	panel.handle_event(_joy(JOY_BUTTON_A), font)
	check(panel.compact_overview(), "controller A returns from reader to overview")
	panel.set_tab(Compendium.CHEMISTRY)
	check(panel.compact_overview(), "Chemistry opens with the whole pair matrix")
	var pairs := {}
	for row: int in range(8):
		for column: int in range(8):
			var rectangle := Compendium.chemistry_overview_rect(row, column)
			check(Compendium.PANEL.encloses(rectangle), "all sixty-four pair cells fit without scrolling")
			check(panel.overview_hit(rectangle.get_center()), "every reaction cell is pointer reachable")
			equal(panel.selected_row, row + 1, "matrix row maps to existing element reader")
			equal(panel.selected_element_column, column, "matrix column maps to exact second element")
			var cell := ChemistryGuide.matrix_cell(row, column)
			var first_wire := ChemistryGuide.DISPLAY_WIRES[row]
			var second_wire := ChemistryGuide.DISPLAY_WIRES[column]
			var recipe := Chemistry.recipe(Chemistry.recipe_wire(first_wire, second_wire))
			equal(cell.wire_id, recipe.wire_id, "matrix has live reaction wire")
			equal(cell.name, recipe.name, "matrix uses full canonical reaction name")
			equal(cell.active_ms, recipe.active_ms, "matrix timing uses current runtime definition")
			equal(cell.effect, ChemistryGuide.EFFECTS[int(recipe.wire_id) - 301], "matrix effect copy is the existing reviewed guide text")
			equal(cell.wire_id, ChemistryGuide.matrix_cell(column, row).wire_id, "matrix remains symmetric")
			check(Compendium.wrap_text(cell.name, font, rectangle.size.x - 12, 14).size() <= 2, "complete reaction name fits its cell in at most two lines")
			pairs[cell.wire_id] = true
			for line: String in panel.compact_summary(font):
				check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= 1136.01, "reaction summary fits without horizontal overflow")
	equal(pairs.size(), 36, "complete matrix represents exactly the current thirty-six reactions")
	equal(ChemistryGuide.DISPLAY_WIRES, [3, 1, 2, 4, 5, 6, 7, 8], "visible chemistry order does not change stable element wires")
	equal(ChemistryGuide.matrix_cell(0, 0).first, "Water", "chemistry display begins with Water")
	equal(ChemistryGuide.matrix_cell(3, 3).first, "Air", "wind wire four uses the player-facing Air label")
	equal(ChemistryGuide.matrix_cell(-1, 0), {}, "invalid matrix index fails closed")
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
	for row: int in range(8):
		for column: int in range(8):
			check(panel.overview_hit(Compendium.chemistry_overview_rect(row, column).get_center()), "pair details begin at the actual clicked matrix cell")
			panel.handle_event(_key(KEY_ENTER), font)
			var first_wire := ChemistryGuide.DISPLAY_WIRES[row]
			var second_wire := ChemistryGuide.DISPLAY_WIRES[column]
			var recipe := Chemistry.recipe(Chemistry.recipe_wire(first_wire, second_wire))
			var first := ChemistryGuide.ELEMENTS[first_wire]
			var second := ChemistryGuide.ELEMENTS[second_wire]
			equal(panel.chemistry_title(), "%s + %s = %s" % [first, second, recipe.name], "detail title agrees with both selected matrix elements")
			var paragraphs: Array[String] = panel.detail_paragraphs()
			equal(paragraphs[0], ChemistryGuide.EFFECTS[int(recipe.wire_id) - 301], "the selected recipe's actual behavior and counter lead the details")
			var text := " ".join(paragraphs)
			check(text.contains("%.1f s (%s)" % [float(Chemistry.ELEMENT_LIFE_MS[first_wire]) / 1000.0, first]), "first input lifetime is live source data")
			check(text.contains("%.1f s (%s)" % [float(Chemistry.ELEMENT_LIFE_MS[second_wire]) / 1000.0, second]), "second input lifetime is live source data")
			if int(recipe.pulse_ms) > 0:
				check(text.contains("Cadence: %.2f s." % (float(recipe.pulse_ms) / 1000.0)), "pair details preserve the actual cadence")
			if int(recipe.wire_id) in [301, 305, 306, 329]:
				check(text.contains("Shot-cover health: %.0f." % (float(recipe.health) / 1000.0)), "pair details preserve the actual cover health")
				if int(recipe.wire_id) == 329:
					check(text.contains("Non-Light attacks meet cover; Light paths split with shared damage"), "Lens durability explanation preserves its Light split exception")
					check(not text.contains("Cover stops shots and rays"), "Lens supplemental copy cannot falsely block every element")
			if int(recipe.wire_id) in [313, 319, 328]:
				check(text.contains("Link reach: %.0f px per step; at most %d separate source(s)." % [float(recipe.length) / 1000.0, 1 if int(recipe.wire_id) == 313 else Chemistry.MAX_LINKS]), "pair details preserve source link reach and capacity")
			var phases: Array[Dictionary] = panel.chemistry_phase_strip()
			equal(phases.size(), 3, "every recipe has a warning, active, harmless-decay visual sequence")
			var durations: Array[int] = [int(recipe.formation_ms), int(recipe.active_ms), int(recipe.decay_ms)]
			var labels := ["Warning", "Active effects", "Harmless decay"]
			var total := durations[0] + durations[1] + durations[2]
			for phase: int in range(3):
				equal(phases[phase].duration_ms, durations[phase], "phase strip cannot invent lifecycle timings")
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
			reached[int(recipe.wire_id)] = true
			panel.handle_event(_joy(JOY_BUTTON_A), font)
			check(panel.compact_overview(), "controller returns to the same matrix")
			equal([panel.selected_row, panel.selected_element_column], [row + 1, column], "overview/details switching preserves both selected elements")
			equal(panel.detail_page, 0, "returning to overview clears stale page selection")
	equal(reached.size(), 36, "all thirty-six exact recipes remain accessible")
	# Directly changing a column must also invalidate the wrapped cache; selection
	# restoration/capture callers do not necessarily go through move_column().
	panel.selected_row = 3 # Fire.
	panel.selected_element_column = 4 # Ice: Thermal Shock, not Fire + Earth.
	panel.toggle_details()
	equal(panel.chemistry_title(), "Fire + Ice = Thermal Shock", "non-first column never falls back to its entire element row")
	check(" ".join(panel.visible_detail_lines(font)).contains("active temporary constructs once"), "selected Thermal Shock counter appears on the first page")
	panel.selected_element_column = 0 # Water: Steam.
	check(" ".join(panel.visible_detail_lines(font)).contains("Expanding Steam"), "wrapped cache key includes the selected second element")
	panel.detail_page = 1
	panel.handle_event(_key(KEY_RIGHT), font)
	equal(panel.selected_element_column, 1, "keyboard changes pair while details stay open")
	equal(panel.detail_page, 0, "changing pair resets its detail page")
	check(panel.show_details, "pair navigation never unexpectedly returns to overview")
	panel.handle_event(_joy(JOY_BUTTON_DPAD_LEFT), font)
	equal(panel.selected_element_column, 0, "controller has the same pair navigation in details")
	check(" ".join(panel.visible_detail_lines(font)).contains("Expanding Steam"), "controller pair selection immediately refreshes detail text")
	panel.move_column(-100)
	equal(panel.selected_element_column, 0, "detail pair selection cannot underflow")
	panel.move_column(100)
	equal(panel.selected_element_column, 7, "detail pair selection cannot exceed the element table")
	panel.selected_row = 0
	equal(panel.chemistry_phase_strip(), [], "primer is not falsely assigned a reaction timeline")
	equal(panel.detail_line_limit(), Compendium.LINES_PER_PAGE, "primer retains its full readable first page")
	check(" ".join(panel.visible_detail_lines(font)).contains("Cast them separately at the same nearby endpoint"), "full practical primer survives the exact-pair reader")
	equal(ChemistryGuide.pair_lines(8, 0), [], "invalid pair details fail closed")
	panel.close_panel()


func _test_chemistry(panel: RefCounted, preferences: PlayerPreferences, font: Font) -> void:
	panel.open_panel(Compendium.CHARACTERS, preferences)
	panel.handle_event(_key(KEY_TAB), font)
	equal(panel.tab, Compendium.CHEMISTRY, "Chemistry is reachable through the existing Tab navigation")
	equal(panel.row_count(), 9, "primer and eight element rows fit one readable list page")
	var primer := " ".join(panel.detail_paragraphs())
	check(primer.contains("3-5 seconds") and primer.contains("endpoint"), "primer explains current paid terminal matter and aim endpoints")
	check(primer.contains("separate from the reaction area's duration"), "deposit duration cannot be mistaken for a chemistry reaction area")
	check(primer.contains("SPELL IMPACT:") and primer.contains("REACTION AREA:") and primer.contains("PLAIN TERMINAL MATTER:"), "primer explicitly separates three visually similar gameplay concepts")
	check(primer.contains("surviving paid Spray pulse leaves one finite ingredient") and primer.contains("ground target within reach"), "guide teaches the current paid Spray terminal ingredient")
	check(primer.contains("catches weaker Rapid") and primer.contains("stronger Bolt or Heavy stops the pulse"), "guide teaches the bounded unequal Spray interception")
	check(primer.contains("not a projectile-to-projectile clash"), "guide does not imply the deferred moving-projectile clash system")
	check(primer.contains("reaction outcome") and primer.contains("not a selectable spell delivery"), "reaction-area teaching cannot imply a standalone Field spell")
	check(primer.contains("Plain matter itself causes no damage, healing, burn, wet, slow or other status"), "plain material is not falsely described as automatic elemental status")
	check(primer.contains("Fire Bolt + Water Bolt") and primer.contains("same-family spells make the direct match"), "guide turns the current distinct family strengths into an executable cross-element choice")
	check(primer.contains("one cast cannot react with itself") and primer.contains("Each cast supplies one chemistry reaction"), "guide teaches separate paid sources and finite whole-cast consumption")
	check(primer.contains("Only equal reaction strengths combine") and primer.contains("unequal deposits stay unchanged"), "guide distinguishes exact strength admission from material quantity and expiry")
	check(primer.contains("Rapid is explicitly trail-free regardless of reaction strength"), "trail teaching does not infer a strength threshold")
	check(primer.contains("oldest deposit") and primer.contains("only the active window"), "guide teaches stable ownership and harmless formation/decay")
	check(primer.contains("not later") and primer.contains("extra Charge") and primer.contains("extra Ice"), "linked circuits require separate sources present at formation")
	check(primer.contains("one reaction origin") and primer.contains("without being consumed"), "busy space and capacity explain refused pair formation without invented material loss")
	panel.detail_page = 0
	var first_page := " ".join(panel.visible_detail_lines(font))
	check(first_page.contains("Fire Bolt + Water Bolt") and first_page.contains("Heavy + Heavy") and first_page.contains("Rapid + Rapid") and first_page.contains("Spray + Spray"), "real-font first page gives source-valid same-family cross-element choices")
	check(first_page.contains("3-5 seconds") and first_page.contains("Cast them separately"), "first page includes current source expiry and the separate-cast requirement")
	check(first_page.contains("Matching reaction strength") and first_page.contains("overlapping matter") and first_page.contains("clear path"), "first page explains actual material admission conditions")
	check(first_page.contains("Watch formation -> active -> decay") and first_page.contains("only the active window"), "first page teaches the observable effect lifecycle")
	check(first_page.contains("element row") and first_page.contains("counters") and first_page.contains("Practice reset clears transient matter"), "first page provides the next learning step and safe practice reset")
	check(primer.find("1. In the Spell Loom") < primer.find("SPELL IMPACT:"), "practical steps precede impact, reaction-area and matter definitions")
	_test_chemistry_source_values(panel.chemistry_rows)
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
	equal(seen.size(),36,"all thirty-six unique pairs are accessible in the live compendium")
	panel.handle_event(_joy(JOY_BUTTON_RIGHT_SHOULDER),font)
	equal(panel.tab,Compendium.MOVEMENT,"controller cycles Chemistry back to Movement")
	panel.handle_event(_joy(JOY_BUTTON_LEFT_SHOULDER),font)
	equal(panel.tab,Compendium.CHEMISTRY,"controller can cycle backwards to Chemistry")
	panel.handle_event(_key(KEY_ESCAPE),font)
	check(not panel.is_open,"Chemistry closes through the same safe modal exit")


func _test_chemistry_source_values(rows: Array[Dictionary]) -> void:
	equal(ChemistryGuide.EFFECTS.size(), 36, "every current pair has one curated explanation")
	var unique_effects := {}
	for description: String in ChemistryGuide.EFFECTS:
		check(description.length() >= 60, "each effect explains both behavior and a practical response")
		unique_effects[description] = true
	equal(unique_effects.size(), 36, "pair explanations are not generic repeated placeholders")
	for display_row: int in range(8):
		var element := ChemistryGuide.DISPLAY_WIRES[display_row]
		var row: Dictionary = rows[display_row + 1]
		var text := " ".join(row["lines"])
		check(text.contains("%.1f seconds" % (float(Chemistry.ELEMENT_LIFE_MS[element])/1000.0)), "element deposit lifetime comes from live chemistry tuning")
		check(text.contains("Plain matter has no automatic status or damage"), "each element page preserves plain-matter constraint")
		equal(row["recipes"].size(), 8, "each element page retains all eight symmetric pair records")
		for display_column: int in range(8):
			var other := ChemistryGuide.DISPLAY_WIRES[display_column]
			var live := Chemistry.recipe(Chemistry.recipe_wire(element, other))
			var pair_copy := " ".join(ChemistryGuide.pair_lines(display_row, display_column))
			check(pair_copy.contains("two separate casts with matching reaction strength") and pair_copy.contains("%s Bolt + %s Bolt" % [ChemistryGuide.ELEMENTS[element], ChemistryGuide.ELEMENTS[other]]), "every exact pair reader carries a same-family example for its selected elements")
			equal(row["recipes"][display_column], live, "existing recipe API remains an unmodified live-kernel projection")
			check(text.contains("%.2f s -> %.2f s -> %.2f s" % [float(live.formation_ms)/1000.0,float(live.active_ms)/1000.0,float(live.decay_ms)/1000.0]), "lifecycle labels use actual source phase values")
			if int(live.pulse_ms) > 0:
				check(text.contains("Cadence: %.2f s." % (float(live.pulse_ms)/1000.0)), "cadence labels track each recipe rather than a duplicated timing constant")
			if int(live.wire_id) in [301,305,306,329]:
				check(text.contains("Shot-cover health: %.0f." % (float(live.health)/1000.0)), "cover durability is readable in player units")
			if int(live.wire_id) in [313,319,328]:
				check(text.contains("Link reach: %.0f px per step; at most %d separate source(s)." % [float(live.length)/1000.0,1 if int(live.wire_id) == 313 else Chemistry.MAX_LINKS]), "link reach and source cap are projected from recipe and kernel limits")
	check(ChemistryGuide.EFFECTS[307-301].contains("ALL elements"), "Crystal Prism is not mislabeled as Light-only")
	check(ChemistryGuide.EFFECTS[306-301].contains("excess hits ordinary cover"), "Grounding depletion never promises a free pass through intact cover")
	check(ChemistryGuide.EFFECTS[312-301].contains("active temporary constructs once, not actors or worldbone"), "Thermal Shock does not claim destruction of immutable buildings or unformed cover")
	check(ChemistryGuide.EFFECTS[319-301].contains("without links"), "Conductive Flood origin fallback remains discoverable")
	check(ChemistryGuide.EFFECTS[329-301].contains("shared damage") and ChemistryGuide.EFFECTS[329-301].contains("no projectile capacity"), "Lens guide explains conservation and finite capacity")
	check(ChemistryGuide.EFFECTS[330-301].contains("does not add slippery movement"), "Black Ice cannot imply the deferred material grip system")
	var config := SimConfig.new(120)
	var prism := ElementReactionState.new()
	prism.recipe_wire_id = 307
	prism.position_x = 500000
	prism.position_y = 500000
	prism.radius = int(Chemistry.recipe(307).radius)
	prism.length = int(Chemistry.recipe(307).length)
	prism.active_tick = 1
	prism.decay_tick = 20
	for element: int in range(1, 9):
		var projectile := ProjectileState.new(100, 2, 2, 100, element, Vector2i(510000,500000), Vector2i(500000,0), 4000, 12000, 50)
		projectile.previous_x = 490000
		check(bool(Chemistry.projectile_interaction(projectile,[prism],null,config,1)["reflected"]), "Prism ALL-elements teaching is backed by real projectile routing: %d" % element)
		var response := Chemistry.ray_interaction(Vector2i(490000,500000),Vector2i(510000,500000),element,12000,[prism],1)
		check(bool(response["transformed"]) and int(response["rays"][0]["end"].x) < int(response["rays"][0]["origin"].x), "Prism ALL-elements teaching is backed by real ray routing: %d" % element)


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

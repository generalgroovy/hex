extends FluxTestSuite


func run() -> int:
	var filter := VisualAccessibilityFilter.new()
	check(filter.configure(), "accessibility filter loads its exact fail-closed profile catalog and shader")
	equal(filter.profiles_by_id.size(), 6, "accessibility filter exposes two player profiles and four review simulations")
	equal(filter.player_profile_label("standard"), "STANDARD", "standard profile has readable copy")
	equal(filter.player_profile_label("high_contrast"), "HIGH CONTRAST", "high-contrast profile has readable copy")
	equal(VisualAccessibilityFilter.player_profile_for(false), "standard", "ordinary preference selects the unfiltered frame")
	equal(VisualAccessibilityFilter.player_profile_for(true), "high_contrast", "high-contrast preference selects the live contrast filter")
	check(filter.set_profile("grayscale"), "grayscale review profile can be activated")
	equal(filter.current_profile_id, "grayscale", "review profile selection is observable")
	check(not filter.set_profile("achromatopsia_guess"), "unknown accessibility profiles fail closed")
	equal(VisualAccessibilityFilter.parse_capture_profile("--capture-visual-profile=DEUTERANOPIA"), "deuteranopia", "capture profile parsing is case-insensitive")
	equal(VisualAccessibilityFilter.parse_capture_profile("--capture-visual-profile=unknown"), "", "unknown capture profile fails closed")
	equal(VisualAccessibilityFilter.parse_capture_profile("--other=grayscale"), "", "unrelated arguments cannot enable a review filter")
	check(VisualAccessibilityFilter.has_reduced_effects_capture_argument("--capture-reduced-effects"), "reduced-effects capture switch parses exactly")
	check(not VisualAccessibilityFilter.has_reduced_effects_capture_argument("--capture-reduced-effects=true"), "reduced-effects capture switch rejects alternate syntax")
	filter.free()
	return finish("visual-accessibility-filter")

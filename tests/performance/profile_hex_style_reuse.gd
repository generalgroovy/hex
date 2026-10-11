extends "res://tests/performance/profile_hex_boundary_reuse.gd"
## Same alternating paid-world and all-material fixtures, isolating style reuse
## against uncached evaluation. Both arms retain the accepted geometry caches.

const StyleOracle = preload("res://tests/support/hex_style_oracle.gd")

func _profile_id() -> String:
	return "hex-style-reuse"

func _oracle_path() -> String:
	return "res://tests/support/hex_style_oracle.gd"

func _baseline_presenter() -> HexCourtPresenter:
	return StyleOracle.new()

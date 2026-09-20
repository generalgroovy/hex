class_name HexCourt
extends "res://src/sim/hex/hex_chemistry_world.gd"

# Compatibility scenario only. All paid state and chemistry live in the shared
# base; the court supplies its original geometry for retained practice receipts.
const ORIGIN := Vector2i(640_000, 480_000)
const RADIUS := 6

func _init() -> void:
	var configured := configure_geometry(ORIGIN, Grid.disk(Vector2i.ZERO, RADIUS))
	assert(configured)

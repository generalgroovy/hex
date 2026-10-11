extends "res://src/app/bootstrap.gd"
## Native regression harness: use the real Bootstrap camera helper, not a copy.
const FullbodyPose = preload("res://src/presentation/fullbody_cast_presenter.gd")
const BACKGROUND := Color("243b35")
const SENTINEL := Color("ff00ff")
var capture_frame: Dictionary = {}
var capture_camera := Vector2(180, 100)
var capture_anchor := Vector2(520, 360)
var capture_sentinel := Vector2(650, 430)
var use_bootstrap_transform := true


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(-5000, -5000, 10000, 10000), BACKGROUND)
	if capture_frame.is_empty(): return
	if use_bootstrap_transform: _set_world_transform(capture_camera)
	FullbodyPose.draw_frame(self, capture_frame, capture_anchor, Color.WHITE)
	# This must inherit the same camera after the body, which catches even an
	# unconditional reset following an otherwise correct clipped ball mesh.
	draw_rect(Rect2(capture_sentinel, Vector2(16, 16)), SENTINEL)

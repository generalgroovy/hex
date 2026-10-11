extends "C:/Users/sende/Projects/hex/tests/diagnostics/gallery_availability_journey.gd"

# Post-gate diagnostic only: normalize harmless local actor aim/facing before
# each screenshot so OS cursor position cannot choose a different underlay pose.
# Production source and the original native journey remain frozen and unchanged.
func _capture(label: String, enabled: bool) -> void:
	var actor: PlayerState = game._local_player_state()
	actor.aim_x = 0
	actor.aim_y = 1000
	actor.facing_x = 0
	actor.facing_y = 1000
	facts["pose_control"] = "Arranged south-facing local actor only before each capture; inherited production UI/request checks and original diagnostic unchanged."
	await super._capture(label, enabled)

extends SceneTree


# No-write probe: never loads gameplay, preferences, network, or saves.
func _initialize() -> void:
	print("FLUX_BOOTSTRAP_PROBE=" + JSON.stringify({
		"user_data_dir": OS.get_user_data_dir(),
		"arguments": Array(OS.get_cmdline_user_args()),
	}))
	quit(0)

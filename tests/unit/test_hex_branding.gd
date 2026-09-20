extends FluxTestSuite

func run() -> int:
 equal(String(ProjectSettings.get_setting("application/config/name")), "HEX", "new product title is HEX")
 var roaming := OS.get_environment("APPDATA").replace("\\", "/").trim_suffix("/")
 if OS.get_name() == "Windows":
  equal(OS.get_user_data_dir().replace("\\", "/"), roaming + "/Godot/app_userdata/FLUX 2", "branding preserves the exact existing Windows profile directory")
 var bootstrap = preload("res://src/app/bootstrap.gd").new()
 bootstrap.player_preferences = PlayerPreferences.new()
 bootstrap.controls_editor = ControlBindingEditor.new()
 bootstrap.player_preferences.keyboard_bindings[&"interact"] = 0
 bootstrap.player_preferences.mouse_bindings[&"interact"] = 0
 bootstrap.player_preferences.controller_bindings[&"interact"] = PlayerPreferences.unbound_controller_binding()
 for device: int in [ControlBindingEditor.DEVICE_KEYBOARD, ControlBindingEditor.DEVICE_MOUSE, ControlBindingEditor.DEVICE_CONTROLLER]:
  bootstrap.station_activation_device = device
  equal(bootstrap._station_interact_label(), "UNBOUND", "actual station caller recognizes editor's unbound sentinel")
  equal(bootstrap._station_interact_instruction("OPEN"), "Bind Interact at Controls Lectern.", "unbound station instruction gives actionable settings path")
 bootstrap.station_activation_device = ControlBindingEditor.DEVICE_KEYBOARD
 bootstrap.player_preferences.keyboard_bindings[&"interact"] = KEY_G
 equal(bootstrap._station_interact_instruction("OPEN"), "G OPEN", "actual station caller displays custom interaction key")
 bootstrap.free()
 return finish("hex-branding")

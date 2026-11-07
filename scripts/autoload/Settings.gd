extends Node
## Player settings (graphics, camera, audio) and the full input map.
## Input is defined here in code so keyboard/mouse and gamepad bindings live in one place.

const PATH := "user://settings.cfg"

signal changed

var data := {
	"quality": 2,            # 0 low, 1 medium, 2 high, 3 ultra
	"render_scale": 1.0,     # 3D resolution scale (FSR upscaling below 1.0)
	"fullscreen": false,
	"vsync": true,
	"fps_cap": 0,
	"mouse_sens": 0.25,
	"pad_sens": 2.6,
	"invert_y": false,
	"cam_distance": 4.2,
	"show_damage_numbers": true,
	"vol_master": 0.8,
	"vol_music": 0.7,
	"vol_ambience": 0.6,
	"vol_sfx": 0.8,
	"vol_ui": 0.6,
}

const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]

# action -> [keyboard/mouse events..., gamepad events...]
# Entries: "k:KEY" key, "m:N" mouse button, "b:N" joypad button, "a:AXIS:+/-" joypad axis.
const BINDINGS := {
	"move_forward": ["k:W", "a:1:-"],
	"move_back": ["k:S", "a:1:+"],
	"move_left": ["k:A", "a:0:-"],
	"move_right": ["k:D", "a:0:+"],
	"cam_left": ["a:2:-"],
	"cam_right": ["a:2:+"],
	"cam_up": ["a:3:-"],
	"cam_down": ["a:3:+"],
	"attack_light": ["m:1", "b:10"],
	"attack_heavy": ["m:2", "a:5:+"],
	"weapon_art": ["k:Q", "a:4:+"],
	"guard": ["k:Ctrl", "b:9"],
	"dodge": ["k:Space", "b:1"],
	"jump": ["k:F", "b:3"],
	"interact": ["k:E", "b:0"],
	"use_item": ["k:R", "b:2"],
	"item_next": ["k:3", "b:14"],
	"item_prev": ["k:1", "b:13"],
	"lock_on": ["m:3", "k:Tab", "b:8"],
	"dive": ["k:C", "b:7"],
	"menu": ["k:Escape", "b:6"],
	"map": ["k:M", "b:4"],
	"ui_tab_next": ["k:PageDown", "k:BracketRight", "b:10"],
	"ui_tab_prev": ["k:PageUp", "k:BracketLeft", "b:9"],
	"zoom_in": ["m:4"],
	"zoom_out": ["m:5"],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	apply_window()

func _setup_input() -> void:
	for action in BINDINGS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.25)
		for spec in BINDINGS[action]:
			var ev := _make_event(spec)
			if ev:
				InputMap.action_add_event(action, ev)
	# Make sure built-in UI navigation works with both sticks/dpad and keyboard.
	var ui_extra := {
		"ui_up": ["a:1:-", "b:11", "k:W"], "ui_down": ["a:1:+", "b:12", "k:S"],
		"ui_left": ["a:0:-", "b:13", "k:A"], "ui_right": ["a:0:+", "b:14", "k:D"],
		"ui_accept": ["b:0", "k:E"], "ui_cancel": ["b:1", "k:Escape"],
	}
	for action in ui_extra:
		for spec in ui_extra[action]:
			var ev := _make_event(spec)
			if ev and not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)

func _make_event(spec: String) -> InputEvent:
	var p := spec.split(":")
	match p[0]:
		"k":
			var e := InputEventKey.new()
			e.physical_keycode = OS.find_keycode_from_string(p[1])
			return e
		"m":
			var e := InputEventMouseButton.new()
			e.button_index = int(p[1]) as MouseButton
			return e
		"b":
			var e := InputEventJoypadButton.new()
			e.button_index = int(p[1]) as JoyButton
			return e
		"a":
			var e := InputEventJoypadMotion.new()
			e.axis = int(p[1]) as JoyAxis
			e.axis_value = -1.0 if p[2] == "-" else 1.0
			return e
	return null

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in data.keys():
			data[k] = cfg.get_value("settings", k, data[k])

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in data.keys():
		cfg.set_value("settings", k, data[k])
	cfg.save(PATH)
	changed.emit()

func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(data.fps_cap)
	var vp := get_viewport()
	vp.scaling_3d_scale = float(data.render_scale)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if float(data.render_scale) < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	var q := int(data.quality)
	vp.msaa_3d = Viewport.MSAA_DISABLED if q < 2 else Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q < 2 else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	RenderingServer.sub_surface_scattering_set_quality([RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_DISABLED, RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_LOW, RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_MEDIUM, RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_HIGH][q])
	changed.emit()

## Applies quality-dependent effects to a world's Environment and sun.
func apply_environment(env: Environment, sun: DirectionalLight3D) -> void:
	var q := int(data.quality)
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = q >= 3
	env.ssr_enabled = q >= 2
	env.ssr_max_steps = 32 if q == 2 else 56
	env.sdfgi_enabled = q >= 3
	env.volumetric_fog_enabled = q >= 3
	env.glow_enabled = true
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = [50.0, 80.0, 120.0, 180.0][q]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q < 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

func vegetation_density() -> float:
	return [0.35, 0.6, 1.0, 1.3][int(data.quality)]

func grass_enabled() -> bool:
	return int(data.quality) >= 1

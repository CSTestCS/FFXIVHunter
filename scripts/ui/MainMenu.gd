extends Node3D
## Title screen: 3D backdrop (waystone + a random adventurer), save slot selection, settings.

var ui: Control
var panel: PanelContainer
var box: VBoxContainer
var cam: Camera3D
var t := 0.0
var hero: CharacterModel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play_music("title")
	Audio.play_ambience("wind")
	_backdrop()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UIKit.theme()
	layer.add_child(ui)
	var title := UIKit.label("AETHER HUNTER", 92, UIKit.GOLD)
	title.position = Vector2(110, 90)
	ui.add_child(title)
	var sub := UIKit.label("An adventurer's tale of hunts, writs and roads", 26, UIKit.TEXT)
	sub.position = Vector2(116, 205)
	ui.add_child(sub)
	panel = UIKit.panel(20)
	panel.position = Vector2(110, 300)
	panel.custom_minimum_size = Vector2(620, 0)
	ui.add_child(panel)
	box = UIKit.vbox(10)
	panel.add_child(box)
	var ver := UIKit.label("v1.1  ·  Placeholder VRoid models (built-in models: docs/MODELS.md)", 16, UIKit.DIM)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_top = -40
	ver.offset_left = 20
	ui.add_child(ver)
	_main()

func _backdrop() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1a2a4a")
	sm.sky_horizon_color = Color("e89a5c")
	sm.ground_horizon_color = Color("e89a5c")
	sm.ground_bottom_color = Color("1a1a22")
	var sky := Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("e8a070")
	env.fog_density = 0.035
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, 140, 0)
	sun.light_color = Color("ffb070")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	ground.material_override = MeshKit.pbr(Color("3a4a2a"), 0.95)
	add_child(ground)
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3(0, 2.8, 0), Vector3(0.6, 1.8, 0.6), Basis(), 6, 4)
	var crystal := MeshInstance3D.new()
	crystal.mesh = MeshKit.finish(st, MeshKit.pbr(Color("3f8fd0"), 0.08, 0.2, Color("4fb8ff"), 1.2))
	crystal.name = "Crystal"
	crystal.position = Vector3(2.2, 0, -1.5)
	add_child(crystal)
	var l := OmniLight3D.new()
	l.light_color = Color("7fd4ff")
	l.omni_range = 8.0
	l.position = Vector3(2.2, 2.5, -1.5)
	add_child(l)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	hero = CharacterModel.new()
	add_child(hero)
	var jobs := DB.jobs.keys()
	var job: String = jobs[rng.randi() % jobs.size()]
	hero.build(DB.RacesData.randomize_appearance(rng), ["plate_set", "ranger_garb", "sea_coat", "desert_silks", "scholar_robes"][rng.randi() % 5], DB.jobs[job].weapon, 3)
	hero.rotation.y = PI - 0.35
	# a few trees and stones so the horizon isn't empty
	var bark := MeshKit.vcol_pbr(0.9)
	bark.albedo_color = Color(0.7, 0.6, 0.5)
	for i in range(14):
		var kind: String = ["pine", "broadleaf", "dead"][i % 3]
		var meshes := Vegetation.tree_meshes(kind)
		var a := rng.randf_range(-1.2, 1.9)
		var d := rng.randf_range(9.0, 26.0)
		for k in range(2):
			if (meshes[k] as Mesh).get_surface_count() == 0:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[k]
			mi.material_override = bark if k == 0 else MeshKit.pbr(Color("3a5a2a"), 0.8)
			mi.position = Vector3(sin(a) * d, -0.2, -cos(a) * d)
			mi.rotation.y = rng.randf() * TAU
			mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
			add_child(mi)
	for i in range(8):
		var st2 := MeshKit.begin()
		MeshKit.rock(st2, Vector3.ZERO, Vector3(1.0, 0.6, 0.8) * rng.randf_range(0.4, 1.4), i)
		var r := MeshInstance3D.new()
		r.mesh = MeshKit.finish(st2, MeshKit.pbr(Color("6a6660"), 0.85))
		var a2 := rng.randf_range(-1.0, 1.6)
		r.position = Vector3(sin(a2) * rng.randf_range(4.0, 14.0), 0.0, -cos(a2) * rng.randf_range(4.0, 14.0))
		add_child(r)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.look_at_from_position(Vector3(-1.4, 1.45, 3.0), Vector3(0.9, 1.15, 0))

func _process(delta: float) -> void:
	t += delta
	if hero:
		hero.animate(delta, Poses.idle(t, hero.weapon_kind), 8.0)
	var c := get_node_or_null("Crystal")
	if c:
		c.rotation.y += delta * 0.5
	cam.position.x = -1.4 + sin(t * 0.1) * 0.3

func _clear() -> void:
	UIKit.clear(box)

func _btn(text: String, cb: Callable, enabled := true) -> void:
	var b := UIKit.button(text, cb, 560)
	b.disabled = not enabled
	box.add_child(b)

func _focus() -> void:
	await get_tree().process_frame
	UIKit.focus_first(box)

func _latest_slot() -> int:
	var best := -1
	var best_date := ""
	for i in range(Saves.SLOT_COUNT):
		var s := Saves.summary(i)
		if not s.is_empty() and String(s.date) > best_date:
			best_date = s.date
			best = i
	return best

func _main() -> void:
	_clear()
	var latest := _latest_slot()
	_btn("Continue", func(): Saves.load_into_game(latest), latest >= 0)
	_btn("New Game", _new_game)
	_btn("Load Game", _load_game)
	_btn("Settings", _settings)
	_btn("Quit", func(): get_tree().quit())
	_focus()

func _slot_text(i: int) -> String:
	var s := Saves.summary(i)
	if s.is_empty():
		return "Slot %d  —  Empty" % (i + 1)
	return "Slot %d  —  %s, Lv.%d %s  ·  %s  ·  %s" % [i + 1, s.name, int(s.level), s.job, s.region, s.time]

func _new_game() -> void:
	_clear()
	box.add_child(UIKit.label("Choose a save slot", 28, UIKit.GOLD))
	for i in range(Saves.SLOT_COUNT):
		var idx := i
		_btn(_slot_text(i), func():
			if Saves.exists(idx):
				_confirm("Overwrite slot %d?" % (idx + 1), func():
					Saves.delete(idx)
					Game.goto_creator(idx))
			else:
				Game.goto_creator(idx))
	_btn("Back", _main)
	_focus()

func _load_game() -> void:
	_clear()
	box.add_child(UIKit.label("Load game", 28, UIKit.GOLD))
	for i in range(Saves.SLOT_COUNT):
		var idx := i
		var row := UIKit.hbox(6)
		var b := UIKit.button(_slot_text(i), func(): Saves.load_into_game(idx), 470)
		b.disabled = not Saves.exists(i)
		row.add_child(b)
		var d := UIKit.button("Delete", func(): _confirm("Delete slot %d permanently?" % (idx + 1), func():
			Saves.delete(idx)
			_load_game()), 90)
		d.disabled = not Saves.exists(i)
		row.add_child(d)
		box.add_child(row)
	_btn("Back", _main)
	_focus()

func _confirm(text: String, yes: Callable) -> void:
	_clear()
	box.add_child(UIKit.label(text, 26, UIKit.GOLD))
	_btn("Yes", yes)
	_btn("No", _main)
	_focus()

func _settings() -> void:
	_clear()
	var s := SettingsMenu.new()
	box.add_child(s)
	_btn("Back", _main)
	_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_main()

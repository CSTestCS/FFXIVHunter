extends Node3D
## Character creation: your adventurer AND the legendary Lightbearer (the world's famous hero),
## then job selection. Every option works with mouse, keyboard and gamepad
## (D-pad/stick up-down to move, left-right to change a value, LB/RB to switch categories).

const RacesData := preload("res://scripts/data/races.gd")
const CATS := ["Race", "Body", "Face", "Eyes", "Hair", "Features", "Name"]

var looks := {}
var editing := "player"
var hero_job := "paladin"
var job := ""
var cat := 0
var step := "look"
var model: CharacterModel
var cam: Camera3D
var orbit := 0.0
var zoom_face := false
var t := 0.0
var left: VBoxContainer
var opts: VBoxContainer
var info: Label
var tabs: HBoxContainer
var who: HBoxContainer
var _rebuild_pending := false
var _dragging := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play_music("town")
	Audio.play_ambience("")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	looks.player = RacesData.randomize_appearance(rng, "hume")
	looks.player.first_name = _random_name(rng)
	looks.player.last_name = _random_name(rng)
	looks.hero = RacesData.randomize_appearance(rng)
	looks.hero.first_name = "Aster"
	looks.hero.last_name = "Vale"
	_stage()
	_ui()
	_refresh_model()
	_build_options()

func _random_name(rng: RandomNumberGenerator) -> String:
	var a := ["Ka", "Ly", "Mor", "Ae", "Thal", "Bry", "Se", "Va", "Or", "Fen", "Ri", "Ca", "Dra", "El", "Ny", "Jo"]
	var b := ["ra", "en", "vin", "lia", "dor", "wyn", "ric", "sa", "mir", "th", "na", "ros", "ka", "lle"]
	return a[rng.randi() % a.size()] + b[rng.randi() % b.size()]

func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10141e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8a49c")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -20, 0)
	key.light_energy = 1.3
	key.light_color = Color("fff1e0")
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color("c8d8ff")
	add_child(rim)
	var floor := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.7
	cyl.height = 0.12
	floor.mesh = cyl
	floor.position.y = -0.06
	floor.material_override = MeshKit.pbr(Color("2a2c30"), 0.5, 0.3)
	add_child(floor)
	model = CharacterModel.new()
	model.rotation.y = PI  # face the camera
	add_child(model)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)
	var p := UIKit.panel(18)
	p.anchor_bottom = 1.0
	p.offset_left = 30
	p.offset_top = 30
	p.offset_right = 760
	p.offset_bottom = -30
	root.add_child(p)
	left = UIKit.vbox(10)
	p.add_child(left)
	who = UIKit.hbox(8)
	left.add_child(who)
	tabs = UIKit.hbox(4)
	left.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	opts = UIKit.vbox(8)
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(opts)
	info = UIKit.label("", 17, UIKit.DIM, true)
	info.custom_minimum_size = Vector2(700, 0)
	left.add_child(info)
	var help := UIKit.label("Right side: drag / right stick to rotate · wheel or Y / F to toggle face view · LB/RB: categories", 16, UIKit.DIM)
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -900
	help.offset_top = -50
	help.offset_right = -30
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(help)

func _look() -> Dictionary:
	return looks[editing]

# ------------------------------------------------------------------ option building
func _build_options() -> void:
	UIKit.clear(who)
	UIKit.clear(tabs)
	UIKit.clear(opts)
	if step == "job":
		_build_jobs()
		return
	for w in [["player", "Your Adventurer"], ["hero", "The Lightbearer"]]:
		var ww: String = w[0]
		var b := UIKit.button(("▶ " if editing == ww else "") + w[1], func():
			editing = ww
			_refresh_model()
			_build_options(), 340)
		who.add_child(b)
	for i in range(CATS.size()):
		var idx := i
		var b := UIKit.button(CATS[i], func():
			cat = idx
			_build_options(), 92)
		b.modulate = UIKit.GOLD if i == cat else Color.WHITE
		tabs.add_child(b)
	if editing == "hero":
		info.text = "The Lightbearer is the legendary hero who saved the realm alongside the Dawnward Circle. They appear in the story's cameos looking exactly as you design them here."
	else:
		info.text = "Your adventurer: no legend, just a traveller with a long road ahead."
	var a := _look()
	var r: Dictionary = DB.races[a.race]
	match CATS[cat]:
		"Race":
			var race_ids: Array = DB.races.keys()
			_stepper("Race", race_ids.map(func(x): return DB.races[x].name), race_ids.find(a.race), func(i):
				a.race = race_ids[i]
				a.clan = DB.races[a.race].clans.keys()[0]
				a.ears = 0
				a.tail = 0
				a.horns = 0
				a.skin = mini(int(a.skin), 3)
				a.model_variant = 0, true)
			var clan_ids: Array = r.clans.keys()
			_stepper("Clan", clan_ids.map(func(x): return r.clans[x].name), clan_ids.find(a.clan), func(i):
				a.clan = clan_ids[i]
				a.model_variant = 0)
			_note(r.desc + "\n" + r.clans[a.clan].desc)
			_stepper("Body type", ["Feminine", "Masculine"], 0 if a.body == "feminine" else 1, func(i):
				a.body = ["feminine", "masculine"][i]
				a.model_variant = 0)
			var variants := ModelLibrary.body_variants(a.race, a.clan, a.body)
			if variants.size() > 1:
				_stepper("Body model", variants.map(func(p): return (p as String).get_file().get_basename().capitalize()), int(a.get("model_variant", 0)), func(i): a.model_variant = i)
			var tones: Array = r.clans[a.clan].skin
			_swatches("Skin tone", tones, int(a.skin), func(i): a.skin = i)
			_stepper("Voice", RacesData.VOICES, int(a.voice), func(i): a.voice = i)
		"Body":
			_slider("Height (%d cm)" % int(RacesData.height_cm(a)), "height")
			_slider("Muscle tone", "muscle")
			_slider("Bust size", "bust")
			_slider("Build", "weight")
		"Face":
			_stepper("Face", RacesData.FACE_PRESETS, int(a.face), func(i): a.face = i)
			_stepper("Facial marking", RacesData.FACE_MARKINGS, int(a.marking), func(i): a.marking = i)
			_colors("Marking colour", RacesData.PAINT_COLORS, "marking_color")
			_colors("Lip colour", ["#b46a6a", "#c97a7a", "#8a3a4a", "#d89a8a", "#6a3a5a", "#a05050"], "lip_color")
		"Eyes":
			_stepper("Eye shape", RacesData.EYE_SHAPES, int(a.eye_shape), func(i): a.eye_shape = i)
			_slider("Eye size", "eye_size")
			_colors("Eye colour", RacesData.EYE_COLORS, "eye_color")
			_stepper("Heterochromia", ["Off", "On"], 1 if a.heterochromia else 0, func(i): a.heterochromia = i == 1)
			if a.heterochromia:
				_colors("Right eye colour", RacesData.EYE_COLORS, "eye_color_r")
		"Hair":
			var styles: Array = RacesData.HAIRSTYLES.duplicate()
			for extra in ModelLibrary.extra_hairstyles(styles.map(func(h): return h.id)):
				styles.append({"id": extra, "name": (extra as String).capitalize()})
			_stepper("Hairstyle", styles.map(func(h): return h.name), maxi(0, styles.map(func(h): return h.id).find(a.hair)), func(i): a.hair = styles[i].id)
			_colors("Hair colour", RacesData.HAIR_COLORS, "hair_color")
			_stepper("Highlights", ["Off", "On"], 1 if a.highlights else 0, func(i): a.highlights = i == 1)
			if a.highlights:
				_colors("Highlight colour", RacesData.HAIR_COLORS, "highlight_color")
		"Features":
			if not (r.ears as Array).is_empty() and r.ears[0] != "human":
				_stepper("Ears", (r.ears as Array).map(func(x): return x.replace("_", " ").capitalize()), int(a.ears), func(i): a.ears = i)
			if not (r.tail as Array).is_empty():
				_stepper("Tail", (r.tail as Array).map(func(x): return x.replace("_", " ").capitalize()), int(a.tail), func(i): a.tail = i)
				_slider("Tail length", "tail_length")
			if not (r.horns as Array).is_empty():
				_stepper("Horns", (r.horns as Array).map(func(x): return x.capitalize()), int(a.horns), func(i): a.horns = i)
			if a.race in ["draeki"] or not (r.tail as Array).is_empty() or not (r.horns as Array).is_empty():
				_colors("Scale / horn / tail colour", RacesData.HAIR_COLORS, "scale_color")
			if opts.get_child_count() == 0:
				_note("%s have no extra racial features to adjust." % r.name)
		"Name":
			_text_field("First name", "first_name")
			_text_field("Last name", "last_name")
			if editing == "player":
				_stepper("Nameday: day", range(1, 33).map(func(x): return str(x)), int(a.nameday_day) - 1, func(i): a.nameday_day = i + 1, false)
				_stepper("Nameday: month", ["1st Astral", "1st Umbral", "2nd Astral", "2nd Umbral", "3rd Astral", "3rd Umbral", "4th Astral", "4th Umbral", "5th Astral", "5th Umbral", "6th Astral", "6th Umbral"], int(a.nameday_month) - 1, func(i): a.nameday_month = i + 1, false)
				_stepper("Guardian", RacesData.DEITIES.map(func(d): return d.name), int(a.deity), func(i): a.deity = i, false)
			else:
				var jl: Array = DB.jobs.keys()
				_stepper("Signature job", jl.map(func(j): return DB.jobs[j].name), jl.find(hero_job), func(i): hero_job = jl[i])
	var row := UIKit.hbox(8)
	row.add_child(UIKit.button("Randomize", _randomize, 200))
	row.add_child(UIKit.button("Copy look from the other", func():
		var other := "hero" if editing == "player" else "player"
		var keep := [looks[editing].first_name, looks[editing].last_name]
		looks[editing] = looks[other].duplicate()
		looks[editing].first_name = keep[0]
		looks[editing].last_name = keep[1]
		_refresh_model()
		_build_options(), 300))
	row.add_child(UIKit.button("Next: Choose Job ▶", _go_jobs, 220))
	opts.add_child(row)
	_focus_later()

func _focus_later() -> void:
	await get_tree().process_frame
	UIKit.focus_first(opts)

func _note(text: String) -> void:
	var l := UIKit.label(text, 17, UIKit.DIM, true)
	l.custom_minimum_size = Vector2(680, 0)
	opts.add_child(l)

func _row(label: String) -> HBoxContainer:
	var h := UIKit.hbox(8)
	var l := UIKit.label(label, 19)
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	opts.add_child(h)
	return h

## Value stepper: focus the value button and use left/right (or click the arrows).
func _stepper(label: String, values: Array, idx: int, cb: Callable, rebuild := true) -> void:
	var h := _row(label)
	idx = clampi(idx, 0, maxi(0, values.size() - 1))
	var state := [idx]
	var mid := Button.new()
	mid.text = str(values[idx]) if not values.is_empty() else "-"
	mid.custom_minimum_size = Vector2(300, 40)
	var change := func(dir: int):
		if values.is_empty():
			return
		state[0] = (state[0] + dir + values.size()) % values.size()
		mid.text = str(values[state[0]])
		cb.call(state[0])
		_changed(rebuild)
	var lb := UIKit.button("◀", func(): change.call(-1), 44)
	lb.focus_mode = Control.FOCUS_NONE
	var rb := UIKit.button("▶", func(): change.call(1), 44)
	rb.focus_mode = Control.FOCUS_NONE
	mid.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left"):
			change.call(-1)
			mid.accept_event()
		elif ev.is_action_pressed("ui_right"):
			change.call(1)
			mid.accept_event())
	mid.pressed.connect(func(): change.call(1))
	h.add_child(lb)
	h.add_child(mid)
	h.add_child(rb)

func _slider(label: String, key: String) -> void:
	var h := _row(label)
	var a := _look()
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.02
	s.value = float(a[key])
	s.custom_minimum_size = Vector2(390, 36)
	s.value_changed.connect(func(v):
		a[key] = v
		_changed(false))
	if key == "height":
		s.drag_ended.connect(func(_c): _build_options())
	h.add_child(s)

func _swatches(label: String, colors: Array, idx: int, cb: Callable) -> void:
	_stepper(label, colors.map(func(c): return "■ " + str(c)), idx, cb, false)
	_tint_last(colors, idx)

func _colors(label: String, palette: Array, key: String) -> void:
	var a := _look()
	var idx := palette.find(a[key])
	_stepper(label, palette.map(func(c): return "■ " + str(c)), maxi(idx, 0), func(i): a[key] = palette[i], false)
	var h: HBoxContainer = opts.get_child(opts.get_child_count() - 1)
	var cp := ColorPickerButton.new()
	cp.color = Color(a[key])
	cp.custom_minimum_size = Vector2(44, 40)
	cp.focus_mode = Control.FOCUS_NONE
	cp.color_changed.connect(func(c):
		a[key] = "#" + c.to_html(false)
		_changed(false))
	h.add_child(cp)
	_tint_last(palette, idx)

func _tint_last(_colors_list: Array, _idx: int) -> void:
	var h: HBoxContainer = opts.get_child(opts.get_child_count() - 1)
	var mid: Button = h.get_child(2)
	mid.add_theme_color_override("font_color", Color(mid.text.substr(2)))
	mid.add_theme_color_override("font_focus_color", Color(mid.text.substr(2)).lightened(0.2))

func _text_field(label: String, key: String) -> void:
	var h := _row(label)
	var a := _look()
	var e := LineEdit.new()
	e.text = a[key]
	e.max_length = 15
	e.custom_minimum_size = Vector2(390, 40)
	e.text_changed.connect(func(tx): a[key] = tx.strip_edges())
	h.add_child(e)

func _changed(rebuild: bool) -> void:
	if not _rebuild_pending:
		_rebuild_pending = true
		_deferred_refresh.call_deferred(rebuild)

func _deferred_refresh(rebuild: bool) -> void:
	_rebuild_pending = false
	_refresh_model()
	if rebuild:
		_build_options()

func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var keep := [_look().first_name, _look().last_name, _look().nameday_day, _look().nameday_month, _look().deity]
	looks[editing] = RacesData.randomize_appearance(rng)
	var a := _look()
	a.first_name = keep[0]
	a.last_name = keep[1]
	a.nameday_day = keep[2]
	a.nameday_month = keep[3]
	a.deity = keep[4]
	_refresh_model()
	_build_options()

func _refresh_model() -> void:
	var outfit := "simple_tunic" if editing == "player" else "dawnward_regalia"
	var wk := ""
	if step == "job" and job != "":
		wk = DB.jobs[job].weapon
	elif editing == "hero":
		wk = DB.jobs[hero_job].weapon
	model.build(_look(), outfit, wk, 2 if editing == "player" else 5)

# ------------------------------------------------------------------ job selection
func _go_jobs() -> void:
	if String(looks.player.first_name) == "" or String(looks.player.last_name) == "":
		info.text = "Your adventurer needs a first and last name (Name tab)."
		cat = CATS.find("Name")
		editing = "player"
		_build_options()
		return
	if String(looks.hero.first_name) == "":
		looks.hero.first_name = "Aster"
	step = "job"
	editing = "player"
	if job == "":
		job = "paladin"
	_refresh_model()
	_build_options()

func _build_jobs() -> void:
	info.text = "Every job is open to you from the start. Each plays like its own weapon type. You'll begin outside the city tied to your job, and can learn the others later."
	who.add_child(UIKit.label("Choose your starting job", 28, UIKit.GOLD))
	for city in DB.CITY_ORDER:
		opts.add_child(UIKit.label(DB.regions[city].name + "  —  " + DB.regions[city].subtitle, 22, UIKit.GOLD))
		var h := HFlowContainer.new()
		opts.add_child(h)
		for j in DB.jobs:
			if DB.jobs[j].city != city:
				continue
			var jj: String = j
			var b := UIKit.button(("✔ " if job == j else "") + DB.jobs[j].name, func():
				job = jj
				_refresh_model()
				_build_options(), 160)
			b.focus_entered.connect(func(): _describe(jj))
			h.add_child(b)
	var jd: Dictionary = DB.jobs[job]
	var desc := UIKit.label("%s  (%s)\n%s\nWeapon: %s · Difficulty: %s · Starts near %s\nMoves: %s" % [jd.name, jd.role, jd.desc, jd.weapon.replace("_", " & ").capitalize(), "★".repeat(int(jd.difficulty)), DB.regions[jd.city].name,
		", ".join(_move_names(jd))], 18, UIKit.TEXT, true)
	desc.custom_minimum_size = Vector2(680, 0)
	desc.name = "Desc"
	opts.add_child(desc)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.button("◀ Back to appearance", func():
		step = "look"
		_refresh_model()
		_build_options(), 280))
	row.add_child(UIKit.button("Begin your adventure ▶", _begin, 320))
	opts.add_child(row)
	_focus_later()

func _move_names(jd: Dictionary) -> Array:
	var out := []
	for k in jd.moves:
		if k == "ART":
			out.append("Weapon Art: " + jd.moves[k].get("name", "Art"))
	out.append("Guard: " + jd.guard.capitalize())
	out.append("Evade: " + jd.dodge.capitalize())
	return out

func _describe(j: String) -> void:
	var d := opts.find_child("Desc", true, false) as Label
	if d:
		var jd: Dictionary = DB.jobs[j]
		d.text = "%s  (%s)\n%s\nWeapon: %s · Difficulty: %s · Starts near %s\n%s" % [jd.name, jd.role, jd.desc, jd.weapon.replace("_", " & ").capitalize(), "★".repeat(int(jd.difficulty)), DB.regions[jd.city].name, ", ".join(_move_names(jd))]

func _begin() -> void:
	set_process(false)
	Game.new_game(Game.current_slot, looks.player, looks.hero, job, hero_job)

# ------------------------------------------------------------------ preview camera
func _process(delta: float) -> void:
	t += delta
	var pose: Dictionary
	if step == "job" and job != "":
		var m: Dictionary = DB.jobs[job].moves.L1
		var k := fmod(t * 0.7, 2.2)
		if k < 1.2:
			pose = Poses.idle(t, DB.jobs[job].weapon)
		else:
			var ph := 0 if k < 1.5 else (1 if k < 1.7 else 2)
			var kk := clampf((k - [1.2, 1.5, 1.7][ph]) / [0.3, 0.2, 0.5][ph], 0.0, 1.0)
			pose = Poses.attack(m.anim, ph, kk, Poses.idle(t, DB.jobs[job].weapon))
	else:
		pose = Poses.idle(t, model.weapon_kind)
	model.animate(delta, pose, 14.0)
	orbit += Input.get_axis("cam_left", "cam_right") * delta * 2.0
	var h := model.height_m
	var target := Vector3(0, h * (0.93 if zoom_face else 0.55), 0)
	var dist := h * (0.42 if zoom_face else 1.55) + 0.6
	var dir := Vector3(sin(orbit), 0.08, cos(orbit))
	var pos := target + dir.normalized() * dist
	cam.global_position = cam.global_position.lerp(pos, 1.0 - exp(-8.0 * delta)) if cam.global_position != Vector3.ZERO else pos
	cam.look_at(target + cam.global_transform.basis.x * (-dist * 0.32), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed and mb.position.x > 800
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_face = mb.button_index == MOUSE_BUTTON_WHEEL_UP
	elif event is InputEventMouseMotion and _dragging:
		orbit -= (event as InputEventMouseMotion).relative.x * 0.01
	elif event.is_action_pressed("jump"):
		zoom_face = not zoom_face
	elif event.is_action_pressed("ui_tab_next") and step == "look":
		cat = (cat + 1) % CATS.size()
		_build_options()
	elif event.is_action_pressed("ui_tab_prev") and step == "look":
		cat = (cat - 1 + CATS.size()) % CATS.size()
		_build_options()
	elif event.is_action_pressed("ui_cancel"):
		if step == "job":
			step = "look"
			_refresh_model()
			_build_options()
		else:
			Game.goto_main_menu()

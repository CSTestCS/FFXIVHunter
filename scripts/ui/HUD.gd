class_name HUD
extends CanvasLayer
## In-game HUD and dialogue. Built in code; works with mouse, keyboard and gamepad.

signal dialogue_done(choice: int)

var world: Node
var root: Control
var hp_bar: ProgressBar
var st_bar: ProgressBar
var mp_bar: ProgressBar
var gauge_bar: ProgressBar
var gauge_label: Label
var name_label: Label
var tracker: Label
var prompt: Label
var item_label: Label
var meal_label: Label
var toast_box: VBoxContainer
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss_target: Actor
var timer_box: VBoxContainer
var timer_label: Label
var timer_bar: ProgressBar
var breath_bar: ProgressBar
var minimap: Control
var region_label: Label
var reticle: Control
var fade_rect: ColorRect
var letter_top: ColorRect
var letter_bot: ColorRect
var uw_rect: ColorRect
var loading: Control
var banner_box: VBoxContainer
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: RichTextLabel
var dlg_choices: VBoxContainer
var dlg_hint: Label
var objective_pos = null
var _dlg_lines: Array = []
var _dlg_i := 0
var _dlg_choices_list: Array = []
var _typing := 0.0
var _dlg_open := false

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)
	uw_rect = ColorRect.new()
	uw_rect.color = Color(0.1, 0.35, 0.5, 0.28)
	uw_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	uw_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uw_rect.visible = false
	root.add_child(uw_rect)
	_build_bars()
	_build_right()
	_build_center()
	_build_dialogue()
	letter_top = _bar_rect(true)
	letter_bot = _bar_rect(false)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	_build_loading()

func _build_bars() -> void:
	var box := UIKit.vbox(4)
	box.position = Vector2(28, 24)
	root.add_child(box)
	name_label = UIKit.label("", 22, UIKit.GOLD)
	box.add_child(name_label)
	hp_bar = UIKit.bar(Color("4fbf63"), 380, 20)
	box.add_child(hp_bar)
	st_bar = UIKit.bar(Color("e8c64a"), 320, 12)
	box.add_child(st_bar)
	mp_bar = UIKit.bar(Color("5aa0ff"), 320, 10)
	box.add_child(mp_bar)
	var gh := UIKit.hbox(8)
	box.add_child(gh)
	gauge_label = UIKit.label("", 18, UIKit.DIM)
	gh.add_child(gauge_label)
	gauge_bar = UIKit.bar(Color("e06a3a"), 200, 10)
	gh.add_child(gauge_bar)
	var tp := UIKit.panel(10)
	tp.position = Vector2(24, 210)
	tp.custom_minimum_size = Vector2(430, 0)
	tp.modulate.a = 0.92
	root.add_child(tp)
	tracker = UIKit.label("", 19, UIKit.TEXT, true)
	tracker.custom_minimum_size = Vector2(400, 0)
	tp.add_child(tracker)
	var br := UIKit.vbox(2)
	br.anchor_left = 1.0
	br.anchor_right = 1.0
	br.anchor_top = 1.0
	br.anchor_bottom = 1.0
	br.offset_left = -420
	br.offset_top = -120
	br.offset_right = -28
	br.offset_bottom = -24
	br.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(br)
	meal_label = UIKit.label("", 17, UIKit.DIM)
	meal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(meal_label)
	item_label = UIKit.label("", 22, UIKit.TEXT)
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(item_label)

func _build_right() -> void:
	minimap = Minimap.new()
	minimap.hud = self
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -248
	minimap.offset_right = -24
	minimap.offset_top = 24
	minimap.offset_bottom = 248
	root.add_child(minimap)
	region_label = UIKit.label("", 18, UIKit.TEXT)
	region_label.anchor_left = 1.0
	region_label.anchor_right = 1.0
	region_label.offset_left = -400
	region_label.offset_right = -24
	region_label.offset_top = 252
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(region_label)
	toast_box = UIKit.vbox(4)
	toast_box.anchor_left = 1.0
	toast_box.anchor_right = 1.0
	toast_box.offset_left = -520
	toast_box.offset_right = -24
	toast_box.offset_top = 290
	root.add_child(toast_box)

func _build_center() -> void:
	boss_box = UIKit.vbox(2)
	boss_box.anchor_left = 0.5
	boss_box.anchor_right = 0.5
	boss_box.offset_left = -360
	boss_box.offset_right = 360
	boss_box.offset_top = 24
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = UIKit.label("", 24, UIKit.GOLD)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = UIKit.bar(Color("c83a2a"), 720, 16)
	boss_box.add_child(boss_bar)
	timer_box = UIKit.vbox(2)
	timer_box.anchor_left = 0.5
	timer_box.anchor_right = 0.5
	timer_box.offset_left = -220
	timer_box.offset_right = 220
	timer_box.offset_top = 92
	timer_box.visible = false
	root.add_child(timer_box)
	timer_label = UIKit.label("", 22, UIKit.TEXT)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_box.add_child(timer_label)
	timer_bar = UIKit.bar(Color("4fbf63"), 440, 10)
	timer_box.add_child(timer_bar)
	breath_bar = UIKit.bar(Color("7fd4ff"), 260, 10)
	breath_bar.anchor_left = 0.5
	breath_bar.anchor_right = 0.5
	breath_bar.anchor_top = 0.62
	breath_bar.anchor_bottom = 0.62
	breath_bar.offset_left = -130
	breath_bar.offset_right = 130
	breath_bar.visible = false
	root.add_child(breath_bar)
	prompt = UIKit.label("", 24, UIKit.TEXT)
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 0.7
	prompt.anchor_bottom = 0.7
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	reticle = Reticle.new()
	reticle.hud = self
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reticle)
	banner_box = UIKit.vbox(0)
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.anchor_top = 0.22
	banner_box.offset_left = -500
	banner_box.offset_right = 500
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)

func _build_dialogue() -> void:
	dlg = UIKit.panel(20)
	dlg.anchor_left = 0.5
	dlg.anchor_right = 0.5
	dlg.anchor_top = 1.0
	dlg.anchor_bottom = 1.0
	dlg.offset_left = -640
	dlg.offset_right = 640
	dlg.offset_top = -270
	dlg.offset_bottom = -40
	dlg.visible = false
	root.add_child(dlg)
	var v := UIKit.vbox(6)
	dlg.add_child(v)
	dlg_name = UIKit.label("", 26, UIKit.GOLD)
	v.add_child(dlg_name)
	dlg_text = RichTextLabel.new()
	dlg_text.bbcode_enabled = false
	dlg_text.fit_content = true
	dlg_text.custom_minimum_size = Vector2(1200, 90)
	dlg_text.add_theme_font_size_override("normal_font_size", 25)
	dlg_text.scroll_active = false
	v.add_child(dlg_text)
	dlg_choices = UIKit.vbox(4)
	v.add_child(dlg_choices)
	dlg_hint = UIKit.label("▶  E / A / Click", 16, UIKit.DIM)
	dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(dlg_hint)

func _bar_rect(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	r.offset_top = 0 if top else 0
	r.offset_bottom = 0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r

func _build_loading() -> void:
	loading = ColorRect.new()
	(loading as ColorRect).color = Color("080b12")
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(loading)
	var v := UIKit.vbox(10)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -400
	v.offset_right = 400
	v.offset_top = -60
	loading.add_child(v)
	var t := UIKit.label("", 48, UIKit.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.name = "Title"
	v.add_child(t)
	var s := UIKit.label("", 22, UIKit.DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.name = "Sub"
	v.add_child(s)
	var tips := ["Watch the glowing ground markers: that's where the blow will land.", "Eat before a hunt: main dish, side and drink each help in a different way.",
		"Tap dodge to roll through attacks; hold it to sprint.", "Fainting three times fails a mission. Fainting in the wild drops some gil where you fell.",
		"Resting at a waystone heals you, refills the wilds and saves your game.", "Large monsters enrage at half health. Their attacks come faster.",
		"Blunt weapons crack shells and stone; magic burns aether-born foes.", "Hold C (or L3) to dive. Pearls glimmer on the lake and sea floor."]
	var tip := UIKit.label("Tip: " + tips[randi() % tips.size()], 18, UIKit.TEXT, true)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size = Vector2(800, 0)
	v.add_child(tip)

# ------------------------------------------------------------------ API
func show_loading(title: String, sub: String) -> void:
	loading.visible = true
	loading.find_child("Title", true, false).text = title
	loading.find_child("Sub", true, false).text = sub + "\n\nGenerating region..."

func hide_loading() -> void:
	var tw := create_tween()
	tw.tween_property(loading, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): loading.visible = false)

func setup_for_world() -> void:
	minimap.tex = world.map_tex
	region_label.text = world.rd.name
	refresh()

func banner(title: String, sub: String) -> void:
	UIKit.clear(banner_box)
	var t := UIKit.label(title, 56, UIKit.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(t)
	var s := UIKit.label(sub, 24, UIKit.TEXT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(s)
	var tw := create_tween()
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.2)
	tw.tween_property(banner_box, "modulate:a", 0.0, 1.2)

func set_prompt(text: String) -> void:
	prompt.text = "" if text == "" else "[E / A]  " + text

func toast(text: String) -> void:
	var l := UIKit.label(text, 19, UIKit.TEXT, true)
	l.custom_minimum_size = Vector2(490, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast_box.add_child(l)
	if toast_box.get_child_count() > 6:
		toast_box.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)

func boss(m: Actor) -> void:
	boss_target = m
	boss_box.visible = m != null
	if m:
		boss_name.text = "%s  —  %s" % [m.display_name, DB.monsters[m.id].get("title", "")]

func set_timer(t: float, text: String, ratio: float) -> void:
	if t == -1.0:
		timer_box.visible = false
		return
	timer_box.visible = true
	timer_label.text = text if t < 0.0 else "%s  %d:%02d" % [text, int(t) / 60, int(t) % 60]
	timer_bar.value = ratio * 100.0

func set_objective(p) -> void:
	objective_pos = p

func set_underwater(v: bool) -> void:
	uw_rect.visible = v

func letterbox(on: bool) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(letter_top, "offset_bottom", 110.0 if on else 0.0, 0.5)
	tw.tween_property(letter_bot, "offset_top", -110.0 if on else 0.0, 0.5)
	for c in [hp_bar.get_parent(), tracker.get_parent(), minimap, region_label, item_label.get_parent(), prompt]:
		c.visible = not on

func fade(alpha: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, t)
	await tw.finished

func fade_instant(alpha: float) -> void:
	fade_rect.color.a = alpha

func refresh() -> void:
	if world == null or world.player == null or Game.state.is_empty():
		return
	var p: Player = world.player
	name_label.text = "%s   Lv.%d %s" % [Game.player_name(), Game.job_level(), DB.jobs[Game.state.job].name]
	var gname: String = DB.JobsData.GAUGE_NAMES.get(p.jd.gauge, "")
	gauge_label.text = gname
	gauge_bar.visible = gname != "" and gname != "Mana"
	gauge_label.visible = gauge_bar.visible or p.jd.gauge == "ammo"
	mp_bar.visible = p.jd.gauge == "mana"
	var lines := []
	for id in Game.active_quests():
		var q: Dictionary = DB.quests[id]
		var mark := "◆ " if q.type == "main" else "◇ "
		var status := Game.quest_progress_text(id)
		if Game.quest_ready(id):
			status = "Report to %s" % DB.npcs[Game.quest_turn_in(id)].name
		lines.append("%s%s\n    %s" % [mark, q.name, status])
	var w: Dictionary = Game.state.get("writ", {})
	if not w.is_empty():
		var prog := ""
		if w.kind in ["hunt_small", "gather"]:
			prog = " (%d/%d)" % [int(w.get("progress", 0)), int(w.count)]
		lines.append("▣ Writ: %s\n    %s%s" % [w.title, Game.writ_text(w), prog])
	tracker.text = "\n".join(lines) if not lines.is_empty() else "No active quests. Visit the guild!"
	var qi: String = Game.state.get("quick_item", "potion")
	item_label.text = "%s  x%d   [R / X]" % [DB.item_name(qi), Game.count(qi)]
	var meal: Dictionary = Game.state.get("meal", {})
	if meal.is_empty():
		meal_label.text = "Not fed: visit a canteen"
	else:
		meal_label.text = "Fed: %s, %s, %s (%d min)" % [DB.item_name(meal.main), DB.item_name(meal.side), DB.item_name(meal.drink), int(float(meal.time_left) / 60.0)]
	refresh_bars()

func refresh_bars() -> void:
	if world == null or world.player == null:
		return
	var p: Player = world.player
	hp_bar.value = p.hp / p.max_hp * 100.0
	st_bar.value = p.stamina / p.max_stamina * 100.0
	st_bar.modulate = Color(1, 0.5, 0.4) if p.exhausted else Color.WHITE
	mp_bar.value = p.mp / p.max_mp * 100.0
	if p.jd.gauge == "ammo":
		gauge_label.text = "Ammo  " + "●".repeat(p.ammo) + "○".repeat(6 - p.ammo)
	else:
		gauge_bar.value = p.gauge

func _process(delta: float) -> void:
	if world and world.player and not loading.visible:
		refresh_bars()
		var p: Player = world.player
		breath_bar.visible = p.swimming and p.breath < p.max_breath - 0.1
		breath_bar.value = p.breath / p.max_breath * 100.0
		if boss_target and is_instance_valid(boss_target):
			boss_bar.value = boss_target.hp / boss_target.max_hp * 100.0
			if not boss_target.alive:
				boss(null)
		elif boss_box.visible:
			boss(null)
		var t: float = Game.state.get("time", 12.0)
		region_label.text = "%s   %02d:%02d" % [world.rd.name, int(t), int(fmod(t, 1.0) * 60.0)]
		minimap.queue_redraw()
		reticle.queue_redraw()
		if Engine.get_process_frames() % 60 == 0:
			refresh()
	if _dlg_open and _typing >= 0.0:
		_typing += delta * 60.0
		dlg_text.visible_characters = int(_typing)
		if _typing >= dlg_text.get_total_character_count():
			_typing = -1.0
			dlg_text.visible_characters = -1
			if _dlg_i == _dlg_lines.size() - 1 and not _dlg_choices_list.is_empty():
				_show_choices()

# ------------------------------------------------------------------ dialogue
## Shows lines ([speaker, text]); returns the chosen index when choices are given (else -1).
func say(lines: Array, choices: Array = []) -> int:
	if lines.is_empty():
		return -1
	_dlg_lines = lines
	_dlg_i = 0
	_dlg_choices_list = choices
	_dlg_open = true
	dlg.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_line()
	var c: int = await dialogue_done
	dlg.visible = false
	_dlg_open = false
	if world and world.player and world.player.controls and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return c

func _show_line() -> void:
	UIKit.clear(dlg_choices)
	var l: Array = _dlg_lines[_dlg_i]
	dlg_name.text = l[0]
	dlg_name.visible = l[0] != ""
	dlg_text.text = l[1]
	dlg_text.visible_characters = 0
	dlg_text.add_theme_color_override("default_color", UIKit.TEXT if l[0] != "" else Color("c8d4e6"))
	_typing = 0.0
	dlg_hint.visible = true

func _show_choices() -> void:
	UIKit.clear(dlg_choices)
	dlg_hint.visible = false
	for i in range(_dlg_choices_list.size()):
		var idx := i
		var b := UIKit.button(_dlg_choices_list[i], func(): dialogue_done.emit(idx), 500)
		dlg_choices.add_child(b)
	await get_tree().process_frame
	UIKit.focus_first(dlg_choices)

func _input(event: InputEvent) -> void:
	if not _dlg_open:
		return
	var adv: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_light") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not adv:
		return
	if dlg_choices.get_child_count() > 0:
		return  # buttons handle it
	get_viewport().set_input_as_handled()
	if _typing >= 0.0:
		_typing = -1.0
		dlg_text.visible_characters = -1
		if _dlg_i == _dlg_lines.size() - 1 and not _dlg_choices_list.is_empty():
			_show_choices()
		return
	if _dlg_i < _dlg_lines.size() - 1:
		_dlg_i += 1
		Audio.ui("ui_page")
		_show_line()
	elif _dlg_choices_list.is_empty():
		dialogue_done.emit(-1)

# ------------------------------------------------------------------ inner widgets
class Minimap extends Control:
	var hud
	var tex: Texture2D
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(3), Color(0, 0, 0, 0.6))
		if tex:
			draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.92))
		draw_rect(r.grow(2), UIKit.GOLD, false, 2.0)
		var w = hud.world
		if w == null or w.player == null:
			return
		var half: float = w.terrain.half
		var to_px := func(p: Vector3) -> Vector2: return Vector2((p.x + half) / (half * 2.0), (p.z + half) / (half * 2.0)) * size
		for e in w.enemies:
			if e.alive and e.global_position.distance_to(w.player.global_position) < 80.0:
				draw_circle(to_px.call(e.global_position), 4.0 if e.is_large else 2.2, Color("e2695c"))
		for n in w.npcs.values():
			if n.marker.text != "":
				draw_string(ThemeDB.fallback_font, to_px.call(n.global_position) + Vector2(-4, 6), n.marker.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, n.marker.modulate)
		for ws in w.waystones.values():
			draw_circle(to_px.call(ws.global_position), 4.0, Color("7fd4ff"))
		for c in w.allies:
			if c is Companion:
				draw_circle(to_px.call(c.global_position), 3.0, Color("7fd48a"))
		if hud.objective_pos != null:
			var op: Vector2 = to_px.call(hud.objective_pos)
			op = op.clamp(Vector2(6, 6), size - Vector2(6, 6))
			draw_circle(op, 7.0, Color("ffd34a"))
			draw_circle(op, 4.0, Color("8a5a00"))
		var pp: Vector2 = to_px.call(w.player.global_position)
		var f: Vector3 = w.player.face_dir
		var a := atan2(f.z, f.x)
		var pts := PackedVector2Array([pp + Vector2(cos(a), sin(a)) * 9.0, pp + Vector2(cos(a + 2.5), sin(a + 2.5)) * 6.0, pp + Vector2(cos(a - 2.5), sin(a - 2.5)) * 6.0])
		draw_colored_polygon(pts, Color.WHITE)

class Reticle extends Control:
	var hud
	func _draw() -> void:
		var w = hud.world
		if w == null or w.player == null:
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var t = w.player.lock_target
		if t and is_instance_valid(t) and not cam.is_position_behind(t.center()):
			var sp := cam.unproject_position(t.center())
			draw_arc(sp, 18.0, 0, TAU, 24, Color("ffd34a"), 2.5)
			draw_circle(sp, 3.0, Color("ffd34a"))
		if hud.objective_pos != null and not cam.is_position_behind(hud.objective_pos + Vector3.UP * 3.0):
			var op := cam.unproject_position(hud.objective_pos + Vector3.UP * 3.0)
			var d: float = (hud.objective_pos as Vector3).distance_to(w.player.global_position)
			if d > 15.0:
				draw_string(ThemeDB.fallback_font, op + Vector2(-20, 0), "◆ %dm" % int(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd34a"))

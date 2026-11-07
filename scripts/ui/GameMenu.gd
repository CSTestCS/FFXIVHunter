class_name GameMenu
extends Control
## Pause menu: status, equipment, items, jobs, quests, party, map, settings, save/quit.
## Switch tabs with the tab buttons, PageUp/PageDown, [ ], or LB/RB.

signal closed

const TABS := ["Status", "Equipment", "Items", "Jobs", "Quests", "Party", "Map", "Settings", "System"]

var world: Node
var start_tab := ""
var tab := 0
var tabs_row: HBoxContainer
var body: VBoxContainer
var scroll: ScrollContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := UIKit.panel(24)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 120
	p.offset_right = -120
	p.offset_top = 70
	p.offset_bottom = -70
	add_child(p)
	var v := UIKit.vbox(12)
	p.add_child(v)
	tabs_row = UIKit.hbox(6)
	v.add_child(tabs_row)
	for i in range(TABS.size()):
		var idx := i
		tabs_row.add_child(UIKit.button(TABS[i], func(): _show(idx), 150))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = UIKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	v.add_child(UIKit.label("◀ LB / PgUp      RB / PgDn ▶      B / Esc: close", 16, UIKit.DIM))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show(maxi(0, TABS.find(start_tab)))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action_pressed("ui_tab_next"):
		get_viewport().set_input_as_handled()
		_show((tab + 1) % TABS.size())
	elif event.is_action_pressed("ui_tab_prev"):
		get_viewport().set_input_as_handled()
		_show((tab - 1 + TABS.size()) % TABS.size())

func _close() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()

func _show(i: int) -> void:
	tab = i
	for k in range(tabs_row.get_child_count()):
		(tabs_row.get_child(k) as Button).modulate = UIKit.GOLD if k == i else Color.WHITE
	UIKit.clear(body)
	match TABS[i]:
		"Status": _status()
		"Equipment": _equipment()
		"Items": _items()
		"Jobs": _jobs()
		"Quests": _quests()
		"Party": _party()
		"Map": _map()
		"Settings": body.add_child(SettingsMenu.new())
		"System": _system()
	await get_tree().process_frame
	if TABS[i] in ["Settings", "Status", "Map"]:
		tabs_row.get_child(i).grab_focus()
	else:
		UIKit.focus_first(body)
		if get_viewport().gui_get_focus_owner() == null:
			tabs_row.get_child(i).grab_focus()

func _t(text: String, size := 20, col := UIKit.TEXT) -> Label:
	var l := UIKit.label(text, size, col, true)
	l.custom_minimum_size = Vector2(1500, 0)
	body.add_child(l)
	return l

func _status() -> void:
	var s: Dictionary = Game.state
	var p: Dictionary = s.player
	var r: Dictionary = DB.races[p.race]
	_t(Game.player_name(), 34, UIKit.GOLD)
	_t("%s %s · %s · Nameday: %d/%d · Guardian: %s" % [r.clans[p.clan].name, r.name, p.body.capitalize(), int(p.nameday_day), int(p.nameday_month), DB.RacesData.DEITIES[int(p.deity)].name])
	var lvl := Game.job_level()
	var j: Dictionary = s.jobs[s.job]
	_t("%s   Level %d   EXP %d / %d" % [DB.jobs[s.job].name, lvl, int(j.xp), Game.xp_to_next(lvl)], 24)
	var st := Game.compute_stats()
	_t("HP %d   Attack %d   Defense %d   Critical %d%%   Stamina %d   Speed +%d%%" % [int(st.max_hp), int(st.atk), int(st.def), int(st.crit * 100), int(st.stamina), int(st.speed * 100)])
	_t("Gil: %d      Writs completed: %d      Play time: %d:%02d" % [int(s.gil), int(s.writs_done), int(s.playtime) / 3600, (int(s.playtime) / 60) % 60])
	var meal: Dictionary = s.get("meal", {})
	if meal.is_empty():
		_t("Meal: none. Eat at a canteen before a hunt!", 20, UIKit.DIM)
	else:
		_t("Meal: %s · %s · %s  (%d min left)" % [DB.item_name(meal.main), DB.item_name(meal.side), DB.item_name(meal.drink), int(float(meal.time_left) / 60.0)], 20, UIKit.GOOD)
	_t("The legendary Lightbearer: %s" % Game.hero_name(), 20, UIKit.DIM)

func _equipment() -> void:
	var s: Dictionary = Game.state
	var w: Dictionary = s.weapons[s.job]
	_t("Weapon", 26, UIKit.GOLD)
	_t("%s  (tier %d, ATK %d)" % [DB.weapon_name(s.job, int(w.tier)), int(w.tier), int(DB.weapon_attack(s.job, int(w.tier)))])
	_t("Materia: " + ", ".join((w.materia as Array).map(func(m): return DB.materia[m].name if m != "" else "(empty)")), 18, UIKit.DIM)
	_t("Armor", 26, UIKit.GOLD)
	var a: Dictionary = s.armor_owned.get(s.armor, {"tier": 0, "materia": []})
	_t("%s +%d  (DEF %d)" % [DB.armor[s.armor].name, int(a.tier), int(DB.armor[s.armor].def)])
	_t("Materia: " + ", ".join((a.materia as Array).map(func(m): return DB.materia[m].name if m != "" else "(empty)")), 18, UIKit.DIM)
	_t("Change armor", 22, UIKit.GOLD)
	var h := HFlowContainer.new()
	body.add_child(h)
	for id in s.armor_owned:
		var aid: String = id
		h.add_child(UIKit.button(("✔ " if s.armor == id else "") + DB.armor[id].name, func():
			Game.state.armor = aid
			world.player.refresh_from_state()
			_show(tab), 300))
	_t("Upgrade weapons and armor at a smithy; meld materia at a materia workshop.", 17, UIKit.DIM)

func _items() -> void:
	var inv: Dictionary = Game.state.inventory
	if inv.is_empty():
		_t("Your pack is empty.")
		return
	for type in ["consumable", "material", "key"]:
		var any := false
		for id in inv:
			var it: Dictionary = DB.items.get(id, {})
			if it.get("type", "") != type:
				continue
			if not any:
				_t(type.capitalize() + "s", 24, UIKit.GOLD)
				any = true
			if type == "consumable":
				var iid: String = id
				var row := UIKit.hbox(10)
				row.add_child(UIKit.label("%s x%d — %s" % [it.name, int(inv[id]), it.desc], 19))
				row.add_child(UIKit.button("Set quick item" if Game.state.quick_item != id else "✔ Quick item", func():
					Game.state.quick_item = iid
					_show(tab), 220))
				body.add_child(row)
			else:
				_t("%s x%d — %s" % [it.name, int(inv[id]), it.desc], 18, UIKit.TEXT if type == "material" else UIKit.GOLD)
	var mats := []
	for id in inv:
		if DB.materia.has(id):
			mats.append("%s x%d" % [DB.materia[id].name, int(inv[id])])
	if not mats.is_empty():
		_t("Materia", 24, UIKit.GOLD)
		_t(", ".join(mats), 18)

func _jobs() -> void:
	var fighting := false
	for e in world.enemies:
		if e.alive and e.target != null:
			fighting = true
	_t("Jobs are learned from each job's guild in the three cities. You can switch out of combat." if not fighting else "You can't change jobs mid-fight!", 18, UIKit.DIM)
	for j in DB.jobs:
		var jd: Dictionary = DB.jobs[j]
		var u: bool = Game.state.jobs[j].unlocked
		var jj: String = j
		var row := UIKit.hbox(10)
		var btn := UIKit.button(("✔ " if Game.state.job == j else "") + "%s  Lv.%d" % [jd.name, Game.job_level(j)], func():
			Game.change_job(jj)
			world.player.refresh_from_state()
			_show(tab), 300)
		btn.disabled = not u or fighting
		row.add_child(btn)
		row.add_child(UIKit.label(("%s · %s · learn in %s" % [jd.weapon.replace("_", " & ").capitalize(), jd.role, DB.regions[jd.city].name]) if not u else "%s · %s" % [jd.weapon.replace("_", " & ").capitalize(), jd.role], 17, UIKit.DIM))
		body.add_child(row)

func _quests() -> void:
	_t("Active", 26, UIKit.GOLD)
	for id in Game.active_quests():
		var q: Dictionary = DB.quests[id]
		_t("%s %s  [%s]" % ["◆" if q.type == "main" else "◇", q.name, "Main story" if q.type == "main" else "Side quest"], 22)
		_t("    " + Game.fmt(q.summary), 18, UIKit.DIM)
		_t("    → " + ("Report to %s" % DB.npcs[Game.quest_turn_in(id)].name if Game.quest_ready(id) else Game.quest_progress_text(id)), 18, UIKit.GOOD)
	var w: Dictionary = Game.state.get("writ", {})
	if not w.is_empty():
		_t("▣ Writ: %s — %s" % [w.title, Game.writ_text(w)], 20)
	_t("Completed", 26, UIKit.GOLD)
	var done := []
	for id in Game.state.quests:
		if Game.state.quests[id].state == "done":
			done.append(DB.quests[id].name)
	_t(", ".join(done) if not done.is_empty() else "None yet.", 18, UIKit.DIM)

func _party() -> void:
	var party: Array = Game.state.get("party", [])
	if party.is_empty():
		_t("You travel alone." + (" Hire companions at a city's Party Registry." if Game.has_flag("party_unlocked") else " Companions become available as the story progresses."), 20)
	for cid in party:
		var c: Dictionary = DB.companions[cid]
		_t("%s — %s" % [c.name, DB.jobs[c.job].name], 22, UIKit.GOLD)
		_t("    " + c.bio, 18, UIKit.DIM)

func _map() -> void:
	var h := UIKit.hbox(20)
	body.add_child(h)
	var tr := TextureRect.new()
	tr.texture = world.map_tex
	tr.custom_minimum_size = Vector2(520, 520)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.add_child(tr)
	var mk := MapMarks.new()
	mk.world = world
	mk.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.add_child(mk)
	var v := UIKit.vbox(6)
	h.add_child(v)
	v.add_child(UIKit.label(world.rd.name, 30, UIKit.GOLD))
	v.add_child(UIKit.label("Roads lead to:", 20))
	for e in world.rd.exits:
		v.add_child(UIKit.label("  %s → %s" % [e.side.capitalize(), DB.regions[e.to].name], 18, UIKit.DIM))
	v.add_child(UIKit.label("The realm", 24, UIKit.GOLD))
	for r in DB.regions:
		var rr: Dictionary = DB.regions[r]
		var links := []
		for e in rr.exits:
			links.append(DB.regions[e.to].name)
		var attuned := false
		for ws in rr.get("waystones", []):
			attuned = attuned or Game.state.waystones.has(ws.id)
		v.add_child(UIKit.label("%s%s  ↔  %s" % ["◆ " if attuned else "◇ ", rr.name, ", ".join(links)], 16, UIKit.TEXT if attuned else UIKit.DIM))

func _system() -> void:
	_t("Save slot %d" % (Game.current_slot + 1), 24, UIKit.GOLD)
	var row := UIKit.hbox(10)
	body.add_child(row)
	var status := UIKit.label("", 18, UIKit.GOOD)
	row.add_child(UIKit.button("Save game", func():
		var fighting := false
		for e in world.enemies:
			if e.alive and e.target != null:
				fighting = true
		if fighting:
			status.text = "Can't save during a fight."
		else:
			world.save_game()
			status.text = "Saved.", 240))
	row.add_child(UIKit.button("Quit to title", func():
		get_tree().paused = false
		Game.goto_main_menu(), 240))
	row.add_child(UIKit.button("Quit game", func(): get_tree().quit(), 240))
	body.add_child(status)
	_t("Unsaved progress since your last rest or save will be lost when quitting.", 17, UIKit.DIM)

class MapMarks extends Control:
	var world
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if world == null:
			return
		var half: float = world.terrain.half
		var f := func(p: Vector3) -> Vector2: return Vector2((p.x + half) / (2.0 * half), (p.z + half) / (2.0 * half)) * size
		for ws in world.waystones.values():
			draw_circle(f.call(ws.global_position), 7.0, Color("7fd4ff"))
		for n in world.npcs.values():
			if n.marker.text != "":
				draw_string(ThemeDB.fallback_font, f.call(n.global_position), n.marker.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, n.marker.modulate)
		if world.hud.objective_pos != null:
			draw_circle(f.call(world.hud.objective_pos), 9.0, Color("ffd34a"))
		draw_circle(f.call(world.player.global_position), 7.0, Color.WHITE)
		draw_arc(f.call(world.player.global_position), 10.0, 0, TAU, 16, Color.BLACK, 2.0)

class_name ServiceMenu
extends Control
## NPC services and waystone menu. One window, content rebuilt per action (simple and robust).

signal closed

var world: Node
var kind := ""
var npc_id := ""
var panel: PanelContainer
var title: Label
var body: VBoxContainer
var info: Label
var tab := 0
var _sel := {"main": "", "side": "", "drink": ""}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UIKit.panel(22)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(980, 640)
	panel.position = Vector2(-490, -320)
	add_child(panel)
	var v := UIKit.vbox(10)
	panel.add_child(v)
	title = UIKit.label("", 34, UIKit.GOLD)
	v.add_child(title)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(940, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	body = UIKit.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	info = UIKit.label("", 19, UIKit.DIM, true)
	info.custom_minimum_size = Vector2(940, 0)
	v.add_child(info)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()

func _rebuild() -> void:
	UIKit.clear(body)
	info.text = "Gil: %d" % int(Game.state.gil)
	match kind:
		"inn": _inn()
		"canteen": _canteen()
		"smith": _smith()
		"materia": _materia()
		"outfitter": _outfitter()
		"merchant": _merchant()
		"recruiter": _recruiter()
		"job_master": _job_master()
		"guild": _guild()
		"writ_board": _writs()
		"waystone": _waystone()
	_row([["Leave", _close]])
	await get_tree().process_frame
	UIKit.focus_first(body)

func _row(buttons: Array) -> HBoxContainer:
	var h := UIKit.hbox(8)
	for b in buttons:
		var btn := UIKit.button(b[0], b[1], 220)
		if b.size() > 2 and b[2] == false:
			btn.disabled = true
		h.add_child(btn)
	body.add_child(h)
	return h

func _text(t: String, size := 20, col := UIKit.TEXT) -> void:
	body.add_child(UIKit.label(t, size, col, true))

func _npc_name() -> String:
	return DB.npcs[npc_id].name if DB.npcs.has(npc_id) else ""

# ------------------------------------------------------------------ services
func _inn() -> void:
	title.text = "Inn  —  " + _npc_name()
	_text("A warm bed restores you fully, passes the night, and saves your progress.")
	_row([["Rest (saves the game)", func():
		_close()
		await world.rest(true)]])

func _canteen() -> void:
	title.text = "Canteen  —  " + _npc_name()
	_text("Choose a main dish, a side and a drink. Each slot targets a different part of the hunt:\nMain = attack & health   Side = defense & stamina   Drink = utility (speed, swimming, rewards)", 18, UIKit.DIM)
	var total := 0
	for slot in ["main", "side", "drink"]:
		_text(slot.capitalize(), 24, UIKit.GOLD)
		var h := HFlowContainer.new()
		body.add_child(h)
		for id in DB.meals[slot]:
			var m: Dictionary = DB.meals[slot][id]
			var locked := Game.job_level() < int(m.get("level", 0))
			var sel: bool = _sel[slot] == id
			var b := UIKit.button(("✔ " if sel else "") + "%s  (%d gil)" % [m.name, int(m.price)], func():
				_sel[slot] = id
				_rebuild(), 300)
			b.tooltip_text = m.desc
			b.disabled = locked
			b.focus_entered.connect(func(): info.text = "%s: %s" % [m.name, m.desc])
			h.add_child(b)
		if _sel[slot] != "":
			total += int(DB.meals[slot][_sel[slot]].price)
	var ready_: bool = _sel.main != "" and _sel.side != "" and _sel.drink != ""
	_row([["Eat (%d gil)" % total, func():
		if Game.spend_gil(total):
			Game.eat_meal(_sel.main, _sel.side, _sel.drink)
			world.player.refresh_from_state()
			world.player.hp = world.player.max_hp
			_close(), ready_]])

func _smith() -> void:
	title.text = "Smithy  —  " + _npc_name()
	_text("Upgrade your weapons (one per job) and armor. Each tier needs gil and monster materials.", 18, UIKit.DIM)
	for j in DB.jobs:
		if not Game.state.jobs[j].unlocked:
			continue
		var tier := int(Game.state.weapons[j].tier)
		var nm := DB.weapon_name(j, tier)
		if tier >= DB.tiers.size() - 1:
			_text("%s  —  %s  (max tier)" % [DB.jobs[j].name, nm])
			continue
		var nxt: Dictionary = DB.tiers[tier + 1]
		var can := int(Game.state.gil) >= int(nxt.gil)
		var mats := []
		for m in nxt.mats:
			mats.append("%s %d/%d" % [DB.item_name(m), Game.count(m), int(nxt.mats[m])])
			if Game.count(m) < int(nxt.mats[m]):
				can = false
		var jj: String = j
		_row([["Upgrade %s" % DB.jobs[j].name, func():
			if Game.spend_gil(int(nxt.gil)):
				for m in nxt.mats:
					Game.remove_item(m, int(nxt.mats[m]))
				Game.state.weapons[jj].tier = tier + 1
				Game.notify.emit("Forged: " + DB.weapon_name(jj, tier + 1))
				_rebuild(), can]])
		_text("    %s → %s   ATK %d → %d   |  %d gil, %s" % [nm, DB.weapon_name(j, tier + 1), int(DB.weapon_attack(j, tier)), int(DB.weapon_attack(j, tier + 1)), int(nxt.gil), ", ".join(mats)], 17, UIKit.DIM)
	_text("Armor", 24, UIKit.GOLD)
	for a in Game.state.armor_owned:
		if a == "none":
			continue
		var t := int(Game.state.armor_owned[a].tier)
		if t >= 3:
			_text("%s  (+%d, max)" % [DB.armor[a].name, t])
			continue
		var cost := (t + 1) * 500 + int(DB.armor[a].def) * 40
		var need := {"beast_hide": 2 + t, "iron_ore": 2 + t} if t < 2 else {"steel_ingot": 3, "drake_scale": 1}
		var ok := int(Game.state.gil) >= cost
		var desc := []
		for m in need:
			desc.append("%s %d/%d" % [DB.item_name(m), Game.count(m), need[m]])
			if Game.count(m) < need[m]:
				ok = false
		var aa: String = a
		_row([["Reinforce %s +%d" % [DB.armor[a].name, t + 1], func():
			if Game.spend_gil(cost):
				for m in need:
					Game.remove_item(m, need[m])
				Game.state.armor_owned[aa].tier = t + 1
				_rebuild(), ok]])
		_text("    %d gil, %s  (+25%% defense per level)" % [cost, ", ".join(desc)], 17, UIKit.DIM)

func _materia() -> void:
	title.text = "Materia Workshop  —  " + _npc_name()
	_text("Buy materia, then meld it into a slot. Weapons (per job) have 2 slots, armor sets have 3. Melding over a slot destroys the old materia.", 18, UIKit.DIM)
	var h := HFlowContainer.new()
	body.add_child(h)
	for id in DB.materia:
		var m: Dictionary = DB.materia[id]
		var b := UIKit.button("Buy %s (%d)" % [m.name, int(m.price)], func():
			if Game.spend_gil(int(m.price)):
				Game.add_item(id, 1)
				_rebuild(), 300)
		h.add_child(b)
	var owned := []
	for id in Game.state.inventory:
		if DB.materia.has(id):
			owned.append(id)
	_text("Your materia: " + (", ".join(owned.map(func(x): return "%s x%d" % [DB.materia[x].name, Game.count(x)])) if not owned.is_empty() else "none"), 19)
	var job: String = Game.state.job
	var slots := []
	for i in range(2):
		slots.append(["weapon", i, Game.state.weapons[job].materia[i]])
	var arm: String = Game.state.armor
	if arm != "none":
		for i in range(3):
			slots.append(["armor", i, Game.state.armor_owned[arm].materia[i]])
	for s in slots:
		var cur: String = s[2]
		var label := "%s slot %d: %s" % ["Weapon (%s)" % DB.jobs[job].name if s[0] == "weapon" else DB.armor[arm].name, int(s[1]) + 1, DB.materia[cur].name if cur != "" else "(empty)"]
		_text(label, 19, UIKit.TEXT)
		var row := HFlowContainer.new()
		body.add_child(row)
		for id in owned:
			var target: Array = s
			var b := UIKit.button("Meld %s" % DB.materia[id].name, func():
				Game.remove_item(id, 1)
				if target[0] == "weapon":
					Game.state.weapons[job].materia[target[1]] = id
				else:
					Game.state.armor_owned[arm].materia[target[1]] = id
				Game.notify.emit("Melded " + DB.materia[id].name)
				_rebuild(), 260)
			row.add_child(b)

func _outfitter() -> void:
	title.text = "Armorer & Outfitter  —  " + _npc_name()
	_text("Buy armor sets and choose what you wear. (Custom clothing models replace these visuals by armor id; see docs/CUSTOM_MODELS.md.)", 18, UIKit.DIM)
	for a in DB.armor:
		var d: Dictionary = DB.armor[a]
		if d.get("hidden", false) and a != "none":
			continue
		var owned: bool = Game.state.armor_owned.has(a)
		var lvl := int(d.get("level", 0))
		var aa: String = a
		if owned:
			var worn: bool = Game.state.armor == a
			_row([[("✔ Wearing " if worn else "Wear ") + d.name + "  (DEF %d)" % int(d.def), func():
				Game.state.armor = aa
				world.player.refresh_from_state()
				_rebuild(), not worn]])
		elif int(d.price) > 0:
			_row([["Buy %s  (DEF %d, %d gil%s)" % [d.name, int(d.def), int(d.price), ", Lv.%d" % lvl if lvl > 1 else ""], func():
				if Game.spend_gil(int(d.price)):
					Game.state.armor_owned[aa] = {"tier": 0, "materia": ["", "", ""]}
					Game.state.armor = aa
					world.player.refresh_from_state()
					_rebuild(), Game.job_level() >= lvl]])

func _merchant() -> void:
	title.text = "Provisioner  —  " + _npc_name()
	for id in ["potion", "hi_potion", "ether", "stamina_tonic", "phoenix_down"]:
		var it: Dictionary = DB.items[id]
		_row([["Buy %s (%d gil)  — own %d" % [it.name, int(it.price), Game.count(id)], func():
			if Game.spend_gil(int(it.price)):
				Game.add_item(id, 1, true)
				_rebuild()]])
	_text("Sell materials (half price)", 24, UIKit.GOLD)
	for id in Game.state.inventory.keys():
		if DB.items.has(id) and DB.items[id].type == "material":
			var price := int(DB.items[id].price) / 2
			_row([["Sell %s x1 (%d gil) — own %d" % [DB.item_name(id), price, Game.count(id)], func():
				if Game.remove_item(id, 1):
					Game.add_gil(price)
					_rebuild()]])

func _recruiter() -> void:
	title.text = "Party Registry  —  " + _npc_name()
	if not Game.has_flag("party_unlocked"):
		_text("\"Prove yourself on a real hunt first. The guildmaster will let me know when you're ready.\"")
		return
	_text("Hire companions once, then choose up to 3 to travel with you. They level with you.", 18, UIKit.DIM)
	var party: Array = Game.state.party
	for cid in DB.companions:
		var c: Dictionary = DB.companions[cid]
		var hired: bool = Game.state.hired.has(cid)
		var cc: String = cid
		if not hired:
			_row([["Hire %s — %s (%d gil)" % [c.name, DB.jobs[c.job].name, int(c.price)], func():
				if Game.spend_gil(int(c.price)):
					Game.state.hired.append(cc)
					_rebuild()]])
		elif party.has(cid):
			_row([["Dismiss %s from party" % c.name, func():
				party.erase(cc)
				_rebuild()]])
		else:
			_row([["Add %s (%s) to party" % [c.name, DB.jobs[c.job].name], func():
				party.append(cc)
				_rebuild(), party.size() < 3]])
		_text("    " + c.bio, 16, UIKit.DIM)
	_text("Party changes take effect when you next enter a region (or rest at a waystone).", 16, UIKit.DIM)

func _job_master() -> void:
	var d: Dictionary = DB.npcs[npc_id]
	var j: String = d.job
	var jd: Dictionary = DB.jobs[j]
	title.text = "%s  —  %s" % [jd.name, d.name]
	_text(jd.desc)
	_text("Weapon: %s   Role: %s   Difficulty: %s" % [jd.weapon.replace("_", " & ").capitalize(), jd.role, "★".repeat(int(jd.difficulty))], 18, UIKit.DIM)
	if not Game.state.jobs[j].unlocked:
		_row([["Take up the %s job" % jd.name, func():
			Game.unlock_job(j)
			_rebuild()]])
	elif Game.state.job != j:
		_row([["Become a %s (Lv.%d)" % [jd.name, Game.job_level(j)], func():
			Game.change_job(j)
			world.player.refresh_from_state()
			_rebuild()]])
	else:
		_text("You are already walking this path.", 19, UIKit.GOOD)

func _guild() -> void:
	title.text = "Adventurers' Guild  —  " + _npc_name()
	_text("Change job (any job you have taken up). New jobs are learned from each job's guild in the three cities.", 18, UIKit.DIM)
	_job_list()
	_row([["Open the writ board", func():
		kind = "writ_board"
		_rebuild(), Game.has_flag("writs_unlocked")]])

func _job_list() -> void:
	var h := HFlowContainer.new()
	body.add_child(h)
	for j in DB.jobs:
		if Game.state.jobs[j].unlocked:
			var jj: String = j
			var b := UIKit.button(("✔ " if Game.state.job == j else "") + "%s Lv.%d" % [DB.jobs[j].name, Game.job_level(j)], func():
				Game.change_job(jj)
				world.player.refresh_from_state()
				_rebuild(), 240)
			h.add_child(b)

func _writs() -> void:
	title.text = "Guild Writs"
	if not Game.has_flag("writs_unlocked"):
		_text("\"No writs for you until you've recovered,\" says a stern note pinned to the board.")
		return
	var city: String = world.region_id if world.is_city else Game.state.home
	var w: Dictionary = Game.state.get("writ", {})
	if not w.is_empty():
		_text("Current writ: %s\n%s\nReward: %d gil, %d EXP" % [w.title, Game.writ_text(w), int(w.gil), int(w.xp)], 20, UIKit.GOLD)
		_row([["Abandon writ", func():
			Game.state.writ = {}
			Game.quest_changed.emit()
			_rebuild()]])
		return
	_text("Writs are repeatable work: no story, just coin and experience. One at a time.", 18, UIKit.DIM)
	var board := Game.writ_board(city)
	for i in range(board.size()):
		var wr: Dictionary = board[i]
		var idx := i
		var tag: String = {"hunt_small": "HUNT", "hunt_large": "LARGE HUNT", "gather": "GATHER", "defense": "DEFENSE", "escort": "ESCORT"}[wr.kind]
		_row([["[%s] %s" % [tag, wr.title], func():
			Game.accept_writ(city, idx)
			_rebuild()]])
		_text("    %s   —   %d gil, %d EXP" % [Game.writ_text(wr), int(wr.gil), int(wr.xp)], 17, UIKit.DIM)

func _waystone() -> void:
	title.text = "Waystone"
	_text("The crystal hums. Rest here to recover, refill the wilds and save. Travel to any waystone you've attuned.", 18, UIKit.DIM)
	_row([["Rest & save", func():
		_close()
		await world.rest(false)], ["Save only", func():
		world.save_game()
		info.text = "Game saved to slot %d." % (Game.current_slot + 1)]])
	_text("Travel", 24, UIKit.GOLD)
	var h := HFlowContainer.new()
	body.add_child(h)
	for r in DB.regions:
		for ws in DB.regions[r].get("waystones", []):
			if Game.state.waystones.has(ws.id) and ws.id != npc_id:
				var wid: String = ws.id
				h.add_child(UIKit.button(DB.regions[r].name, func():
					_close()
					world.fast_travel(wid), 260))
	_text("Change job", 24, UIKit.GOLD)
	_job_list()

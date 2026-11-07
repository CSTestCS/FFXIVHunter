extends Node
## Global game state + rules: progression, inventory, quests, writs, meals, screen flow.
## The whole save file is `state` (a JSON-safe Dictionary).

signal notify(text: String)
signal state_changed
signal quest_changed
signal level_up(job: String, level: int)
signal mission_event(kind: String, data: Dictionary)

const MAX_LEVEL := 50
const MEAL_DURATION := 1800.0
const RacesData := preload("res://scripts/data/races.gd")

var state: Dictionary = {}
var current_slot := -1
var screen: Node = null
var world: Node = null          # the active World (set by World itself)
var pending_cutscene := ""
var _playtime_accum := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if state.is_empty() or get_tree().paused:
		return
	state.playtime = float(state.get("playtime", 0.0)) + delta
	var meal: Dictionary = state.get("meal", {})
	if meal.has("time_left"):
		meal.time_left = float(meal.time_left) - delta
		if float(meal.time_left) <= 0.0:
			state.meal = {}
			notify.emit("Your meal's effects have worn off.")
			state_changed.emit()
	for k in state.get("temp_buffs", {}).keys():
		state.temp_buffs[k] = float(state.temp_buffs[k]) - delta
		if float(state.temp_buffs[k]) <= 0:
			state.temp_buffs.erase(k)

# ------------------------------------------------------------------ screens
func change_screen(node: Node) -> void:
	get_tree().paused = false
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = node
	get_tree().root.add_child.call_deferred(node)

func goto_main_menu() -> void:
	state = {}
	current_slot = -1
	change_screen(load("res://scripts/ui/MainMenu.gd").new())

func goto_creator(slot: int) -> void:
	current_slot = slot
	change_screen(load("res://scripts/ui/CharacterCreator.gd").new())

func goto_world(cutscene := "") -> void:
	pending_cutscene = cutscene
	change_screen(load("res://scripts/world/World.gd").new())

# ------------------------------------------------------------------ new game
func new_game(slot: int, player_look: Dictionary, hero_look: Dictionary, job: String, hero_job := "paladin") -> void:
	current_slot = slot
	var city: String = DB.jobs[job].city
	var start: Dictionary = DB.RegionsData.START_POINTS[city]
	var jobs := {}
	for j in DB.jobs:
		jobs[j] = {"level": 1, "xp": 0, "unlocked": j == job}
	var weapons := {}
	for j in DB.jobs:
		weapons[j] = {"tier": 0, "materia": ["", ""]}
	state = {
		"version": 1, "player": player_look, "hero": hero_look, "hero_job": hero_job, "job": job, "jobs": jobs, "weapons": weapons,
		"home": city, "gil": 0, "inventory": {}, "armor": "none", "armor_owned": {"none": {"tier": 0, "materia": ["", "", ""]}},
		"meal": {}, "temp_buffs": {}, "region": start.region, "pos": [start.pos.x, start.pos.y, start.pos.z],
		"waystones": [], "last_waystone": "", "flags": {}, "quests": {}, "writ": {}, "writ_board": {}, "writs_done": 0,
		"party": [], "hired": [], "dropped_gil": {}, "playtime": 0.0, "time": 7.5, "hp_ratio": 0.35,
		"quick_item": "potion", "created": Time.get_datetime_string_from_system(),
	}
	start_quest("msq_awakening", true)
	goto_world("opening")

# ------------------------------------------------------------------ text helpers
func player_name() -> String:
	var p: Dictionary = state.get("player", {})
	return ("%s %s" % [p.get("first_name", "Adventurer"), p.get("last_name", "")]).strip_edges()

func hero_name() -> String:
	var h: Dictionary = state.get("hero", {})
	var n := ("%s %s" % [h.get("first_name", ""), h.get("last_name", "")]).strip_edges()
	return n if n != "" else "the Lightbearer"

func next_city() -> String:
	var i := DB.CITY_ORDER.find(state.get("home", "saltcrest"))
	return DB.CITY_ORDER[(i + 1) % DB.CITY_ORDER.size()]

func resolve(token: String) -> String:
	match token:
		"@home": return state.home
		"@home_field": return DB.RegionsData.START_POINTS[state.home].region
		"@next_city": return next_city()
		"@next_field": return DB.RegionsData.START_POINTS[next_city()].region
		"@guild": return DB.guild_npc(state.home)
		"@next_guild": return DB.guild_npc(next_city())
		"@rescuer": return DB.RESCUERS[state.home]
	return token

func fmt(text: String) -> String:
	var gm: String = DB.npcs[DB.guild_npc(state.get("home", "saltcrest"))].name
	return text.format({
		"first": state.get("player", {}).get("first_name", "Adventurer"), "name": player_name(), "hero": hero_name(),
		"rescuer": DB.npcs[DB.RESCUERS[state.get("home", "saltcrest")]].name, "home": DB.regions[state.get("home", "saltcrest")].name,
		"home_field": DB.regions[resolve("@home_field")].name, "guildmaster": gm, "next_city": DB.regions[next_city()].name,
	})

# ------------------------------------------------------------------ inventory & gil
func add_gil(n: int, apply_bonus := false) -> void:
	if apply_bonus:
		n = int(n * (1.0 + buff("gil_pct")))
	state.gil = int(state.gil) + n
	if n > 0:
		notify.emit("+%d gil" % n)
	state_changed.emit()

func spend_gil(n: int) -> bool:
	if int(state.gil) < n:
		notify.emit("Not enough gil.")
		return false
	state.gil = int(state.gil) - n
	state_changed.emit()
	return true

func count(id: String) -> int:
	return int(state.inventory.get(id, 0))

func add_item(id: String, n := 1, silent := false) -> void:
	if n <= 0:
		return
	state.inventory[id] = count(id) + n
	if not silent:
		notify.emit("Obtained %s x%d" % [DB.item_name(id), n])
	_progress_gather(id, n)
	state_changed.emit()

func remove_item(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	state.inventory[id] = count(id) - n
	if int(state.inventory[id]) <= 0:
		state.inventory.erase(id)
	state_changed.emit()
	return true

# ------------------------------------------------------------------ progression
func job_level(job := "") -> int:
	if job == "":
		job = state.job
	return int(state.jobs[job].level)

func xp_to_next(level: int) -> int:
	return int(120 * pow(level, 1.55))

func add_xp(n: int) -> void:
	n = int(n * (1.0 + buff("xp_pct")))
	var j: Dictionary = state.jobs[state.job]
	if int(j.level) >= MAX_LEVEL:
		return
	j.xp = int(j.xp) + n
	notify.emit("+%d EXP" % n)
	while int(j.level) < MAX_LEVEL and int(j.xp) >= xp_to_next(int(j.level)):
		j.xp = int(j.xp) - xp_to_next(int(j.level))
		j.level = int(j.level) + 1
		level_up.emit(state.job, int(j.level))
		notify.emit("%s reached level %d!" % [DB.jobs[state.job].name, int(j.level)])
	state_changed.emit()

func buff(key: String) -> float:
	var total := 0.0
	var meal: Dictionary = state.get("meal", {})
	for slot in ["main", "side", "drink"]:
		var id: String = meal.get(slot, "")
		if id != "" and DB.meals[slot].has(id):
			total += float(DB.meals[slot][id].buff.get(key, 0.0))
	if state.get("temp_buffs", {}).has(key):
		total += 1.0
	return total

## Final combat stats for the player (or a companion when `who` is given).
func compute_stats(job := "", level := -1, armor_id := "", for_player := true) -> Dictionary:
	if job == "":
		job = state.job
	if level < 0:
		level = job_level(job)
	if armor_id == "":
		armor_id = state.get("armor", "none")
	var jd: Dictionary = DB.jobs[job]
	var tier := int(state.weapons[job].tier) if for_player else clampi(level / 6, 0, 5)
	var arm: Dictionary = DB.armor.get(armor_id, DB.armor.none)
	var arm_tier := int(state.armor_owned.get(armor_id, {}).get("tier", 0)) if for_player else 0
	var s := {
		"max_hp": (420.0 + level * 46.0) * float(jd.hp),
		"atk": DB.weapon_attack(job, tier) + level * 2.2,
		"def": (float(arm.def) * (1.0 + arm_tier * 0.25) + level * 1.2) * float(jd.def),
		"crit": 0.05, "stamina": 100.0, "speed": 0.0, "max_mp": 100.0 + level * 3.0,
	}
	if for_player:
		var mats: Array = []
		mats.append_array(state.weapons[job].materia)
		mats.append_array(state.armor_owned.get(armor_id, {}).get("materia", []))
		for m in mats:
			if m != "" and DB.materia.has(m):
				var md: Dictionary = DB.materia[m]
				var key: String = {"hp": "max_hp", "atk": "atk", "def": "def", "crit": "crit", "stamina": "stamina", "speed": "speed"}[md.stat]
				s[key] = float(s[key]) + float(md.value)
		s.max_hp += buff("hp")
		s.atk *= 1.0 + buff("atk_pct")
		s.def *= 1.0 + buff("def_pct")
		s.crit += buff("crit")
		s.stamina += buff("stamina")
		s.speed += buff("speed")
	return s

func eat_meal(main: String, side: String, drink: String) -> void:
	state.meal = {"main": main, "side": side, "drink": drink, "time_left": MEAL_DURATION}
	notify.emit("You feel well fed. Meal effects last 30 minutes or until your next mission ends.")
	state_changed.emit()

# ------------------------------------------------------------------ quests
func quest_state(id: String) -> String:
	return state.quests.get(id, {}).get("state", "")

func is_done(id: String) -> bool:
	return quest_state(id) == "done"

func has_flag(f: String) -> bool:
	return state.flags.has(f)

func set_flag(f: String) -> void:
	state.flags[f] = true

func quest_giver(id: String) -> String:
	return resolve(DB.quests[id].giver)

func quest_available(id: String) -> bool:
	var q: Dictionary = DB.quests[id]
	if quest_state(id) != "":
		return false
	for r in q.get("requires", []):
		if not is_done(r):
			return false
	if q.type == "main":
		# main quests unlock from the previous quest's "next"
		return state.flags.has("unlock_" + id)
	return job_level() >= int(q.get("level", 1)) - 2

func quests_offered_by(npc_id: String) -> Array:
	var out := []
	for id in DB.quests:
		if quest_available(id) and quest_giver(id) == npc_id:
			out.append(id)
	return out

func start_quest(id: String, silent := false) -> void:
	state.quests[id] = {"state": "active", "progress": 0}
	var q: Dictionary = DB.quests[id]
	for it in q.get("start_items", {}):
		add_item(it, int(q.start_items[it]), true)
	if not silent:
		notify.emit("Quest accepted: " + q.name)
	quest_changed.emit()
	mission_event.emit("accepted", {"quest": id})

func objective(id: String) -> Dictionary:
	return DB.quests[id].objective

func objective_region(id: String) -> String:
	return resolve(objective(id).get("region", ""))

func active_quests() -> Array:
	var out := []
	for id in state.quests:
		if state.quests[id].state == "active":
			out.append(id)
	return out

func quest_progress_text(id: String) -> String:
	var o := objective(id)
	var base := fmt(o.get("text", ""))
	var p := int(state.quests[id].progress)
	match o.kind:
		"hunt_small", "gather":
			return "%s (%d/%d)" % [base, p, int(o.count)]
	return base

func complete_quest(id: String) -> void:
	var q: Dictionary = DB.quests[id]
	var turned_in_to := quest_turn_in(id)
	state.quests[id].state = "done"
	var r: Dictionary = q.get("rewards", {})
	if r.has("gil"):
		add_gil(int(r.gil), true)
	if r.has("xp"):
		add_xp(int(r.xp))
	for it in r.get("items", {}):
		add_item(it, int(r.items[it]))
	for f in r.get("flags", []):
		set_flag(f)
	for it in q.get("start_items", {}):
		remove_item(it, count(it))
	if q.has("next"):
		set_flag("unlock_" + q.next)
		# Main quests from the same giver continue immediately.
		if quest_giver(q.next) == turned_in_to and not DB.quests[q.next].has("intro"):
			start_quest(q.next, true)
	_end_mission_meal()
	notify.emit("Quest complete: " + q.name)
	quest_changed.emit()
	mission_event.emit("quest_complete", {"quest": id})

func _end_mission_meal() -> void:
	if not state.meal.is_empty():
		state.meal = {}

func _bump(id: String, n := 1) -> void:
	var o := objective(id)
	state.quests[id].progress = int(state.quests[id].progress) + n
	if int(state.quests[id].progress) >= int(o.get("count", 1)):
		state.quests[id].progress = int(o.get("count", 1))
		_mark_ready(id)
	quest_changed.emit()

func _mark_ready(id: String) -> void:
	if quest_ready(id):
		return
	state.quests[id].ready = true
	notify.emit("Objective complete! Report to %s." % DB.npcs[quest_turn_in(id)].name)
	quest_changed.emit()
	mission_event.emit("ready", {"quest": id})

func quest_turn_in(id: String) -> String:
	var o := objective(id)
	if o.kind == "talk":
		return resolve(o.npc)
	return quest_giver(id)

func quest_ready(id: String) -> bool:
	return state.quests.get(id, {}).get("ready", false)

## Called by the world when the player talks to an NPC. Returns quests ready to turn in here.
func quests_to_turn_in(npc_id: String) -> Array:
	var out := []
	for id in active_quests():
		var o := objective(id)
		if quest_turn_in(id) == npc_id and (o.kind == "talk" or quest_ready(id)):
			out.append(id)
	return out

func on_monster_killed(monster_id: String, region: String) -> void:
	for id in active_quests():
		var o := objective(id)
		if o.kind == "hunt_small" and o.monster == monster_id and (objective_region(id) == "" or objective_region(id) == region) and not quest_ready(id):
			_bump(id)
		elif o.kind == "hunt_large" and o.monster == monster_id and objective_region(id) == region:
			_mark_ready(id)
	var w: Dictionary = state.writ
	if not w.is_empty() and w.get("monster", "") == monster_id and w.region == region and not w.get("ready", false):
		w.progress = int(w.get("progress", 0)) + 1
		if w.kind == "hunt_large" or int(w.progress) >= int(w.get("count", 1)):
			complete_writ()
		else:
			quest_changed.emit()

func _progress_gather(item: String, n: int) -> void:
	for id in active_quests():
		var o := objective(id)
		if o.kind == "gather" and o.item == item and not quest_ready(id):
			_bump(id, n)
	var w: Dictionary = state.get("writ", {})
	if not w.is_empty() and w.kind == "gather" and w.item == item:
		w.progress = int(w.get("progress", 0)) + n
		if int(w.progress) >= int(w.count):
			complete_writ()
		else:
			quest_changed.emit()

func on_rest() -> void:
	for id in active_quests():
		if objective(id).kind == "rest":
			_mark_ready(id)

func on_mission_success(source: String) -> void:
	if source == "writ":
		complete_writ()
	elif state.quests.has(source):
		_mark_ready(source)

func on_mission_failed(source: String) -> void:
	notify.emit("Mission failed. You may try again.")
	if source == "writ":
		state.writ = {}
	elif state.quests.has(source):
		state.quests[source].progress = 0
	_end_mission_meal()
	quest_changed.emit()

# ------------------------------------------------------------------ writs
func city_fields(city: String) -> Array:
	# fields reachable within two steps of the city
	var out := []
	var frontier := [city]
	for _i in range(2):
		var nxt := []
		for r in frontier:
			for e in DB.regions[r].exits:
				if DB.regions[e.to].type == "field" and not out.has(e.to):
					out.append(e.to)
					nxt.append(e.to)
		frontier = nxt
	return out

func writ_board(city: String) -> Array:
	if not state.writ_board.has(city) or (state.writ_board[city] as Array).is_empty():
		state.writ_board[city] = _generate_writs(city)
	return state.writ_board[city]

func _generate_writs(city: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city) + int(state.writs_done) * 7919 + int(state.playtime)
	var lvl := job_level()
	var fields := city_fields(city)
	var pool := []
	for t in DB.writs:
		if int(t.level) <= lvl + 2 and (not t.has("requires") or is_done(t.requires)):
			pool.append(t)
	var out := []
	for i in range(5):
		var t: Dictionary = pool[rng.randi() % pool.size()]
		var w := t.duplicate(true)
		var candidates := fields.duplicate()
		if t.has("monster"):
			candidates = (DB.QuestsData.MONSTER_HOMES[t.monster] as Array).duplicate()
			if t.kind == "hunt_small":
				var near := candidates.filter(func(r): return fields.has(r))
				if not near.is_empty():
					candidates = near
		elif t.kind == "gather":
			candidates = candidates.filter(func(r): return DB.regions[r].get("gather", []).any(func(g): return g[0] == t.item))
			if candidates.is_empty():
				candidates = fields.duplicate()
		w.region = candidates[rng.randi() % candidates.size()]
		var mult: float = {"hunt_small": 1.0, "gather": 0.8, "defense": 1.3, "escort": 1.2, "hunt_large": 3.5}[t.kind]
		w.gil = int((60 + lvl * 28) * mult)
		w.xp = int((50 + lvl * 35) * mult)
		w.progress = 0
		w.id = "w%d_%d" % [int(state.writs_done), i]
		out.append(w)
	return out

func writ_text(w: Dictionary) -> String:
	var where: String = DB.regions[w.region].name
	match w.kind:
		"hunt_small": return "Defeat %d %s in %s" % [int(w.count), DB.monsters[w.monster].name, where]
		"hunt_large": return "Hunt the %s in %s" % [DB.monsters[w.monster].name, where]
		"gather": return "Gather %d %s in %s" % [int(w.count), DB.item_name(w.item), where]
		"defense": return "Defend the camp in %s" % where
		"escort": return "Escort a traveller through %s" % where
	return ""

func accept_writ(city: String, index: int) -> void:
	var board: Array = writ_board(city)
	state.writ = board[index]
	board.remove_at(index)
	notify.emit("Writ accepted: " + state.writ.title)
	quest_changed.emit()
	mission_event.emit("accepted", {"writ": true})

func complete_writ() -> void:
	var w: Dictionary = state.writ
	if w.is_empty():
		return
	add_gil(int(w.gil), true)
	add_xp(int(w.xp))
	state.writs_done = int(state.writs_done) + 1
	state.writ = {}
	_end_mission_meal()
	notify.emit("Writ complete: " + w.title)
	for id in active_quests():
		if objective(id).kind == "writ":
			_mark_ready(id)
	quest_changed.emit()
	mission_event.emit("writ_complete", w)

## Encounters the world must spawn in `region` for the active quests/writ.
func encounters_for(region: String) -> Array:
	var out := []
	for id in active_quests():
		var o := objective(id)
		if quest_ready(id) or objective_region(id) != region:
			continue
		if o.kind in ["hunt_large", "defense", "escort"]:
			var e: Dictionary = o.duplicate()
			e.source = id
			out.append(e)
	var w: Dictionary = state.get("writ", {})
	if not w.is_empty() and w.region == region and w.kind in ["hunt_large", "defense", "escort"]:
		var e: Dictionary = w.duplicate()
		e.source = "writ"
		if w.kind == "hunt_large":
			e.pos = DB.QuestsData.LARGE_POS[w.monster]
		out.append(e)
	return out

# ------------------------------------------------------------------ misc
func appearance_for_npc(npc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(npc.get("seed", 1))
	var look: Dictionary = npc.get("look", {})
	var a := RacesData.randomize_appearance(rng, look.get("race", ""))
	for k in look:
		a[k] = look[k]
	if look.has("race") and not look.has("clan"):
		a.clan = DB.races[a.race].clans.keys()[0]
	return a

func unlock_job(job: String) -> void:
	state.jobs[job].unlocked = true
	notify.emit("You can now take up the %s job!" % DB.jobs[job].name)
	state_changed.emit()

func change_job(job: String) -> void:
	state.job = job
	notify.emit("Job changed to %s." % DB.jobs[job].name)
	state_changed.emit()

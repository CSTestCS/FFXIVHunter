extends Node
## Automated play-through used during development (and in CI):
##   godot --path . -- --smoke-test [--shots DIR]
## Creates a character in slot 8, visits every region, fights, completes quest steps,
## saves/loads, and fails loudly on script errors. With --shots it also saves screenshots.

var shots := ""
var errors := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		shots = args[i + 1]
		DirAccess.make_dir_recursive_absolute(shots)
	_run()

func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("shot ", name)

func _frames(n: int) -> void:
	for k in range(n):
		await get_tree().process_frame

func _wait_world() -> Node:
	for k in range(600):
		await get_tree().process_frame
		var w = Game.world
		if w and w._ready_done and w.player:
			await _frames(5)
			return w
	push_error("world did not load")
	errors += 1
	return null

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	# world map: every exit needs a way back, every region a waystone
	for r in DB.regions:
		for e in DB.regions[r].exits:
			var back := false
			for e2 in DB.regions[e.to].exits:
				back = back or e2.to == r
			_check(back, "exit %s -> %s has a return exit" % [r, e.to]) if not back else null
		if DB.regions[r].get("waystones", []).is_empty():
			_check(false, "region %s has a waystone" % r)
	for m in DB.QuestsData.MONSTER_HOMES:
		_check(DB.monsters.has(m), "monster %s exists" % m) if not DB.monsters.has(m) else null
	print("regions: %d, monsters: %d" % [DB.regions.size(), DB.monsters.size()])
	for a in ["res://audio/music/title.ogg", "res://audio/music/battle.ogg", "res://audio/amb/forest.ogg", "res://audio/sfx/hit_slash.wav"]:
		_check(ResourceLoader.exists(a), "audio " + a.get_file())
	var only := OS.get_cmdline_user_args().find("--only-regions")
	if only >= 0:
		await _region_shots(OS.get_cmdline_user_args()[only + 1].split(","))
		get_tree().quit()
		return
	# --- title + creator screens
	Game.goto_main_menu()
	await _frames(20)
	await _shot("01_title")
	Game.goto_creator(7)
	await _frames(20)
	await _shot("02_creator")
	var cc: Node = Game.screen
	cc.cat = 4
	cc._build_options()
	cc.zoom_face = true
	await _frames(30)
	await _shot("03_creator_face")
	for c in range(cc.CATS.size()):
		cc.cat = c
		cc._build_options()
		await _frames(2)
	cc.editing = "hero"
	cc._randomize()
	cc._build_options()
	await _frames(3)
	cc.editing = "player"
	cc.step = "job"
	cc.job = "warrior"
	cc._refresh_model()
	cc._build_options()
	cc.zoom_face = false
	await _frames(30)
	await _shot("04_job_select")
	# --- new game (opening cutscene)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var look := DB.RacesData.randomize_appearance(rng, "ferran")
	look.first_name = "Test"
	look.last_name = "Runner"
	var hero := DB.RacesData.randomize_appearance(rng, "aelith")
	hero.first_name = "Aster"
	Game.new_game(7, look, hero, "warrior", "paladin")
	var w = await _wait_world()
	print("opening region: ", w.region_id, " in ", Time.get_ticks_msec() - t0, " ms")
	await _frames(60)
	await _shot("05_opening")
	# skip dialogue by answering every say() immediately
	for k in range(2000):
		if is_instance_valid(w) and w.hud._dlg_open:
			w.hud.dialogue_done.emit(0)
		await get_tree().process_frame
		if Game.world != w and Game.world != null:
			break
	w = await _wait_world()
	for k in range(2000):
		if w.hud._dlg_open:
			w.hud.dialogue_done.emit(0)
		await get_tree().process_frame
		if not w.busy and k > 30:
			break
	print("city: ", w.region_id, " gear=", Game.state.gear)
	await _frames(30)
	await _shot("06_city")
	# talk to the guildmaster (turn in awakening), rest at inn, turn in recovery
	var gm: String = Game.resolve("@guild")
	await _talk(w, gm)
	print("after guild: ", Game.active_quests())
	w.rest(true)
	for k in range(1500):
		if w.hud._dlg_open:
			w.hud.dialogue_done.emit(0)
		await get_tree().process_frame
		if k > 120 and not w.busy:
			break
	await _talk(w, gm)
	print("after recovery: ", Game.active_quests(), " gil=", Game.state.gil)
	_check(Game.has_flag("writs_unlocked"), "writs unlocked")
	# meal + writ
	Game.add_gil(2000)
	Game.eat_meal("roast_boar", "crusty_bread", "spring_water")
	var board := Game.writ_board(w.region_id)
	_check(board.size() == 5, "writ board has 5 writs")
	# every service menu and every pause-menu tab
	Game.set_flag("party_unlocked")
	Game.add_item("iron_ore", 10)
	Game.add_item("beast_hide", 10)
	Game.add_item("m_might_1", 1)
	for kind in ["inn", "canteen", "smith", "materia", "outfitter", "merchant", "recruiter", "job_master", "guild", "writ_board", "waystone"]:
		var npc := ""
		for id in DB.npcs:
			if DB.npcs[id].get("region", "") == w.region_id and DB.npcs[id].role == kind:
				npc = id
		if kind == "waystone":
			npc = "ws_saltcrest"
		var menu := ServiceMenu.new()
		menu.world = w
		menu.kind = kind
		menu.npc_id = npc
		w.hud.add_child(menu)
		await _frames(3)
		for b in menu.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Upgrade") or (b as Button).text.begins_with("Buy Potion") or (b as Button).text.begins_with("Hire") or (b as Button).text.begins_with("Meld") or (b as Button).text.begins_with("[HUNT]"):
				(b as Button).pressed.emit()
				await _frames(2)
				break
		if is_instance_valid(menu):
			menu._close()
		await _frames(2)
	print("  services ok, weapon tier=", Game.state.weapons.warrior.tier, " writ=", Game.state.writ.get("title", ""))
	var gm2 := GameMenu.new()
	gm2.world = w
	w.hud.add_child(gm2)
	await _frames(2)
	for i in range(GameMenu.TABS.size()):
		gm2._show(i)
		await _frames(2)
	gm2._close()
	get_tree().paused = false
	await _frames(2)
	print("  game menu ok")
	# --- visit every region, fight a bit in each field
	for r in DB.regions:
		Game.state.region = r
		Game.state.pos = [0.0, 0.0, 0.0]
		Game.goto_world()
		w = await _wait_world()
		var tl := Time.get_ticks_msec()
		await _frames(30)
		print("region %s ok: %d enemies, %d npcs, %d interactables, fps=%d" % [r, w.enemies.size(), w.npcs.size(), w.interactables.size(), Engine.get_frames_per_second()])
		await _shot("10_" + r)
		if not w.enemies.is_empty():
			var e = w.enemies[0]
			w.player.global_position = e.global_position + Vector3(2, 1, 0)
			e.engage(w.player)
			for k in range(90):
				await get_tree().physics_frame
				if k % 20 == 0:
					w.player._start_move("L1")
				if w.hud._dlg_open:
					w.hud.dialogue_done.emit(0)
			await _shot("11_fight_" + r)
			for e2 in w.enemies.duplicate():
				if e2.alive:
					e2.take_hit({"amount": 1e9, "type": "magic", "source": w.player})
			await _frames(10)
		print("  played %d ms" % (Time.get_ticks_msec() - tl))
	# --- large hunt: spawn grimtusk via quest flags and kill it
	Game.set_flag("unlock_msq_grimtusk")
	for q in ["msq_first_writ", "msq_bandits", "msq_escort"]:
		if Game.quest_state(q) == "":
			Game.state.quests[q] = {"state": "done", "progress": 0}
	Game.start_quest("msq_grimtusk", true)
	Game.state.region = "crossroads"
	Game.state.pos = [60.0, 0.0, -50.0]
	Game.goto_world()
	w = await _wait_world()
	var boss = null
	for e in w.enemies:
		if e.id == "grimtusk":
			boss = e
	_check(boss != null, "grimtusk spawned for quest")
	if boss:
		boss.engage(w.player)
		for k in range(240):
			await get_tree().physics_frame
			if k == 120:
				await _shot("12_grimtusk")
		boss.take_hit({"amount": 1e9, "type": "slash", "source": w.player})
		for k in range(3000):
			if w.hud._dlg_open:
				w.hud.dialogue_done.emit(0)
			await get_tree().process_frame
			if k == 400:
				await _shot("13_lightbearer")
			if k > 200 and not w.busy:
				break
		_check(Game.quest_ready("msq_grimtusk"), "grimtusk quest ready")
	# swimming
	Game.state.region = "saltcrest_shore"
	Game.state.pos = [0.0, 0.0, 170.0]
	Game.goto_world()
	w = await _wait_world()
	for k in range(120):
		if w.hud._dlg_open:
			w.hud.dialogue_done.emit(0)
		await get_tree().physics_frame
	print("swimming=", w.player.swimming, " y=", w.player.global_position.y, " water=", w.terrain.water)
	_check(w.player.swimming, "player swims in the sea")
	await _shot("14_swim")
	# save / load round trip
	_check(Saves.save(7, Game.state), "save slot 8")
	var s := Saves.summary(7)
	print("save summary: ", s)
	_check(Saves.load_into_game(7), "load slot 8")
	w = await _wait_world()
	Saves.delete(7)
	print("SMOKE TEST %s in %d ms, %d errors" % ["PASSED" if errors == 0 else "FAILED", Time.get_ticks_msec() - t0, errors])
	get_tree().quit(0 if errors == 0 else 1)

func _region_shots(ids: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var look := DB.RacesData.randomize_appearance(rng, "hume")
	look.first_name = "Shot"
	Game.state = {}
	Game.new_game(7, look, look.duplicate(), "paladin")
	Game.pending_cutscene = ""
	await _wait_world()
	for r in ids:
		Game.state.region = r
		Game.state.pos = [0.0, 0.0, 0.0]
		Game.state.time = 10.0
		Game.pending_cutscene = ""
		Game.goto_world()
		var w = await _wait_world()
		w.player.yaw = 0.6
		w.player.pitch = -0.15
		await _frames(40)
		print("music=", Audio.current_music())
		await _shot("r_" + r)

func _talk(w: Node, npc: String) -> void:
	if not w.npcs.has(npc):
		push_error("npc missing: " + npc)
		errors += 1
		return
	w.player.global_position = w.npcs[npc].global_position + Vector3(1.5, 0.5, 0)
	await _frames(3)
	w.talk_to(npc)
	for k in range(120):
		if w.hud._dlg_open:
			w.hud.dialogue_done.emit(0)
		var menus: Array = w.hud.get_children().filter(func(c): return c is ServiceMenu)
		for m in menus:
			m._close()
		await get_tree().process_frame
		if not w.busy and k > 10:
			break

func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		errors += 1

extends RefCounted
## Story cutscenes. Each is a short scripted sequence using the world's camera, HUD and actors.
## The player stays an ordinary adventurer; the Dawnward Circle and the Lightbearer appear in
## cameos, always looking capable and powerful, then move on to their own (bigger) battles.

static var _cam: Camera3D

static func play(w: Node, id: String) -> void:
	w.hud.letterbox(true)
	var keep_alive := w
	match id:
		"opening": await _opening(w)
		"opening_city": await _opening_city(w)
		"recovered": await _recovered(w)
		"corvin_bandits": await _corvin(w)
		"lightbearer_vale": await _lightbearer(w)
		"brannoc_defense": await _brannoc(w)
		"elowen_coast": await _elowen(w)
		"rhiannon_dunes": await _rhiannon(w)
		"finale_circle": await _finale(w)
	if not is_instance_valid(keep_alive):
		return
	w.hud.letterbox(false)
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	if is_instance_valid(w.player):
		w.player.cam.make_current()

# ------------------------------------------------------------------ helpers
static func cam(w: Node, pos: Vector3, look: Vector3, fov := 50.0) -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = Camera3D.new()
		_cam.far = 1500
		w.add_child(_cam)
	_cam.look_at_from_position(pos, look)
	_cam.fov = fov
	_cam.make_current()

static func cam_move(w: Node, pos: Vector3, look: Vector3, t: float) -> void:
	var from := _cam.global_transform
	var to := Transform3D(Basis(), pos).looking_at(look)
	var tw := w.create_tween()
	tw.tween_method(func(k: float): _cam.global_transform = from.interpolate_with(to, smoothstep(0.0, 1.0, k)), 0.0, 1.0, t)
	await tw.finished

static func wait(w: Node, t: float) -> void:
	await w.get_tree().create_timer(t).timeout

static func say(w: Node, lines: Array) -> void:
	var out := []
	for l in lines:
		out.append([Game.fmt(l[0]), Game.fmt(l[1])])
	await w.hud.say(out)

static func actor(w: Node, look: Dictionary, outfit: String, job: String, pos: Vector3, name := "") -> Companion:
	var c := Companion.new()
	w.add_child(c)
	c.display_name = name
	c.setup(w, look, job, outfit, 40, "hero", 5)
	c.invulnerable = true
	pos.y = w.terrain.height_at(pos.x, pos.z) + 0.1
	c.global_position = pos
	return c

static func hero(w: Node, npc_id: String, pos: Vector3) -> Companion:
	var d: Dictionary = DB.npcs[npc_id]
	var c := actor(w, Game.appearance_for_npc(d), d.get("outfit", "simple_tunic"), d.get("job", "paladin"), pos, d.name)
	if d.get("role", "") != "hero":
		c.model.set_weapon("", 0)
	return c

static func lightbearer(w: Node, pos: Vector3) -> Companion:
	var look: Dictionary = Game.state.hero
	return actor(w, look, "dawnward_regalia", Game.state.get("hero_job", "paladin"), pos, Game.hero_name())

static func face(c: Node3D, target: Vector3) -> void:
	var d := target - c.global_position
	d.y = 0
	if c is Companion:
		(c as Companion).face = d.normalized()
	c.rotation.y = atan2(-d.x, -d.z)

static func p_front(w: Node, dist: float, side := 0.0) -> Vector3:
	var p: Player = w.player
	return p.global_position + p.face_dir * dist + p.face_dir.cross(Vector3.UP) * side

static func vanish(w: Node, c: Node3D, kind := "blink") -> void:
	if not is_instance_valid(c) or not is_instance_valid(w):
		return
	w.spawn_vfx(kind, c.global_position + Vector3.UP, 2.0)
	c.queue_free()

# ------------------------------------------------------------------ scenes
static func _opening(w: Node) -> void:
	var p: Player = w.player
	w.hud.fade_instant(1.0)
	p.forced_pose = "lying"
	p.model.set_bruised(1.0)
	var road_dir := -p.global_position.normalized()
	road_dir.y = 0
	p.face_dir = road_dir.normalized()
	p.rotation.y = atan2(-p.face_dir.x, -p.face_dir.z)
	var pp := p.global_position
	cam(w, pp + Vector3(0.6, 1.2, 1.8), pp + Vector3(0, 0.3, 0), 45)
	await wait(w, 0.6)
	await w.hud.fade(0.0, 3.0)
	await say(w, [["", "Pain. Cold earth. Somewhere, a bird is singing far too cheerfully."],
		["", "You try to remember how you got here. Nothing comes."]])
	var rid: String = Game.resolve("@rescuer")
	var r := hero(w, rid, pp + p.face_dir * 12.0 + Vector3(3, 0, 0))
	r.model.set_sheathed(true)
	r.walk_to = pp + p.face_dir * 1.4 + Vector3(0.6, 0, 0)
	r.walk_speed = 3.5
	await cam_move(w, pp + Vector3(-2.5, 1.7, 2.5), pp + Vector3(0, 0.8, 0), 3.0)
	r.forced_pose = "kneel"
	face(r, pp)
	await say(w, [["{rescuer}", "Gods above... you're breathing! Easy, easy. Don't try to sit up yet."],
		["{rescuer}", "Stripped to your smallclothes and left in the dirt. Bandits, I'd wager. They've grown bold on these roads since the heroes went their separate ways."],
		["{rescuer}", "Nothing's broken, I think. Lucky. Come on, {home} is just up the road. Lean on me."]])
	await w.hud.fade(1.0, 1.5)
	r.queue_free()
	# into the city
	Game.state.region = Game.state.home
	Game.state.pos = [0.0, 0.0, 0.0]
	Game.state.erase("entry_from")
	Game.pending_cutscene = "opening_city"
	Saves.save(Game.current_slot, Game.state)
	Game.goto_world("opening_city")
	await wait(w, 10.0)

static func _opening_city(w: Node) -> void:
	var p: Player = w.player
	w.hud.fade_instant(1.0)
	Game.state.armor = "simple_tunic"
	Game.state.armor_owned["simple_tunic"] = {"tier": 0, "materia": ["", "", ""]}
	p.refresh_from_state()
	p.model.set_bruised(0.6)
	var rid: String = Game.resolve("@rescuer")
	var n: NPC = w.npcs.get(rid)
	var spot := p_front(w, 2.2, 0.5)
	if n:
		n.global_position = spot
		n.rotation.y = p.rotation.y + PI
		n.talking = true
	var pp := p.global_position
	cam(w, pp + p.face_dir * -3.0 + Vector3(1.5, 1.8, 0), pp + p.face_dir * 1.0 + Vector3(0, 1.2, 0), 50)
	await w.hud.fade(0.0, 1.5)
	await say(w, [["{rescuer}", "Here, my old work clothes. Not much, but better than smallclothes in the market square."],
		["{rescuer}", "That big building across the plaza is the adventurers' guild. {guildmaster} runs it; they'll see you right."],
		["{rescuer}", "Take care of yourself, friend. And stay off the dark roads, eh?"]])
	if n:
		n.talking = false
	w.hud.toast("Quest: speak with {guildmaster} at the Adventurers' Guild.".format({"guildmaster": DB.npcs[Game.resolve("@guild")].name}))
	w.save_game()

static func _recovered(w: Node) -> void:
	var p: Player = w.player
	await w.hud.fade(1.0, 1.0)
	await say(w, [["", "Days pass in a haze of broth, sleep, and the innkeeper's grumbling."],
		["", "Your bruises fade. Your strength returns. Whoever you were before, you're an adventurer now."]])
	p.model.set_bruised(0.0)
	p.forced_pose = "cheer"
	cam(w, p.global_position + p.face_dir * 3.0 + Vector3(0, 1.6, 0), p.global_position + Vector3(0, 1.2, 0), 50)
	await w.hud.fade(0.0, 1.0)
	await wait(w, 1.8)
	p.forced_pose = ""
	w.hud.toast("Report back to the guildmaster.")

static func _corvin(w: Node) -> void:
	var p: Player = w.player
	var pp := p.global_position
	var at := p_front(w, 6.0)
	cam(w, pp + Vector3(0, 2.2, 0) - p.face_dir * 4.0, at + Vector3(0, 1.2, 0), 55)
	await wait(w, 0.4)
	w.spawn_vfx("blink", at + Vector3.UP * 3.0, 2.5)
	var c := hero(w, "corvin", at)
	face(c, pp)
	c.forced_pose = "idle"
	w.shake(0.2)
	await say(w, [["", "A shadow drops from the treetops, silent as falling snow."],
		["Corvin Ashe", "Easy there. I'm not with them."],
		["Corvin Ashe", "Their leader's trussed up behind that rock, waiting for the city guard. Clever lad. Had a dozen escape routes. I had thirteen."],
		["Corvin Ashe", "You handled his crew well enough, though. Here. This yours? Thought so. Bit light, I'm afraid."],
		["Corvin Ashe", "Name's Corvin. Do me a favour and forget you saw me. The Circle's meant to be retired."]])
	c.forced_pose = "wave"
	await wait(w, 0.8)
	vanish(w, c)
	await wait(w, 0.6)

static func _lightbearer(w: Node) -> void:
	var p: Player = w.player
	var pp := p.global_position
	w.shake(0.5)
	await say(w, [["", "The ground trembles. A second roar answers the first, deeper and angrier."]])
	var from := p_front(w, 45.0)
	from.y = w.terrain.height_at(from.x, from.z)
	var alpha := MonsterBody.new()
	w.add_child(alpha)
	alpha.build("quadruped_heavy", ["#3a2a20", "#e0d0b0"], 3.6)
	alpha.global_position = from
	alpha.look_at(Vector3(pp.x, from.y, pp.z), Vector3.UP)
	cam(w, pp + Vector3(0, 2.0, 0) - p.face_dir * 5.0 + p.face_dir.cross(Vector3.UP) * 2.0, from + Vector3.UP * 3.0, 55)
	var tw := w.create_tween()
	var stop := pp + (from - pp).normalized() * 9.0
	stop.y = w.terrain.height_at(stop.x, stop.z)
	tw.tween_property(alpha, "global_position", stop, 2.2)
	for i in range(22):
		alpha.animate(0.1, 9.0, "charge", 1, 0.5, false)
		await wait(w, 0.1)
	# the Lightbearer arrives
	var lb_pos := pp + (stop - pp) * 0.5 + Vector3.UP * 0.2
	w.spawn_vfx("light", lb_pos + Vector3.UP * 6.0, 4.0)
	w.spawn_vfx("holy", lb_pos, 6.0)
	var lb := lightbearer(w, lb_pos)
	face(lb, stop)
	lb.forced_pose = "guard"
	w.shake(0.8)
	await wait(w, 0.5)
	w.spawn_vfx("holy", stop + Vector3.UP * 2.0, 9.0)
	w.spawn_vfx("light", stop + Vector3.UP * 4.0, 6.0)
	w.shake(1.0)
	var tw2 := w.create_tween()
	tw2.tween_property(alpha, "rotation:z", 1.5, 0.8)
	tw2.parallel().tween_property(alpha, "position:y", alpha.position.y - 1.5, 2.0)
	await wait(w, 1.2)
	face(lb, pp)
	lb.forced_pose = "idle"
	cam(w, lb.global_position + (pp - lb.global_position) * 0.5 + Vector3(2.0, 1.7, 0), lb.global_position + Vector3(0, 1.5, 0), 45)
	await say(w, [["", "One blow. The beast that would have trampled you collapses without a sound."],
		["{hero}", "You held the first one off on your own? That took nerve."],
		["{hero}", "Something is driving the beasts out of the deep places. My friends and I are looking into it. Quietly."],
		["{hero}", "Patch yourself up, adventurer. The roads need people like you watching them."]])
	lb.walk_to = lb.global_position + (lb.global_position - pp).normalized() * 12.0
	lb.walk_speed = 2.5
	await wait(w, 2.5)
	vanish(w, lb, "light")
	alpha.queue_free()

static func _brannoc(w: Node) -> void:
	var p: Player = w.player
	var pp := p.global_position
	var at := p_front(w, 7.0, 2.0)
	cam(w, pp + Vector3(0, 2.4, 0) - p.face_dir * 5.0, at + Vector3(0, 1.0, 0), 55)
	w.spawn_vfx("dust", at, 7.0)
	w.shake(0.9)
	var b := hero(w, "brannoc", at)
	face(b, pp)
	b.forced_pose = "cheer"
	await say(w, [["", "Something enormous lands in the middle of the camp, hard enough to rattle your teeth."],
		["Brannoc Stoneheart", "HAH! Still standing, are you? Good! I heard the ruckus from two hills over."],
		["Brannoc Stoneheart", "Name's Brannoc. The guard's on its way, but you did the hard part. Held the line, you did."],
		["Brannoc Stoneheart", "Tell the guild Brannoc owes you a drink. Now, I've a mountain to go and shout at."]])
	b.walk_to = b.global_position + p.face_dir * 15.0
	b.forced_pose = ""
	b.walk_speed = 4.0
	await wait(w, 2.0)
	vanish(w, b, "dust")

static func _elowen(w: Node) -> void:
	var p: Player = w.player
	var at := p_front(w, 9.0, -3.0)
	var e := hero(w, "elowen", at)
	face(e, p.global_position)
	e.forced_pose = "idle"
	cam(w, p.global_position + Vector3(0, 2.0, 0) - p.face_dir * 4.0, at + Vector3(0, 1.4, 0), 50)
	w.spawn_vfx("ice", at + e.face * 4.0, 6.0)
	await say(w, [["", "A tall woman in dark robes stands at the water's edge. The air around her glitters with frost."],
		["Elowen Faye", "Mind your step. The currents here are wrong. The aether is stretched thin, as though something far away were drinking it."],
		["Elowen Faye", "You're hunting the wyrm? Good. It was driven out of deeper waters. Strike at its head when it surfaces; it's slow to recover after a dive."],
		["Elowen Faye", "And eat some kelp rolls before you swim. I'd hate to fish you out."]])
	vanish(w, e, "ice")

static func _rhiannon(w: Node) -> void:
	var p: Player = w.player
	var at := p_front(w, 8.0, 3.0)
	var r := hero(w, "rhiannon", at)
	face(r, p.global_position)
	r.forced_pose = "wave"
	cam(w, p.global_position + Vector3(0, 1.8, 0) - p.face_dir * 4.0, at + Vector3(0, 1.4, 0), 50)
	await say(w, [["Rhiannon Vey", "Hey! You're the one they keep talking about at the Lantern! Well, one of them. You're on the list."],
		["Rhiannon Vey", "The Sandmaw goes under right before it strikes. Watch for the glow under the sand, then run. Don't walk. Run."],
		["Rhiannon Vey", "I'd stay and help, but I'm tracking something a lot bigger than a worm. Good hunting!"]])
	w.spawn_vfx("arrows", at + Vector3.UP * 8.0, 3.0)
	vanish(w, r)

static func _finale(w: Node) -> void:
	var p: Player = w.player
	var pp := p.global_position
	await wait(w, 0.8)
	var ridge := p_front(w, 12.0)
	var ids := ["ysolde", "corvin", "brannoc", "elowen", "rhiannon"]
	var heroes := []
	for i in range(ids.size()):
		var c := hero(w, ids[i], ridge + p.face_dir.cross(Vector3.UP) * (i - 2) * 1.8)
		face(c, pp)
		heroes.append(c)
	var lb := lightbearer(w, ridge + p.face_dir * 1.5)
	face(lb, pp)
	w.spawn_vfx("light", ridge + p.face_dir * 60.0 + Vector3.UP * 30.0, 30.0)
	cam(w, pp + Vector3(0, 1.6, 0) - p.face_dir * 3.0 + p.face_dir.cross(Vector3.UP) * 1.5, ridge + Vector3(0, 1.6, 0), 50)
	await w.hud.fade(0.0, 0.5)
	await say(w, [["", "When the dust settles, you are not alone. Six figures stand on the ridge, haloed by a light on the horizon that is not the sun."],
		["Ysolde Marrow", "Splendid work, {first}. Truly. Every guild in the realm will be telling this one by nightfall."],
		["Brannoc Stoneheart", "Told you. Owes me a drink, this one. Or I owe them. I forget."],
		["{hero}", "There's a storm gathering out past the edge of the maps. Something old is waking, and it's ours to face."],
		["{hero}", "The realm needed heroes once. It still needs adventurers. People who show up, day after day, for the small things and the big ones."],
		["{hero}", "Keep the roads safe while we're gone, {first}."]])
	for c in heroes:
		c.walk_to = c.global_position + p.face_dir * 25.0
	lb.walk_to = lb.global_position + p.face_dir * 25.0
	await wait(w, 2.5)
	for c in heroes:
		vanish(w, c, "light")
	vanish(w, lb, "light")
	await say(w, [["", "And so the adventurer's road goes on."], ["", "Arc I complete. The writ board never empties, and the realm is wide. Thank you for playing!"]])

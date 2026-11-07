class_name Companion
extends Actor
## Party member / escort / cameo hero. Uses the same job movesets as the player.
## mode: "party" (fights, follows), "escort" (walks a route, flees fights), "hero" (cutscene actor)

var model: CharacterModel
var job := "paladin"
var jd: Dictionary
var mode := "party"
var atk := 30.0
var crit := 0.05
var target: Actor = null
var move: Dictionary = {}
var phase := 0
var ptime := 0.0
var hits := {}
var combo := "L1"
var think := 0.0
var down_t := 0.0
var route: Array = []
var route_i := 0
var face := Vector3.FORWARD
var anim_t := 0.0
var anim_phase := 0.0
var forced_pose := ""
var walk_to := Vector3.INF
var walk_speed := 3.0
var level := 1

func setup(w: Node, look: Dictionary, p_job: String, outfit: String, lvl: int, p_mode := "party", tier := -1) -> void:
	world = w
	mode = p_mode
	faction = "ally"
	job = p_job
	jd = DB.jobs[job]
	level = lvl
	var s := Game.compute_stats(job, lvl, outfit, false)
	max_hp = float(s.max_hp) * (0.85 if mode == "party" else 1.0)
	hp = max_hp
	atk = float(s.atk) * 0.8
	defense = float(s.def)
	radius = 0.4
	height = 1.7
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	add_child(cs)
	floor_snap_length = 0.6
	model = CharacterModel.new()
	add_child(model)
	model.build(look, outfit, jd.weapon if mode != "escort" else "", tier if tier >= 0 else clampi(lvl / 6, 0, 5))

func _physics_process(delta: float) -> void:
	if world == null:
		return
	anim_t += delta
	_tick_lifesteal(delta)
	var want := Vector3.ZERO
	if not alive:
		down_t -= delta
		if down_t <= 0.0 and mode == "party":
			alive = true
			hp = max_hp * 0.5
			global_position = world.player.global_position + world.player.forward().rotated(Vector3.UP, PI) * 2.0
			world.hud.toast("%s rejoins the fight!" % display_name)
		_animate(delta, 0.0)
		return
	match mode:
		"party": want = _party_ai(delta)
		"escort": want = _escort_ai()
		"hero":
			if walk_to != Vector3.INF:
				var d := walk_to - global_position
				d.y = 0
				if d.length() > 0.3:
					want = d.normalized() * walk_speed
					face = d.normalized()
				else:
					walk_to = Vector3.INF
	if move.is_empty() or phase != 1:
		velocity.x = lerpf(velocity.x, want.x, 1.0 - exp(-10.0 * delta))
		velocity.z = lerpf(velocity.z, want.z, 1.0 - exp(-10.0 * delta))
	else:
		var l := face * float(move.get("lunge", 0.0)) / maxf(float(move.a), 0.05)
		velocity.x = l.x
		velocity.z = l.z
	if world.terrain and global_position.y < world.terrain.water - 1.1:
		velocity.y = (world.terrain.water - 1.25 - global_position.y) * 2.0
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-12.0 * delta))
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func _party_ai(delta: float) -> Vector3:
	var p: Player = world.player
	if not move.is_empty():
		_tick_move(delta)
		return Vector3.ZERO
	think -= delta
	if think <= 0.0:
		think = 0.3
		target = _pick_target()
		# healer support
		if jd.moves.has("H1") and "heal" in jd.moves.H1.get("flags", []):
			for a in world.allies:
				if a.alive and a.hp < a.max_hp * 0.5 and a.global_position.distance_to(global_position) < 11.0:
					_start("H1")
					return Vector3.ZERO
	# dodge out of telegraphs
	for e in world.enemies:
		if e.ai == "windup" and e.tele and Combat.in_shape(global_position, e.mv.get("tele", "circle"), e._shape_origin(), e.atk_dir,
				float(e.mv.get("radius", 3.0)), float(e.mv.get("angle", 90)), float(e.mv.get("length", 0)), float(e.mv.get("width", 0)), float(e.mv.get("inner", 0)), 1.0):
			var away: Vector3 = global_position - e._shape_origin()
			away.y = 0
			if e.mv.get("tele", "") == "line":
				away = e.atk_dir.cross(Vector3.UP) * (1.0 if away.dot(e.atk_dir.cross(Vector3.UP)) > 0 else -1.0)
			return away.normalized() * 6.0
	if target and is_instance_valid(target) and target.alive:
		var ranged: bool = jd.weapon in ["bow", "gun", "staff", "cane"]
		var want_d: float = 11.0 if ranged else 1.6 + target.radius
		var d := target.global_position - global_position
		d.y = 0
		face = d.normalized()
		if d.length() > want_d + 0.5:
			return d.normalized() * 5.0
		if ranged and d.length() < want_d - 4.0:
			return -d.normalized() * 3.0
		_start(combo)
		return Vector3.ZERO
	# follow the player
	var slot := p.global_position + p.forward().rotated(Vector3.UP, PI * 0.75 + get_index() * 0.6) * 2.6
	var d2 := slot - global_position
	d2.y = 0
	if global_position.distance_to(p.global_position) > 40.0:
		global_position = slot + Vector3.UP
	if d2.length() > 1.2:
		face = d2.normalized()
		return d2.normalized() * clampf(d2.length() * 1.6, 2.0, 7.5)
	return Vector3.ZERO

func _pick_target() -> Actor:
	var p: Player = world.player
	if p.lock_target and is_instance_valid(p.lock_target) and p.lock_target.alive:
		return p.lock_target
	var best: Actor = null
	var bd := 22.0
	for e in world.enemies:
		if e.alive and e.target != null:
			var d: float = e.global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = e
	return best

func _start(id: String) -> void:
	if not jd.moves.has(id):
		id = "L1"
	move = jd.moves[id]
	combo = move.get("light", "L1") if move.has("light") else "L1"
	if id == "H1" or randf() < 0.15:
		combo = "L1"
	phase = 0
	ptime = 0.0
	hits.clear()

func _tick_move(delta: float) -> void:
	ptime += delta
	var durs := [float(move.s), float(move.a), float(move.r) + 0.15]
	if phase == 0 and target and is_instance_valid(target):
		face = flat_dir_to(target.global_position)
	if ptime >= durs[phase]:
		ptime = 0.0
		phase += 1
		if phase == 1:
			_active()
		if phase >= 3:
			move = {}
			return
	if phase == 1 and not ("proj" in move.get("flags", []) or "aoe" in move.get("flags", []) or "heal" in move.get("flags", [])):
		for e in Combat.cone_targets(world.enemies, global_position, face, float(move.get("range", 2.5)), float(move.get("arc", 90))):
			if not hits.has(e):
				hits[e] = true
				e.take_hit(_dmg())

func _dmg() -> Dictionary:
	var c := randf() < crit
	return {"amount": atk * float(move.mv) * (1.5 if c else 1.0), "type": move.get("dmg", "slash"), "source": self, "crit": c, "kb": 0.0}

func _active() -> void:
	var flags: Array = move.get("flags", [])
	if "proj" in flags:
		var p: Dictionary = move.proj
		var origin := model.hand_position() if jd.weapon != "bow" else model.hand_position("left")
		var aim := face
		if target and is_instance_valid(target):
			aim = (target.center() - origin).normalized()
		world.spawn_projectile(self, origin, aim, p, _dmg(), world.enemies)
	if "aoe" in flags:
		var a: Dictionary = move.aoe
		var at := target.global_position if target and is_instance_valid(target) else global_position + face * float(a.dist)
		world.spawn_aoe(self, at, float(a.radius), _dmg(), world.enemies, a.get("fx", "fire"))
	if "heal" in flags:
		for ally in world.allies:
			if ally.alive and ally.global_position.distance_to(global_position) <= float(move.heal.radius):
				ally.heal(ally.max_hp * float(move.heal.ratio) * 0.8)
		world.spawn_vfx("heal", global_position + Vector3.UP, 4.0)

func _escort_ai() -> Vector3:
	if route_i >= route.size():
		return Vector3.ZERO
	var p: Player = world.player
	if p.global_position.distance_to(global_position) > 14.0:
		face = flat_dir_to(p.global_position)
		return Vector3.ZERO
	for e in world.enemies:
		if e.alive and e.target != null and e.global_position.distance_to(global_position) < 14.0:
			return Vector3.ZERO
	var to: Vector3 = route[route_i]
	var d := to - global_position
	d.y = 0
	if d.length() < 2.0:
		route_i += 1
		return Vector3.ZERO
	face = d.normalized()
	return d.normalized() * 2.6

func on_death(_info: Dictionary) -> void:
	if mode == "party":
		down_t = 20.0
		world.hud.toast("%s is down! They'll recover shortly." % display_name)
	else:
		world.on_escort_died(self)

func _animate(delta: float, spd: float) -> void:
	var wk := "" if model.sheathed else model.weapon_kind
	var pose: Dictionary
	if not alive:
		pose = Poses.lying(anim_t)
	elif forced_pose != "":
		match forced_pose:
			"talk": pose = Poses.talk(anim_t)
			"wave": pose = Poses.wave(anim_t)
			"cheer": pose = Poses.cheer(anim_t)
			"kneel": pose = Poses.kneel(anim_t)
			"guard": pose = Poses.guard(model.weapon_kind)
			_: pose = Poses.idle(anim_t, wk)
	elif not move.is_empty():
		var durs := [float(move.s), float(move.a), float(move.r) + 0.15]
		pose = Poses.attack(move.anim, mini(phase, 2), clampf(ptime / durs[mini(phase, 2)], 0.0, 1.0), Poses.idle(anim_t, wk))
		if move.anim == "spin":
			pose["_spin"] = clampf(ptime / durs[1], 0.0, 1.0) if phase == 1 else 0.0
	elif global_position.y < world.terrain.water - 1.0:
		anim_phase += delta * (2.0 + spd)
		pose = Poses.swim(anim_phase, clampf(spd / 3.0, 0.0, 1.0), anim_t)
	elif spd > 0.2:
		anim_phase += delta * spd * 1.9
		pose = Poses.move(anim_phase, clampf(spd / 2.0, 0.0, 1.0) if spd < 2.0 else 1.0 + clampf((spd - 2.0) / 2.8, 0.0, 2.0), anim_t, wk)
	else:
		pose = Poses.idle(anim_t, wk)
	model.animate(delta, pose, 20.0 if not move.is_empty() else 12.0)

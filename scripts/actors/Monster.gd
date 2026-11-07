class_name Monster
extends Actor
## Monster AI. Picks attacks by range/cooldown, telegraphs each one on the ground during the
## wind-up, then commits to it (heavy, punishable). Large monsters enrage below half HP and can be
## staggered by sustained damage. Far-away monsters sleep to save CPU.

var id := ""
var data: Dictionary
var body: MonsterBody
var humanoid: CharacterModel
var level := 1
var attack := 10.0
var speed := 4.0
var home := Vector3.ZERO
var leash := 40.0
var aggro_r := 15.0
var target: Actor = null
var ai := "idle"           # idle, wander, chase, windup, active, recover, stagger, dead
var mv: Dictionary = {}
var mt := 0.0
var cds := {}
var wander_to := Vector3.ZERO
var think := 0.0
var rage := false
var tele: Telegraph = null
var atk_origin := Vector3.ZERO
var atk_dir := Vector3.FORWARD
var atk_target := Vector3.ZERO
var hit_done := {}
var stagger_t := 0.0
var sleep := false
var mission := ""          # quest id / "writ" when spawned for a mission
var is_large := false
var passive := false
var dead_t := 0.0
var engaged := false

func setup(w: Node, monster_id: String, pos: Vector3, lvl_bonus := 0) -> void:
	world = w
	id = monster_id
	data = DB.monsters[id]
	display_name = data.name
	level = int(data.level) + lvl_bonus
	is_large = data.size == "large"
	var lvl_mult := 1.0 + lvl_bonus * 0.12
	max_hp = float(data.hp) * lvl_mult
	hp = max_hp
	attack = float(data.atk) * lvl_mult
	defense = float(data.def) * lvl_mult
	speed = float(data.speed)
	weak = data.weak
	aggro_r = float(data.aggro)
	passive = data.get("passive", false)
	var sc := float(data.scale)
	radius = 0.5 * sc if not is_large else 1.2 * sc
	height = 1.2 * sc if data.body != "humanoid" else 1.75
	max_poise = max_hp * (0.12 if is_large else 0.3)
	leash = 70.0 if is_large else 35.0
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = minf(radius, 0.8)
	cap.height = maxf(cap.radius * 2.0, 1.2)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	floor_snap_length = 1.0
	floor_max_angle = deg_to_rad(55)
	if data.body == "humanoid":
		humanoid = CharacterModel.new()
		add_child(humanoid)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(pos.x * 13.0 + pos.z * 7.0)
		var look := DB.RacesData.randomize_appearance(rng)
		humanoid.build(look, "leather_set" if rng.randf() < 0.5 else "simple_tunic", ["sword_shield", "daggers", "greataxe"][rng.randi() % 3], 0)
	else:
		body = MonsterBody.new()
		add_child(body)
		body.build(data.body, data.colors, sc)
	home = pos
	global_position = pos
	rotation.y = randf() * TAU

func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var player: Player = world.player
	var dp := global_position.distance_to(player.global_position)
	# sleep when far away: no physics, no animation
	var far := dp > (140.0 if is_large else 90.0)
	if far and ai in ["idle", "wander"]:
		if not sleep:
			sleep = true
			visible = dp < 200.0
		return
	sleep = false
	visible = true
	if ai == "dead":
		dead_t += delta
		_animate(delta, 0.0)
		if body:
			body.position.y -= delta * 0.4 * (1.0 if dead_t > 2.0 else 0.0)
		if dead_t > 5.0:
			world.remove_monster(self)
		return
	_tick_lifesteal(delta)
	for k in cds.keys():
		cds[k] = float(cds[k]) - delta
	if poise >= max_poise and ai in ["chase", "idle", "wander", "recover", "windup"]:
		_stagger()
	var want := Vector3.ZERO
	match ai:
		"idle", "wander":
			think -= delta
			if think <= 0.0:
				think = randf_range(2.5, 6.0)
				if randf() < 0.6:
					var a := randf() * TAU
					wander_to = home + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 12.0)
					ai = "wander"
				else:
					ai = "idle"
			if ai == "wander":
				var d := wander_to - global_position
				d.y = 0
				if d.length() > 1.0:
					want = d.normalized() * speed * 0.35
				else:
					ai = "idle"
			if not passive:
				_look_for_target()
		"chase":
			if target == null or not is_instance_valid(target) or not target.alive or home.distance_to(global_position) > leash + 20.0:
				_disengage()
			else:
				var d := target.global_position - global_position
				d.y = 0
				var dist := d.length()
				_face(d.normalized(), delta, 6.0)
				think -= delta
				if think <= 0.0:
					think = 0.25
					var m := _pick_move(dist)
					if not m.is_empty():
						_begin(m)
				if ai == "chase":
					var keep := float(_closest_range()) * 0.8
					if dist > keep:
						want = d.normalized() * speed * (1.2 if rage else 1.0)
					elif dist < 1.0 + radius:
						want = -d.normalized() * speed * 0.3
					else:
						want = forward().rotated(Vector3.UP, PI / 2) * speed * 0.25 * sin(world.time_s * 0.7 + float(get_instance_id() % 7))
		"windup":
			mt += delta
			var wind := float(mv.windup) * (0.8 if rage else 1.0)
			if mv.get("at", "self") != "target" and mt < wind * 0.6 and target and is_instance_valid(target):
				_face(flat_dir_to(target.global_position), delta, 3.0)
				atk_dir = forward()
				atk_origin = global_position
				_update_tele_xform()
			if tele:
				tele.set_fill(clampf(mt / wind, 0.0, 1.0))
			if mt >= wind:
				ai = "active"
				mt = 0.0
				hit_done.clear()
				_on_active_start()
		"active":
			mt += delta
			var act := float(mv.active)
			var dash := float(mv.get("dash", 0.0))
			if dash > 0.0:
				want = atk_dir * dash / act
			if mv.anim == "leap" and mt < act:
				var to := atk_target - global_position
				to.y = 0
				want = to / maxf(act - mt, 0.05)
			_active_hits()
			if mt >= act:
				ai = "recover"
				mt = 0.0
				if tele:
					tele.queue_free()
					tele = null
				if mv.anim in ["dive", "burrow"]:
					invulnerable = false
		"recover":
			mt += delta
			if mt >= float(mv.recover) * (0.8 if rage else 1.0):
				ai = "chase"
				mv = {}
				think = randf_range(0.2, 0.9) if is_large else randf_range(0.6, 1.4)
		"stagger":
			stagger_t -= delta
			if stagger_t <= 0.0:
				ai = "chase"
				poise = 0.0
	# physics
	velocity.x = lerpf(velocity.x, want.x, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, want.z, 1.0 - exp(-8.0 * delta))
	var fly: float = data.get("fly", 0.0)
	if fly > 0.0:
		var gy: float = world.terrain.height_at(global_position.x, global_position.z)
		velocity.y = (gy - global_position.y) * 4.0
	elif data.get("swims", false) and global_position.y < world.terrain.water - 0.5:
		velocity.y = (world.terrain.water - 0.7 - global_position.y) * 3.0
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if mv.get("anim", "") == "leap" and ai == "active":
		var k := mt / float(mv.active)
		velocity.y = (1.0 - 2.0 * k) * 14.0
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func _closest_range() -> float:
	var best := 3.0
	for m in data.moves:
		best = minf(best, maxf(float(m.range[1]), 1.5))
	return best + radius

func _look_for_target() -> void:
	var best: Actor = null
	var bd := aggro_r
	for a in world.allies:
		if not a.alive:
			continue
		var d: float = a.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = a
	if best:
		engage(best)

func engage(t: Actor) -> void:
	if ai == "dead":
		return
	target = t
	if ai in ["idle", "wander"]:
		ai = "chase"
		think = 0.4
		if is_large and not engaged:
			engaged = true
			world.on_large_engaged(self)
			Audio.sfx("roar_large", center(), 4.0)
		elif not is_large and randf() < 0.5:
			Audio.sfx("growl" if data.body != "humanoid" else "jump", center(), -4.0, 0.2)
	# packs help each other
	for e in world.enemies:
		if e != self and e.id == id and e.ai in ["idle", "wander"] and e.global_position.distance_to(global_position) < 18.0:
			e.target = t
			e.ai = "chase"

func _disengage() -> void:
	target = null
	ai = "wander"
	wander_to = home
	hp = minf(max_hp, hp + max_hp * 0.25)

func _face(d: Vector3, delta: float, rate: float) -> void:
	if d.length() < 0.01:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-rate * delta))

func _pick_move(dist: float) -> Dictionary:
	var options := []
	for i in range(data.moves.size()):
		var m: Dictionary = data.moves[i]
		if m.get("rage_only", false) and not rage:
			continue
		if float(cds.get(i, 0.0)) > 0.0:
			continue
		var r: Array = m.range
		if dist >= float(r[0]) and dist <= float(r[1]) + radius:
			options.append(i)
	if options.is_empty():
		return {}
	var i: int = options[randi() % options.size()]
	cds[i] = float(data.moves[i].cd) * (0.75 if rage else 1.0)
	var out: Dictionary = data.moves[i].duplicate()
	out.idx = i
	return out

func _begin(m: Dictionary) -> void:
	mv = m
	ai = "windup"
	mt = 0.0
	atk_dir = forward()
	atk_origin = global_position
	atk_target = target.global_position if target else global_position
	if m.anim in ["dive", "burrow"]:
		invulnerable = true
	var shape: String = m.get("tele", "none")
	if shape != "none":
		tele = world.spawn_telegraph(shape, m)
		_update_tele_xform()
		if is_large:
			Audio.sfx("telegraph", atk_origin, -4.0, 0.0)
	if is_large and randf() < 0.4:
		Audio.sfx("growl", center(), 0.0, 0.15)

func _update_tele_xform() -> void:
	if tele == null:
		return
	var at: String = mv.get("at", "self")
	var origin := atk_origin
	if at == "target":
		origin = atk_target
	elif at == "front":
		origin = atk_origin + atk_dir * radius * 0.6
	tele.place(origin, atk_dir, world.terrain)

func _shape_origin() -> Vector3:
	var at: String = mv.get("at", "self")
	if at == "target":
		return atk_target
	if at == "front":
		return atk_origin + atk_dir * radius * 0.6
	return global_position

func _on_active_start() -> void:
	var snd: String = {"bite": "bite", "lunge": "bite", "slam": "slam", "overhead": "swing_heavy", "slash": "swing_light", "spin": "swing_heavy", "tail": "swing_heavy",
		"charge": "charge", "breath": "breath", "roar": "roar_large" if is_large else "roar_small", "leap": "slam", "dive": "splash", "burrow": "slam", "projectile": "cast"}.get(mv.anim, "whoosh")
	Audio.sfx(snd, center(), 2.0 if is_large else -2.0)
	match mv.anim:
		"projectile":
			world.spawn_vfx("orb_fall", atk_target, float(mv.get("radius", 2.5)))
		"roar":
			world.shake(0.4)
		"slam", "leap", "dive", "burrow":
			world.shake(0.25 if not is_large else 0.5)
	if mv.anim in ["dive", "burrow"]:
		global_position = Vector3(atk_target.x, world.terrain.height_at(atk_target.x, atk_target.z), atk_target.z)
		world.spawn_vfx("splash" if mv.anim == "dive" else "dust", atk_target, float(mv.get("radius", 5.0)))
	elif mv.anim == "breath":
		world.spawn_vfx("breath", center() + atk_dir * radius, float(mv.get("length", mv.get("radius", 8.0))), atk_dir)

func _active_hits() -> void:
	var shape: String = mv.get("tele", "none")
	var origin := _shape_origin()
	var dir := atk_dir
	if shape == "none":
		shape = "cone"
		origin = global_position
		dir = forward()
	var r := float(mv.get("radius", radius + 1.6))
	if mv.get("tele", "none") == "none":
		r = radius + 1.8
	var timing_ok := true
	# slams/leaps/dives hit at the impact moment; sweeps/breaths hit throughout
	if mv.anim in ["slam", "leap", "dive", "burrow", "projectile", "overhead", "roar"]:
		timing_ok = mt <= get_physics_process_delta_time() * 2.0 or (mv.anim == "leap" and mt >= float(mv.active) * 0.85)
	if not timing_ok:
		return
	if mv.get("dash", 0.0) > 0.0:
		shape = "circle"
		origin = global_position
		r = radius + 1.2
	for a in world.allies:
		if not a.alive or hit_done.has(a):
			continue
		if Combat.in_shape(a.global_position, shape, origin, dir, r, float(mv.get("angle", 90.0)), float(mv.get("length", 0.0)), float(mv.get("width", 0.0)), float(mv.get("inner", 0.0)), a.radius):
			hit_done[a] = true
			var kdir: Vector3 = a.global_position - (global_position if shape != "line" else origin)
			kdir.y = 0
			a.take_hit({"amount": attack * float(mv.dmg) * randf_range(0.9, 1.1), "type": "blunt", "source": self,
				"kb": float(mv.kb), "dir": kdir.normalized() if kdir.length() > 0.01 else atk_dir})

func _stagger() -> void:
	ai = "stagger"
	stagger_t = 2.4 if is_large else 1.2
	poise = 0.0
	max_poise *= 1.25
	if tele:
		tele.queue_free()
		tele = null
	invulnerable = false
	if is_large:
		world.hud.toast("%s staggers!" % display_name)

func on_hit(_dmg: float, info: Dictionary) -> void:
	var src = info.get("source", null)
	if src is Actor and (target == null or randf() < 0.15):
		engage(src)
	elif target == null and src is Actor:
		engage(src)
	if not rage and is_large and hp < max_hp * 0.5:
		rage = true
		if body:
			body.set_rage(true)
		world.hud.toast("%s is enraged!" % display_name)
		cds.clear()

func on_death(_info: Dictionary) -> void:
	ai = "dead"
	Audio.sfx("monster_die", center(), 2.0 if is_large else -3.0)
	if tele:
		tele.queue_free()
		tele = null
	collision_layer = 0
	world.on_monster_killed(self)

func _animate(delta: float, spd: float) -> void:
	var ph := -1
	var k := 0.0
	var anim := ""
	match ai:
		"windup": ph = 0; anim = mv.anim; k = mt / maxf(float(mv.windup), 0.01)
		"active": ph = 1; anim = mv.anim; k = mt / maxf(float(mv.active), 0.01)
		"recover": ph = 2; anim = mv.anim; k = mt / maxf(float(mv.recover), 0.01)
	if body:
		body.animate(delta, spd if ai != "dead" else 0.0, anim, ph, clampf(k, 0.0, 1.0), ai == "stagger")
		if ai == "dead":
			body.rotation.z = lerpf(body.rotation.z, 1.4, 1.0 - exp(-3.0 * delta))
	elif humanoid:
		var pose: Dictionary
		if ai == "dead":
			pose = Poses.lying(0.0)
		elif ai == "stagger":
			pose = Poses.hurt(0.5)
		elif ph >= 0:
			var a := "slash_r" if anim == "slash" else "overhead"
			pose = Poses.attack(a, ph, clampf(k, 0, 1), Poses.idle(world.time_s, humanoid.weapon_kind))
		elif spd > 0.3:
			pose = Poses.move(world.time_s * spd * 1.9, clampf(spd / 2.2, 0.0, 2.0), world.time_s, humanoid.weapon_kind)
		else:
			pose = Poses.idle(world.time_s, humanoid.weapon_kind)
		humanoid.animate(delta, pose, 16.0)

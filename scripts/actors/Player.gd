class_name Player
extends Actor
## Player controller: third-person movement, sprint, dodge (i-frames), jump, swim/dive,
## weapon movesets with combos/charging/counters, guard, lock-on, quick items.

const RUN := 4.8
const WALK := 2.0
const SPRINT := 7.4
const SWIM := 3.0
const SWIM_FAST := 5.0
const TAP_TIME := 0.22

var model: CharacterModel
var rig: Node3D
var pitch_node: Node3D
var arm: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.3
var controls := true
var in_city := false

var state := "free"            # free, attack, dodge, hurt, knockdown, guard, item, gather, dead, cutscene
var stats := {}
var job := ""
var jd: Dictionary
var moves: Dictionary
var weapon := ""
var stamina := 100.0
var max_stamina := 100.0
var stamina_delay := 0.0
var exhausted := false
var mp := 100.0
var max_mp := 100.0
var gauge := 0.0
var ammo := 6

var move: Dictionary = {}
var move_id := ""
var phase := 0
var ptime := 0.0
var charge := 0.0
var hit_set := {}
var buffer := ""
var buffer_t := 0.0
var lock_target: Actor = null
var _switch_cd := 0.0

var dodge_hold := -1.0
var sprinting := false
var action_t := 0.0
var action_dur := 0.0
var dodge_dir := Vector3.ZERO
var dodge_kind := "roll"
var kb_vel := Vector3.ZERO
var iframes := 0.0
var swimming := false
var diving := false
var breath := 20.0
var max_breath := 20.0
var anim_phase := 0.0
var anim_t := 0.0
var face_dir := Vector3.FORWARD
var heal_over_time := 0.0
var gather_cb := Callable()
var forced_pose := ""          # cutscene poses: lying, sit, kneel, wave, cheer, talk
var cutscene_move := Vector3.ZERO
var _was_floor := true
var _step_phase := 0.0

func _init() -> void:
	faction = "ally"
	radius = 0.4
	height = 1.7

func setup(w: Node) -> void:
	world = w
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	model = CharacterModel.new()
	add_child(model)
	_build_camera()
	refresh_from_state(true)

func _build_camera() -> void:
	rig = Node3D.new()
	rig.top_level = true
	add_child(rig)
	pitch_node = Node3D.new()
	rig.add_child(pitch_node)
	arm = SpringArm3D.new()
	arm.spring_length = float(Settings.data.cam_distance)
	arm.collision_mask = 1
	arm.margin = 0.2
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	arm.shape = sph
	pitch_node.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 62
	cam.far = 1500
	cam.near = 0.08
	arm.add_child(cam)
	cam.position = Vector3(0.45, 0, 0)
	cam.make_current()

## Re-read job/equipment/appearance from Game.state (after job change, upgrades, outfit change).
func refresh_from_state(full := false) -> void:
	job = Game.state.job
	jd = DB.jobs[job]
	moves = jd.moves
	weapon = jd.weapon
	stats = Game.compute_stats()
	var hp_ratio := hp / max_hp if max_hp > 0 and not full else float(Game.state.get("hp_ratio", 1.0))
	max_hp = stats.max_hp
	hp = clampf(max_hp * hp_ratio, 1.0, max_hp)
	defense = stats.def
	max_stamina = stats.stamina
	max_mp = stats.max_mp
	stamina = minf(stamina, max_stamina)
	mp = minf(mp, max_mp) if not full else max_mp
	max_breath = 20.0 * (1.0 + Game.buff("breath"))
	display_name = Game.player_name()
	var tier := int(Game.state.weapons[job].tier)
	if full or model.look != Game.state.player:
		model.build(Game.state.player, Game.state.gear, weapon, tier)
	else:
		model.set_gear(Game.state.gear)
		model.set_weapon(weapon, tier)
	model.set_sheathed(in_city)

func set_in_city(v: bool) -> void:
	in_city = v
	if model:
		model.set_sheathed(v)

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if not controls:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.data.mouse_sens * 0.01
		yaw -= event.relative.x * s
		pitch -= event.relative.y * s * (-1.0 if Settings.data.invert_y else 1.0)
		pitch = clampf(pitch, -1.2, 0.6)
	elif event.is_action_pressed("zoom_in"):
		arm.spring_length = maxf(1.8, arm.spring_length - 0.4)
	elif event.is_action_pressed("zoom_out"):
		arm.spring_length = minf(9.0, arm.spring_length + 0.4)

func _input_dir() -> Vector3:
	if not controls:
		return Vector3.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var d := Basis(Vector3.UP, yaw) * Vector3(v.x, 0, v.y)
	return d

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	if world == null:
		return
	anim_t += delta
	_tick_lifesteal(delta)
	_update_camera(delta)
	if state == "dead":
		_animate(delta)
		return
	iframes = maxf(0.0, iframes - delta)
	invulnerable = iframes > 0.0 or state == "cutscene"
	_regen(delta)
	var wl: float = world.terrain.water
	var was_swim := swimming
	swimming = global_position.y < wl - 1.15 or (swimming and global_position.y < wl - 0.85 and not is_on_floor())
	if swimming and not was_swim:
		Audio.sfx("splash", global_position)
		if state in ["attack", "guard"]:
			state = "free"
		model.set_sheathed(true)
	elif was_swim and not swimming:
		model.set_sheathed(in_city)
	if controls and state != "cutscene":
		_handle_actions(delta)
	_move(delta, wl)
	_animate(delta)

func _regen(delta: float) -> void:
	stamina_delay -= delta
	var free_stamina: bool = Game.state.get("temp_buffs", {}).has("stamina_free")
	if free_stamina:
		stamina = max_stamina
	if stamina_delay <= 0.0 and not sprinting and state != "guard":
		stamina = minf(max_stamina, stamina + delta * 32.0 * (1.0 + Game.buff("stamina_regen")))
	if exhausted and stamina > max_stamina * 0.3:
		exhausted = false
	mp = minf(max_mp, mp + delta * (6.0 if jd.gauge == "mana" else 3.0))
	if heal_over_time > 0.0:
		var h := minf(heal_over_time, max_hp * 0.4 * delta)
		heal_over_time -= h
		hp = minf(max_hp, hp + h)
	if gauge > 0.0 and jd.gauge in ["fury", "soul", "chakra", "blood", "spirit"] and state != "attack":
		gauge = maxf(0.0, gauge - delta * 0.6)
	# breath
	if swimming and global_position.y + 1.55 < world.terrain.water:
		breath -= delta
		if breath <= 0.0:
			breath = 0.0
			hp -= max_hp * 0.06 * delta
			if hp <= 0.0:
				hp = 0.0
				_faint()
	else:
		breath = minf(max_breath, breath + delta * 6.0)

func use_stamina(n: float) -> bool:
	if Game.state.get("temp_buffs", {}).has("stamina_free"):
		return true
	if exhausted or stamina <= 0.0:
		return false
	stamina -= n
	stamina_delay = 0.7
	if stamina <= 0.0:
		stamina = 0.0
		exhausted = true
	return true

func _handle_actions(delta: float) -> void:
	buffer_t -= delta
	if buffer_t <= 0.0:
		buffer = ""
	_switch_cd -= delta
	if Input.is_action_just_pressed("lock_on"):
		if lock_target:
			lock_target = null
		else:
			lock_target = Combat.nearest(world.enemies, global_position, 32.0, -cam.global_transform.basis.z * Vector3(1, 0, 1), 70.0)
			if lock_target == null:
				yaw = atan2(-face_dir.x, -face_dir.z)
	if lock_target and (not is_instance_valid(lock_target) or not lock_target.alive or lock_target.global_position.distance_to(global_position) > 45.0):
		lock_target = null
	if lock_target and _switch_cd <= 0.0:
		var sx := Input.get_axis("cam_left", "cam_right")
		if absf(sx) > 0.85:
			_switch_target(sign(sx))
			_switch_cd = 0.4
	# dodge tap vs sprint hold
	if Input.is_action_just_pressed("dodge"):
		dodge_hold = 0.0
	if dodge_hold >= 0.0:
		if Input.is_action_pressed("dodge"):
			dodge_hold += delta
		else:
			if dodge_hold < TAP_TIME:
				_try_dodge()
			dodge_hold = -1.0
	sprinting = dodge_hold > TAP_TIME and _input_dir().length() > 0.2 and not exhausted and state == "free"
	var can_fight := not in_city and not swimming
	if Input.is_action_just_pressed("attack_light"):
		_queue_attack("light", can_fight)
	if Input.is_action_just_pressed("attack_heavy"):
		_queue_attack("heavy", can_fight)
	if Input.is_action_just_pressed("weapon_art"):
		_queue_attack("art", can_fight)
	if Input.is_action_just_pressed("jump") and state == "free" and is_on_floor() and not swimming:
		velocity.y = 7.2
		Audio.sfx("jump", global_position)
	if Input.is_action_just_pressed("use_item") and state == "free":
		_use_item()
	if Input.is_action_just_pressed("item_next"):
		_cycle_item(1)
	if Input.is_action_just_pressed("item_prev"):
		_cycle_item(-1)
	var can_guard: bool = jd.guard != "none" and can_fight
	if state == "free" and can_guard and Input.is_action_pressed("guard"):
		state = "guard"
	elif state == "guard" and not Input.is_action_pressed("guard"):
		state = "free"
	if state == "free" and buffer != "" and can_fight:
		_start_from_buffer()

func _switch_target(dir: float) -> void:
	var right := cam.global_transform.basis.x
	var best: Actor = null
	var bs := 1e9
	for e in world.enemies:
		if e == lock_target or not e.alive:
			continue
		var d: Vector3 = e.global_position - global_position
		if d.length() > 32.0:
			continue
		var s := d.dot(right) * dir
		if s > 0.0 and s < bs:
			bs = s
			best = e
	if best:
		lock_target = best

func _queue_attack(kind: String, can_fight: bool) -> void:
	if not can_fight:
		if in_city and kind != "art":
			world.hud.toast("Weapons stay sheathed inside the city.")
		return
	buffer = kind
	buffer_t = 0.4

func _start_from_buffer() -> void:
	var id := ""
	match buffer:
		"light": id = "L1"
		"heavy": id = "H1"
		"art": id = "ART"
	buffer = ""
	_start_move(id)

func _start_move(id: String) -> bool:
	if not moves.has(id):
		return false
	var m: Dictionary = moves[id]
	if m.has("ammo") and ammo < int(m.ammo):
		return _start_move("RELOAD") if id != "RELOAD" else false
	if m.has("gauge_cost"):
		if gauge < float(m.gauge_cost):
			world.hud.toast("Not enough %s." % DB.JobsData.GAUGE_NAMES[jd.gauge])
			return false
		gauge -= float(m.gauge_cost)
	if float(m.get("mp", 0)) > 0.0:
		if mp < float(m.mp):
			world.hud.toast("Not enough mana.")
			return false
		mp -= float(m.mp)
	if float(m.get("st", 0)) > 0.0 and not use_stamina(float(m.st)):
		world.hud.toast("Too exhausted!")
		return false
	if m.has("ammo"):
		ammo -= int(m.ammo)
	move = m
	move_id = id
	phase = 0
	ptime = 0.0
	charge = 0.0
	hit_set.clear()
	state = "attack"
	_face_target(true)
	return true

func _face_target(snap: bool) -> void:
	var d := Vector3.ZERO
	if lock_target and is_instance_valid(lock_target):
		d = flat_dir_to(lock_target.global_position)
	else:
		var inp := _input_dir()
		if inp.length() > 0.2:
			d = inp.normalized()
		elif snap:
			# soft auto-aim at the closest enemy in front
			var t := Combat.nearest(world.enemies, global_position, 8.0, face_dir, 50.0)
			if t:
				d = flat_dir_to(t.global_position)
	if d != Vector3.ZERO:
		face_dir = d if snap else face_dir.slerp(d, 0.25).normalized()

func _try_dodge() -> void:
	if state in ["dodge", "knockdown", "dead", "item", "gather"] or swimming:
		return
	if state == "attack" and not (phase == 2 and ptime > float(move.r) * 0.3) and not (phase == 0 and ptime < 0.06):
		return
	var cost: float = {"roll": 20.0, "step": 15.0, "blink": 18.0}[jd.dodge]
	if not use_stamina(cost):
		return
	dodge_kind = jd.dodge
	Audio.sfx("roll" if dodge_kind != "blink" else "cast", global_position)
	var d := _input_dir()
	dodge_dir = d.normalized() if d.length() > 0.2 else -face_dir
	state = "dodge"
	action_t = 0.0
	action_dur = {"roll": 0.6, "step": 0.38, "blink": 0.3}[dodge_kind]
	if d.length() > 0.2 and lock_target == null:
		face_dir = dodge_dir
	if dodge_kind == "blink":
		world.spawn_vfx("blink", global_position + Vector3.UP, 1.0)
		var to := global_position + dodge_dir * 5.5
		to.y = world.terrain.height_at(to.x, to.z) + 0.1
		if world.terrain.in_bounds(to.x, to.z, 5):
			global_position = to
		world.spawn_vfx("blink", global_position + Vector3.UP, 1.0)

func _use_item() -> void:
	var id: String = Game.state.get("quick_item", "potion")
	if Game.count(id) <= 0:
		world.hud.toast("No %s left." % DB.item_name(id))
		return
	state = "item"
	action_t = 0.0
	action_dur = 1.0

func _cycle_item(dir: int) -> void:
	var list := []
	for id in ["potion", "hi_potion", "ether", "stamina_tonic"]:
		if Game.count(id) > 0:
			list.append(id)
	if list.is_empty():
		return
	var i := list.find(Game.state.get("quick_item", "potion"))
	Game.state.quick_item = list[(i + dir + list.size()) % list.size()]
	world.hud.refresh()

func start_gather(duration: float, cb: Callable) -> void:
	state = "gather"
	action_t = 0.0
	action_dur = duration
	gather_cb = cb

# ------------------------------------------------------------------ movement & states
func _move(delta: float, wl: float) -> void:
	var inp := _input_dir()
	var target_vel := Vector3.ZERO
	var speed_mult := 1.0 + float(stats.get("speed", 0.0))
	match state:
		"free", "guard":
			var spd := RUN
			if state == "guard":
				spd = 1.6
			elif sprinting:
				spd = SPRINT
				if not use_stamina(16.0 * delta):
					sprinting = false
			if swimming:
				spd = SWIM_FAST if sprinting else SWIM
				spd *= 1.0 + Game.buff("swim")
			target_vel = inp.normalized() * spd * speed_mult * minf(inp.length() * 1.5, 1.0)
			if inp.length() > 0.1:
				if lock_target and not sprinting and not swimming:
					face_dir = flat_dir_to(lock_target.global_position)
				else:
					face_dir = face_dir.slerp(inp.normalized(), 1.0 - exp(-12.0 * delta)).normalized()
			elif lock_target and not swimming:
				face_dir = face_dir.slerp(flat_dir_to(lock_target.global_position), 1.0 - exp(-10.0 * delta)).normalized()
		"attack":
			_tick_attack(delta)
			if state == "attack" and phase == 1:
				var a := float(move.a)
				target_vel = face_dir * float(move.get("lunge", 0.0)) / maxf(a, 0.05)
		"dodge":
			action_t += delta
			var k := action_t / action_dur
			var dist: float = {"roll": 4.4, "step": 3.6, "blink": 0.0}[dodge_kind]
			target_vel = dodge_dir * dist / action_dur * (1.4 - k * 0.8)
			if k > 0.06 and k < (0.7 if dodge_kind != "blink" else 1.0):
				iframes = maxf(iframes, 0.02)
			if action_t >= action_dur:
				state = "free"
		"hurt", "knockdown":
			action_t += delta
			kb_vel = kb_vel.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * delta))
			target_vel = kb_vel
			if action_t >= action_dur:
				state = "free"
				if action_dur > 1.0:
					iframes = 0.5
		"item":
			action_t += delta
			target_vel = inp.normalized() * 1.2
			if action_t >= 0.55 and action_t - delta < 0.55:
				_apply_item()
			if action_t >= action_dur:
				state = "free"
		"gather":
			action_t += delta
			if inp.length() > 0.5 or Input.is_action_just_pressed("dodge"):
				state = "free"
				world.hud.toast("Gathering interrupted.")
			elif action_t >= action_dur:
				state = "free"
				if gather_cb.is_valid():
					gather_cb.call()
		"cutscene":
			target_vel = cutscene_move
			if cutscene_move.length() > 0.1:
				face_dir = cutscene_move.normalized()
	var accel := 14.0 if is_on_floor() or swimming else 3.0
	if state in ["dodge", "attack", "hurt", "knockdown"]:
		accel = 30.0
	velocity.x = lerpf(velocity.x, target_vel.x, 1.0 - exp(-accel * delta))
	velocity.z = lerpf(velocity.z, target_vel.z, 1.0 - exp(-accel * delta))
	if swimming:
		var target_y := wl - 1.3
		if controls and Input.is_action_pressed("dive") and state == "free":
			velocity.y = lerpf(velocity.y, -2.6, 1.0 - exp(-4.0 * delta))
			diving = true
		elif controls and Input.is_action_pressed("jump") and diving:
			velocity.y = lerpf(velocity.y, 2.6, 1.0 - exp(-4.0 * delta))
		else:
			diving = global_position.y < target_y - 0.4
			var vy := clampf((target_y - global_position.y) * 2.5, -2.0, 2.5)
			velocity.y = lerpf(velocity.y, vy, 1.0 - exp(-5.0 * delta))
	else:
		diving = false
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif velocity.y < 0:
			velocity.y = -0.5
		if state == "attack" and "leap" in move.get("flags", []):
			if phase == 0 and ptime > float(move.s) * 0.4 and is_on_floor():
				velocity.y = 9.0
			elif phase == 1:
				velocity.y = minf(velocity.y, -16.0)
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2(-face_dir.x, -face_dir.z), 1.0 - exp(-18.0 * delta))
	# soft separation from big monsters so you can't stand inside them
	for e in world.enemies:
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var min_d: float = e.radius + radius
		if d.length() < min_d and d.length() > 0.001:
			global_position += d.normalized() * (min_d - d.length()) * 0.5
	if global_position.y < world.terrain.height_at(global_position.x, global_position.z) - 3.0:
		global_position.y = world.terrain.height_at(global_position.x, global_position.z) + 0.5
	if not _was_floor and is_on_floor():
		Audio.sfx("land", global_position, -6.0)
	if not _was_floor and is_on_floor() and velocity.y < -14.0:
		take_hit({"amount": (-velocity.y - 14.0) * 12.0, "type": "blunt"})
	_was_floor = is_on_floor()

func _tick_attack(delta: float) -> void:
	ptime += delta
	var durs := [float(move.s), float(move.a), float(move.r)]
	var flags: Array = move.get("flags", [])
	if phase == 0:
		_face_target(false)
		var held := Input.is_action_pressed("attack_heavy") if move_id == "H1" else false
		if "charge" in flags and held and ptime >= durs[0] * 0.8 and charge < 1.0:
			charge = minf(1.0, charge + delta)
			ptime = durs[0] * 0.8
			if charge >= 1.0:
				world.spawn_vfx("charge", model.hand_position(), 0.6)
	if ptime >= durs[phase]:
		ptime = 0.0
		phase += 1
		if phase == 1:
			_on_active()
		elif phase == 3:
			state = "free"
			move = {}
			return
	if phase == 1:
		if "iframes" in flags:
			iframes = maxf(iframes, 0.05)
		if not ("proj" in flags or "aoe" in flags or "heal" in flags) and move_id != "RELOAD" and not ("counter" in flags):
			_melee_hits()
	if phase == 2 and buffer != "" and ptime >= durs[2] * 0.25:
		var nxt := ""
		if buffer == "light":
			nxt = move.get("light", "")
		elif buffer == "heavy":
			nxt = move.get("heavy", "")
		elif buffer == "art":
			nxt = "ART"
		buffer = ""
		if nxt != "":
			_start_move(nxt)

func _damage(mv: float) -> Dictionary:
	var crit := Combat.roll_crit(float(stats.crit))
	var amt := float(stats.atk) * mv * (1.0 + charge) * randf_range(0.95, 1.05) * (1.5 if crit else 1.0)
	return {"amount": amt, "type": move.get("dmg", "slash"), "source": self, "crit": crit, "kb": 0.0, "stagger": float(move.get("stagger", 1.0))}

func _melee_hits() -> void:
	var hits := Combat.cone_targets(world.enemies, global_position, face_dir, float(move.get("range", 2.5)), float(move.get("arc", 90)))
	for e in hits:
		if hit_set.has(e):
			continue
		hit_set[e] = true
		var info := _damage(float(move.mv))
		info.dir = face_dir
		var dealt: float = e.take_hit(info)
		if dealt > 0.0:
			_on_dealt(e, dealt, info)

func _on_dealt(_e: Actor, _dealt: float, info: Dictionary) -> void:
	world.hitstop(0.05 if not info.crit else 0.08)
	match jd.gauge:
		"fury": gauge = minf(100.0, gauge + 9.0)
		"soul": gauge = minf(100.0, gauge + 10.0)
		"chakra": gauge = minf(100.0, gauge + 7.0)
		"spirit": gauge = minf(100.0, gauge + 12.0)
		"blood": gauge = minf(100.0, gauge + 8.0)

func _on_active() -> void:
	var flags: Array = move.get("flags", [])
	_attack_sound(flags)
	if move_id == "RELOAD":
		ammo = 6
		world.hud.toast("Reloaded.")
		return
	if "buff" in flags:
		var b: Dictionary = move.buff
		lifesteal = float(b.get("lifesteal", 0.0))
		lifesteal_time = float(b.get("time", 5.0))
	if "proj" in flags:
		var p: Dictionary = move.proj
		var origin := model.hand_position() if weapon != "bow" else model.hand_position("left")
		var aim := _aim_dir(origin)
		var n := int(p.count)
		for i in range(n):
			var spread := 0.0 if n == 1 else lerpf(-float(p.spread), float(p.spread), float(i) / (n - 1))
			var dir := aim.rotated(Vector3.UP, deg_to_rad(spread + randf_range(-1.0, 1.0) * (1.0 if n > 1 else 0.0)))
			world.spawn_projectile(self, origin, dir, p, _damage(float(move.mv)), world.enemies)
	if "aoe" in flags:
		var a: Dictionary = move.aoe
		var at := global_position + face_dir * float(a.dist)
		if lock_target and is_instance_valid(lock_target) and lock_target.global_position.distance_to(global_position) < float(a.dist) + 6.0 and float(a.dist) > 0.0:
			at = lock_target.global_position
		at.y = world.terrain.height_at(at.x, at.z)
		world.spawn_aoe(self, at, float(a.radius), _damage(float(move.mv)), world.enemies, a.get("fx", "fire"))
	if "heal" in flags:
		var h: Dictionary = move.heal
		for ally in world.allies:
			if ally.alive and ally.global_position.distance_to(global_position) <= float(h.radius):
				ally.heal(ally.max_hp * float(h.ratio))
		world.spawn_vfx("heal", global_position + Vector3.UP, float(h.radius) * 0.5)

func _aim_dir(origin: Vector3) -> Vector3:
	if lock_target and is_instance_valid(lock_target):
		return (lock_target.center() - origin).normalized()
	var t := Combat.nearest(world.enemies, global_position, 40.0, face_dir, 18.0)
	if t:
		return (t.center() - origin).normalized()
	var f := -cam.global_transform.basis.z
	f.y = clampf(f.y + 0.12, -0.5, 0.5)
	return f.normalized() if face_dir.dot(f) > 0.3 else face_dir

func _apply_item() -> void:
	var id: String = Game.state.get("quick_item", "potion")
	if not Game.remove_item(id, 1):
		return
	var it: Dictionary = DB.items[id]
	Audio.sfx("potion", global_position)
	if it.has("heal"):
		heal_over_time += max_hp * float(it.heal)
		world.spawn_vfx("heal", global_position + Vector3.UP, 1.2)
	if it.has("mana"):
		mp = minf(max_mp, mp + max_mp * float(it.mana))
	if it.has("buff"):
		for k in it.buff:
			Game.state.temp_buffs[k] = float(it.buff[k])
	world.hud.refresh()

# ------------------------------------------------------------------ getting hit
func intercept_hit(dmg: float, info: Dictionary) -> float:
	var src = info.get("source", null)
	var from_front := true
	if src is Node3D:
		from_front = face_dir.dot(flat_dir_to((src as Node3D).global_position)) > 0.35
	if state == "attack" and phase == 1 and "counter" in move.get("flags", []) and from_front:
		# perfect counter: negate and riposte
		world.spawn_vfx("parry", center() + face_dir * 0.6, 1.0)
		Audio.sfx("parry", center())
		world.hud.toast("Counter!")
		if src is Actor:
			var c := _damage(float(move.mv) * 1.2)
			c.stagger = 3.0
			var dealt: float = (src as Actor).take_hit(c)
			if dealt > 0:
				_on_dealt(src, dealt, c)
		gauge = minf(100.0, gauge + 20.0)
		iframes = 0.4
		return 0.0
	if state == "attack" and phase <= 1 and "guardpoint" in move.get("flags", []) and from_front:
		use_stamina(dmg * 0.3)
		return 0.0
	if state == "guard" and from_front:
		var chip := 0.0 if jd.guard == "shield" else 0.25
		var cost := dmg * (0.35 if jd.guard == "shield" else 0.55)
		if use_stamina(cost):
			world.spawn_vfx("block", center() + face_dir * 0.5, 0.7)
			Audio.sfx("block", center())
			kb_vel = -face_dir * minf(float(info.get("kb", 0.0)), 3.0) * 2.0
			return dmg * chip
		# guard broken
		state = "free"
		world.hud.toast("Guard broken!")
	if swimming:
		return dmg * 0.85
	return dmg

func on_hit(dmg: float, info: Dictionary) -> void:
	Game.state.hp_ratio = hp / max_hp
	var kb := float(info.get("kb", 0.0))
	var dir: Vector3 = info.get("dir", -face_dir)
	dir.y = 0
	if state == "guard":
		return
	if kb >= 3.0:
		state = "knockdown"
		action_t = 0.0
		action_dur = 1.5
		kb_vel = dir.normalized() * kb * 2.2
		move = {}
	elif kb > 0.0 or dmg > max_hp * 0.05:
		if state != "attack" or dmg > max_hp * 0.12:
			state = "hurt"
			action_t = 0.0
			action_dur = 0.35
			kb_vel = dir.normalized() * kb * 2.0
			move = {}

func on_death(_info: Dictionary) -> void:
	_faint()

func _faint() -> void:
	if state == "dead":
		return
	if Game.count("phoenix_down") > 0:
		Game.remove_item("phoenix_down", 1)
		alive = true
		hp = max_hp * 0.5
		iframes = 2.0
		world.spawn_vfx("heal", global_position + Vector3.UP, 2.5)
		world.hud.toast("The Phoenix Plume flares, and you rise again!")
		return
	state = "dead"
	alive = false
	lock_target = null
	world.on_player_faint()

func revive_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	alive = true
	hp = max_hp
	stamina = max_stamina
	mp = max_mp
	breath = max_breath
	state = "free"
	iframes = 2.0
	Game.state.hp_ratio = 1.0

# ------------------------------------------------------------------ camera & animation
func _update_camera(delta: float) -> void:
	if controls:
		var look := Vector2(Input.get_axis("cam_left", "cam_right"), Input.get_axis("cam_up", "cam_down"))
		if lock_target == null:
			var s: float = Settings.data.pad_sens
			yaw -= look.x * s * delta
			pitch -= look.y * s * delta * 0.7 * (-1.0 if Settings.data.invert_y else 1.0)
			pitch = clampf(pitch, -1.2, 0.6)
	if lock_target and is_instance_valid(lock_target):
		var to := lock_target.center() - (global_position + Vector3.UP * 1.5)
		var want := atan2(-to.x, -to.z)
		yaw = lerp_angle(yaw, want, 1.0 - exp(-6.0 * delta))
		var flat := Vector2(to.x, to.z).length()
		pitch = lerpf(pitch, clampf(-atan2(-to.y + 1.5, flat) - 0.12, -0.9, 0.3), 1.0 - exp(-4.0 * delta))
	var target_pos := global_position + Vector3.UP * (1.55 if not swimming else 1.0)
	rig.global_position = rig.global_position.lerp(target_pos, 1.0 - exp(-14.0 * delta)) if rig.global_position.distance_to(target_pos) < 6.0 else target_pos
	rig.rotation = Vector3(0, yaw, 0)
	pitch_node.rotation = Vector3(pitch, 0, 0)

func _animate(delta: float) -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	# slope under a lying body (head lies "behind" the feet)
	if forced_pose == "lying" or state in ["dead", "knockdown"]:
		var back := -face_dir * model.height_m * 0.9
		var hf: float = world.terrain.height_at(global_position.x, global_position.z)
		var hh: float = world.terrain.height_at(global_position.x + back.x, global_position.z + back.z)
		model.ground_pitch = atan2(hh - hf, model.height_m * 0.9)
	var wk := "" if (model.sheathed) else weapon
	var pose: Dictionary
	var sharp := 14.0
	if forced_pose != "":
		match forced_pose:
			"lying": pose = Poses.lying(anim_t)
			"sit": pose = Poses.sit(anim_t)
			"kneel": pose = Poses.kneel(anim_t)
			"wave": pose = Poses.wave(anim_t)
			"cheer": pose = Poses.cheer(anim_t)
			"talk": pose = Poses.talk(anim_t)
			_: pose = Poses.idle(anim_t, wk)
		if cutscene_move.length() > 0.1:
			anim_phase += delta * hv * 1.9
			pose = Poses.move(anim_phase, clampf(hv / RUN * 2.0, 0.0, 2.0), anim_t, "")
		model.animate(delta, pose, 6.0)
		return
	match state:
		"dead":
			pose = Poses.lying(anim_t)
			sharp = 5.0
		"attack":
			var durs := [float(move.s), float(move.a), float(move.r)]
			var k := ptime / maxf(durs[mini(phase, 2)], 0.001)
			pose = Poses.attack(move.anim, mini(phase, 2), k, Poses.idle(anim_t, wk))
			if move.anim == "spin":
				pose["_spin"] = clampf(k, 0.0, 1.0) if phase == 1 else 0.0
			sharp = 26.0
		"guard":
			pose = Poses.guard(weapon)
			sharp = 18.0
		"dodge":
			if dodge_kind == "roll":
				pose = Poses.roll(action_t / action_dur)
			else:
				pose = Poses.step(action_t / action_dur)
			sharp = 30.0
		"hurt":
			pose = Poses.hurt(action_t / action_dur)
			sharp = 24.0
		"knockdown":
			pose = Poses.knockdown(action_t / action_dur)
			sharp = 12.0
		"item":
			pose = Poses.merge([Poses.idle(anim_t, ""), Poses.arm("right", 120, 30, 10, 130), {"head": Vector3(14, 0, 0)}])
		"gather":
			pose = Poses.kneel(anim_t)
			pose.merge(Poses.arm("right", 60 + sin(anim_t * 6.0) * 20.0, 10, 15, 30), true)
		_:
			if swimming:
				var before := anim_phase
				anim_phase += delta * (2.0 + hv)
				if hv > 0.5 and floor(anim_phase / TAU) != floor(before / TAU):
					Audio.sfx("swim", global_position, -6.0)
				pose = Poses.swim(anim_phase, clampf(hv / SWIM, 0.0, 1.0), anim_t)
				sharp = 6.0
			elif not is_on_floor() and absf(velocity.y) > 2.0:
				pose = Poses.airborne(velocity.y)
				sharp = 8.0
			else:
				var k := clampf(hv / WALK, 0.0, 1.0) if hv < WALK else 1.0 + clampf((hv - WALK) / (RUN - WALK), 0.0, 1.0) + clampf((hv - RUN) / (SPRINT - RUN), 0.0, 1.0)
				anim_phase += delta * hv * (1.9 if hv < RUN + 0.5 else 1.45)
				pose = Poses.move(anim_phase, k, anim_t, wk)
				_footsteps(hv)
	model.animate(delta, pose, sharp)

func _attack_sound(flags: Array) -> void:
	var p := global_position + Vector3.UP
	if move_id == "RELOAD":
		Audio.sfx("reload", p)
	elif "proj" in flags:
		match weapon:
			"bow": Audio.sfx("bow", p)
			"gun": Audio.sfx("gun", p)
			_: Audio.sfx("cast", p)
	elif "aoe" in flags or "heal" in flags:
		Audio.sfx("cast_big" if "aoe" in flags else "heal", p)
	elif weapon in ["fists", "daggers"]:
		Audio.sfx("whoosh", p)
	else:
		Audio.sfx("swing_heavy" if weapon in ["greatsword", "greataxe", "scythe"] or move_id != "L1" and move_id != "L2" else "swing_light", p)

func _footsteps(hv: float) -> void:
	if not is_on_floor() or hv < 0.5:
		return
	if floor(anim_phase / PI) != floor(_step_phase / PI):
		var kind := "grass"
		var b: String = world.rd.biome
		if world.is_city or world.terrain.mask_at(global_position.x, global_position.z) > 0.5:
			kind = "stone"
		elif b in ["desert", "canyon", "coast"] and global_position.y < world.terrain.water + 2.0 or b in ["desert", "canyon"]:
			kind = "sand"
		elif b == "snow":
			kind = "snow"
		elif b in ["volcanic", "crystal", "highland"]:
			kind = "stone"
		Audio.sfx("step_" + kind, global_position, -8.0 if hv < RUN else -4.0, 0.15)
	_step_phase = anim_phase

## Values saved back into Game.state (position, hp).
func write_state() -> void:
	Game.state.pos = [global_position.x, global_position.y, global_position.z]
	Game.state.hp_ratio = hp / max_hp if alive else 1.0

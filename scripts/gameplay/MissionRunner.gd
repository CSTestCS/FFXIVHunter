extends Node
## Spawns and runs mission encounters in the current region: large hunts, defense waves,
## escorts, and extra targets for small hunts. Missions fail after 3 faints (Monster Hunter rule).

const MAX_FAINTS := 3

var world: Node
var active := {}      # source -> state dictionary
var faints := {}

func setup() -> void:
	refresh()

func active_sources() -> Array:
	return active.keys()

func refresh() -> void:
	var encs: Array = Game.encounters_for(world.region_id)
	var srcs := []
	for e in encs:
		srcs.append(e.source)
		if not active.has(e.source):
			_start(e)
	for src in active.keys():
		if not srcs.has(src):
			_cleanup(src)
	_ensure_small_targets()
	_update_marker()

func _process(delta: float) -> void:
	for src in active.keys():
		var a: Dictionary = active[src]
		match a.kind:
			"defense": _tick_defense(src, a, delta)
			"escort": _tick_escort(src, a)
	_update_marker()

func _update_marker() -> void:
	var target = null
	for src in active:
		var a: Dictionary = active[src]
		match a.kind:
			"hunt_large":
				if is_instance_valid(a.get("monster")):
					target = a.monster.global_position
			"defense":
				if is_instance_valid(a.get("camp")):
					target = a.camp.global_position
			"escort":
				if is_instance_valid(a.get("npc")):
					target = a.npc.global_position
	world.hud.set_objective(target)

func _start(e: Dictionary) -> void:
	var src: String = e.source
	match e.kind:
		"hunt_large":
			var p: Vector3 = e.pos
			var lvl_bonus := maxi(0, Game.job_level() - int(DB.monsters[e.monster].level) - 2) / 2
			var m: Monster = world.spawn_monster(e.monster, p, lvl_bonus)
			m.mission = src
			active[src] = {"kind": "hunt_large", "monster": m}
			world.hud.toast("The %s is somewhere in this region. Follow the marker." % DB.monsters[e.monster].name)
		"defense":
			var hub: Vector3 = world.waystones.values()[0].global_position if not world.waystones.is_empty() else Vector3.ZERO
			var p := hub + Vector3(9, 0, 0)
			p.y = world.terrain.height_at(p.x, p.z)
			var camp := _make_camp(p)
			var st := {"kind": "defense", "camp": camp, "running": false, "t": 0.0, "dur": float(e.get("duration", 80)), "wave_t": 0.0, "waves": 0}
			active[src] = st
			st.entry = world.add_interactable(p, 5.0, "Begin the defense", func(): _begin_defense(src), camp)
		"escort":
			var hub: Vector3 = world.waystones.values()[0].global_position if not world.waystones.is_empty() else Vector3.ZERO
			var far: Vector3 = hub
			var fd := 0.0
			for ex in world.rd.exits:
				var ep: Vector3 = world.terrain.exit_point(ex, 30.0)
				if ep.distance_to(hub) > fd:
					fd = ep.distance_to(hub)
					far = ep
			var route := []
			var n := int(hub.distance_to(far) / 15.0)
			for i in range(1, n + 1):
				var q := hub.lerp(far, float(i) / n)
				q.y = world.terrain.height_at(q.x, q.z)
				route.append(q)
			var c := Companion.new()
			world.add_child(c)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(src)
			var look := DB.RacesData.randomize_appearance(rng)
			c.display_name = "Traveller"
			c.setup(world, look, "paladin", "desert_silks", 1, "escort")
			c.max_hp = 900.0 + Game.job_level() * 60.0
			c.hp = c.max_hp
			c.global_position = hub + Vector3(4, 0.5, 4)
			c.route = route
			c.route_i = route.size()  # waits until the player starts the escort
			world.allies.append(c)
			var st := {"kind": "escort", "npc": c, "route": route, "ambush": [0.33, 0.66], "started": false}
			active[src] = st
			st.entry = world.add_interactable(c.global_position, 3.0, "Begin the escort", func(): _begin_escort(src), c)

func _cleanup(src: String) -> void:
	var a: Dictionary = active[src]
	for k in ["camp", "npc"]:
		if a.has(k) and is_instance_valid(a[k]):
			world.allies.erase(a[k])
			a[k].queue_free()
	if a.has("entry"):
		world.remove_interactable(a.entry)
	active.erase(src)

# ------------------------------------------------------------------ defense
func _make_camp(p: Vector3) -> Actor:
	var camp := Actor.new()
	camp.faction = "ally"
	camp.display_name = "Camp"
	camp.max_hp = 1600.0 + Game.job_level() * 120.0
	camp.hp = camp.max_hp
	camp.defense = 20.0
	camp.radius = 2.0
	camp.height = 2.5
	camp.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.6, 2.4, 2.2)
	cs.shape = bs
	cs.position.y = 1.2
	camp.add_child(cs)
	var st := MeshKit.begin()
	MeshKit.box(st, Vector3(0, 0.9, 0), Vector3(3.4, 0.9, 2.0), Basis(), Color("7a5a3a"))
	for sx in [-1.2, 1.2]:
		for sz in [-1.1, 1.1]:
			MeshKit.tube(st, Vector3(sx, 0.45, sz), Vector3(sx, 0.45, sz * 1.15), 0.45, 0.45, 12, true, Vector2.ONE, Color("4a3220"))
	MeshKit.ellipsoid(st, Vector3(0, 1.4, 0), Vector3(1.8, 1.2, 1.1), Basis(), 12, 8, func(d: Vector3) -> bool: return d.y > 0.0, Color("e8dcc0"))
	for k in range(4):
		MeshKit.box(st, Vector3(-1.0 + k * 0.6, 1.5, 0), Vector3(0.5, 0.5, 0.5), Basis(Vector3.UP, k * 0.4), Color("a08060"))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st, MeshKit.vcol_pbr(0.85))
	camp.add_child(mi)
	world.add_child(camp)
	camp.world = world
	camp.global_position = p
	world.allies.append(camp)
	return camp

func _begin_defense(src: String) -> void:
	var a: Dictionary = active[src]
	if a.running:
		return
	a.running = true
	world.remove_interactable(a.entry)
	a.erase("entry")
	world.hud.toast("Defend the camp for %d seconds!" % int(a.dur))

func _tick_defense(src: String, a: Dictionary, delta: float) -> void:
	if not a.running:
		return
	var camp: Actor = a.camp
	if not is_instance_valid(camp) or not camp.alive:
		world.hud.toast("The camp has fallen!")
		Game.on_mission_failed(src)
		_cleanup(src)
		return
	a.t += delta
	a.wave_t -= delta
	world.hud.set_timer(maxf(0.0, a.dur - a.t), "Defend the camp", camp.hp / camp.max_hp)
	if a.wave_t <= 0.0 and a.t < a.dur - 8.0:
		a.wave_t = 20.0
		a.waves += 1
		var pool: Array = world.rd.get("spawns", [["hopper", 1]])
		var n := 2 + mini(int(a.waves), 3)
		var ang := randf() * TAU
		for i in range(n):
			var s: Array = pool[randi() % pool.size()]
			var p: Vector3 = camp.global_position + Vector3(cos(ang + i * 0.3), 0, sin(ang + i * 0.3)) * 34.0
			if world.terrain.is_water(p.x, p.z):
				p = camp.global_position + Vector3(cos(ang + PI), 0, sin(ang + PI)) * 30.0
			var m: Monster = world.spawn_monster(s[0], p, maxi(0, Game.job_level() - int(DB.monsters[s[0]].level)) / 2)
			m.mission = src
			m.leash = 999.0
			m.engage(camp)
		world.hud.toast("Wave %d approaches!" % int(a.waves))
	if a.t >= a.dur:
		world.hud.set_timer(-1.0, "", 0.0)
		for e in world.enemies:
			if e.mission == src and e.alive:
				e.take_hit({"amount": 1e9, "type": "magic"})
		Game.on_mission_success(src)
		_cleanup(src)

# ------------------------------------------------------------------ escort
func _begin_escort(src: String) -> void:
	var a: Dictionary = active[src]
	if a.started:
		return
	a.started = true
	a.npc.route_i = 0
	world.remove_interactable(a.entry)
	a.erase("entry")
	world.hud.toast("Stay close; the traveller only walks when you're nearby.")

func _tick_escort(src: String, a: Dictionary) -> void:
	if not a.started:
		return
	var c: Companion = a.npc
	if not is_instance_valid(c):
		return
	var prog := float(c.route_i) / maxf(1.0, a.route.size())
	world.hud.set_timer(-2.0, "Escort: %d%%" % int(prog * 100.0), c.hp / c.max_hp)
	if not (a.ambush as Array).is_empty() and prog >= float(a.ambush[0]):
		a.ambush.remove_at(0)
		var pool: Array = world.rd.get("spawns", [["bandit", 1]])
		var ahead: Vector3 = c.global_position + c.face * 22.0
		for i in range(3):
			var s: Array = pool[randi() % pool.size()]
			var m: Monster = world.spawn_monster(s[0], ahead + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), maxi(0, Game.job_level() - int(DB.monsters[s[0]].level)) / 2)
			m.mission = src
			m.engage(c)
		world.hud.toast("Ambush!")
	if c.route_i >= a.route.size():
		world.hud.set_timer(-1.0, "", 0.0)
		world.hud.toast("The traveller arrives safely!")
		Game.on_mission_success(src)
		_cleanup(src)

func on_escort_died(c: Companion) -> void:
	for src in active.keys():
		if active[src].get("npc") == c:
			world.hud.set_timer(-1.0, "", 0.0)
			world.hud.toast("The traveller has fallen...")
			Game.on_mission_failed(src)
			_cleanup(src)
			refresh()
			return

# ------------------------------------------------------------------ hunts
func _ensure_small_targets() -> void:
	var needs := {}
	for id in Game.active_quests():
		var o := Game.objective(id)
		if o.kind == "hunt_small" and Game.objective_region(id) == world.region_id and not Game.quest_ready(id):
			needs[o.monster] = maxi(int(needs.get(o.monster, 0)), int(o.count) - int(Game.state.quests[id].progress))
	var w: Dictionary = Game.state.get("writ", {})
	if not w.is_empty() and w.kind == "hunt_small" and w.region == world.region_id:
		needs[w.monster] = maxi(int(needs.get(w.monster, 0)), int(w.count) - int(w.get("progress", 0)))
	for mid in needs:
		var have := 0
		for e in world.enemies:
			if e.id == mid and e.alive:
				have += 1
		var missing: int = int(needs[mid]) - have
		if missing > 0:
			var c: Vector3 = world._random_land_point(50.0)
			for i in range(missing):
				world.spawn_monster(mid, c + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))

func on_mission_monster_killed(_m: Monster) -> void:
	pass

## Returns true when the mission has failed (3 faints).
func on_player_faint() -> bool:
	for src in active.keys():
		var a: Dictionary = active[src]
		var engaged: bool = a.kind != "hunt_large" or (is_instance_valid(a.get("monster")) and a.monster.target != null)
		if a.kind == "defense" and not a.running:
			engaged = false
		if a.kind == "escort" and not a.started:
			engaged = false
		if not engaged:
			continue
		faints[src] = int(faints.get(src, 0)) + 1
		if int(faints[src]) >= MAX_FAINTS:
			world.hud.toast("Fainted %d times. Mission failed." % MAX_FAINTS)
			if a.kind == "hunt_large" and is_instance_valid(a.monster):
				world.enemies.erase(a.monster)
				a.monster.queue_free()
			Game.on_mission_failed(src)
			_cleanup(src)
			faints.erase(src)
			world.hud.set_timer(-1.0, "", 0.0)
			return true
		world.hud.toast("Faints: %d / %d" % [int(faints[src]), MAX_FAINTS])
	return false

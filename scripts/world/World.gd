extends Node3D
## The playable world. Generates the current region from data, then hosts the player, NPCs,
## monsters, companions, missions, effects and HUD. Only one region is loaded at a time.

const TerrainShader := preload("res://shaders/terrain.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")
const MissionRunnerScript := preload("res://scripts/gameplay/MissionRunner.gd")
const StoryScript := preload("res://scripts/gameplay/Story.gd")

var region_id := ""
var rd: Dictionary
var terrain: Terrain
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var player: Player
var hud: HUD
var fx: Fx
var mission: Node
var enemies: Array = []
var allies: Array = []
var npcs := {}
var interactables: Array = []
var time_s := 0.0
var busy := false
var city_info := {}
var is_city := false
var map_tex: ImageTexture
var waystones := {}
var _shake := 0.0
var _hitstop_until := 0
var _lamps: Array[OmniLight3D] = []
var _respawns := []
var _prompt: Dictionary = {}
var _uw := false
var _base_fog := 0.0
var _lost_gil: Node3D
var _ready_done := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	Game.world = self
	region_id = Game.state.region
	rd = DB.regions[region_id].duplicate(true)
	rd.id = region_id
	is_city = rd.type == "city"
	rng.seed = int(rd.seed) + int(Time.get_ticks_msec())
	hud = HUD.new()
	add_child(hud)
	hud.world = self
	hud.show_loading(rd.name, rd.get("subtitle", ""))
	await get_tree().process_frame
	await get_tree().process_frame
	_build()
	_ready_done = true
	hud.setup_for_world()
	await get_tree().process_frame
	hud.hide_loading()
	hud.banner(rd.name, rd.get("subtitle", ""))
	Game.mission_event.connect(_on_mission_event)
	Game.quest_changed.connect(_refresh_markers)
	_refresh_markers()
	var cs: String = Game.pending_cutscene
	Game.pending_cutscene = ""
	if cs != "":
		await play_cutscene(cs)
	else:
		_check_pre_cutscenes()
	if not Game.state.waystones.has(_first_waystone()) and _first_waystone() != "" and is_city:
		_attune(_first_waystone(), true)

func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null
	if Game.mission_event.is_connected(_on_mission_event):
		Game.mission_event.disconnect(_on_mission_event)
	if Game.quest_changed.is_connected(_refresh_markers):
		Game.quest_changed.disconnect(_refresh_markers)
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)
	Engine.time_scale = 1.0

# ================================================================== build
func _build() -> void:
	terrain = Terrain.new()
	terrain.generate(rd)
	var city: CityBuilder = null
	var hub: Vector3 = rd.waystones[0].pos if not rd.get("waystones", []).is_empty() else Vector3.ZERO
	if is_city:
		city = CityBuilder.new()
		city.prepare(terrain, rd)
	else:
		var r2 := RandomNumberGenerator.new()
		r2.seed = int(rd.seed)
		terrain.flatten(hub, 7.0, NAN, 8.0)
		for e in rd.exits:
			terrain.road_between(terrain.exit_point(e, 0.0), hub, r2, 4.5)
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	if city:
		city_info = city.build(props)
		hub = city_info.waystone
		for p in city.lamps:
			if _lamps.size() < 6 and (p as Vector3).distance_to(city_info.center) < 45.0:
				var l := OmniLight3D.new()
				l.light_color = Color("ffc27a")
				l.omni_range = 9.0
				l.light_energy = 0.0
				l.shadow_enabled = false
				l.position = p
				props.add_child(l)
				_lamps.append(l)
	terrain.build(self, _terrain_material())
	if terrain.water > -100.0:
		_build_water()
	fx = Fx.new()
	fx.world = self
	add_child(fx)
	_setup_environment()
	# interactable places
	var avoid := [[hub, 14.0]]
	for e in rd.exits:
		avoid.append([terrain.exit_point(e, 10.0), 16.0])
	if not is_city:
		for m in DB.QuestsData.LARGE_POS:
			if DB.QuestsData.MONSTER_HOMES[m].has(region_id):
				avoid.append([DB.QuestsData.LARGE_POS[m], 12.0])
		Vegetation.populate(props, terrain, rd, avoid)
	_build_waystones(hub)
	_build_exits()
	_build_gather_nodes(avoid)
	_spawn_npcs()
	_spawn_monsters()
	_spawn_player(hub)
	_spawn_party()
	mission = MissionRunnerScript.new()
	mission.world = self
	add_child(mission)
	mission.setup()
	_build_lost_gil()
	var img := terrain.map_image(256)
	map_tex = ImageTexture.create_from_image(img)

func _terrain_material() -> ShaderMaterial:
	var bio: Dictionary = DB.biomes[rd.biome]
	var m := ShaderMaterial.new()
	m.shader = TerrainShader
	for k in ["grass", "grass2", "rock", "sand", "dirt"]:
		m.set_shader_parameter(k, Color(bio[k]))
	if is_city:
		m.set_shader_parameter("pave", CityBuilder.STYLES[rd.city].pave)
	m.set_shader_parameter("water_level", terrain.water)
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	n.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	tex.generate_mipmaps = true
	m.set_shader_parameter("detail", tex)
	var n2 := FastNoiseLite.new()
	n2.frequency = 0.06
	n2.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = n2
	m.set_shader_parameter("detail_n", nt)
	return m

func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(terrain.size + 400.0, terrain.size + 400.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position.y = terrain.water
	var m := ShaderMaterial.new()
	m.shader = WaterShader
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	nt.noise = n
	m.set_shader_parameter("waves", nt)
	if rd.biome == "swamp":
		m.set_shader_parameter("shallow", Color(0.22, 0.32, 0.18))
		m.set_shader_parameter("deep", Color(0.06, 0.1, 0.06))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Water"
	add_child(mi)

func _setup_environment() -> void:
	var sk: Dictionary = rd.sky
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(sk.top)
	sky_mat.sky_horizon_color = Color(sk.horizon)
	sky_mat.ground_horizon_color = Color(sk.horizon)
	sky_mat.ground_bottom_color = Color(sk.fog).darkened(0.5)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(sk.fog)
	env.fog_density = float(sk.fog_density)
	_base_fog = env.fog_density
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.25
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = float(sk.sun)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.6
	add_child(sun)
	Settings.apply_environment(env, sun)
	Settings.changed.connect(_on_settings_changed)
	_update_time(0.0)

func _on_settings_changed() -> void:
	Settings.apply_environment(env, sun)

func _update_time(delta: float) -> void:
	Game.state.time = fmod(float(Game.state.get("time", 8.0)) + delta / 120.0, 24.0)  # 1 game hour = 2 real minutes
	var t: float = Game.state.time
	var day := clampf(sin((t - 6.0) / 12.0 * PI), -1.0, 1.0)
	var elev := deg_to_rad(lerpf(4.0, 62.0, clampf(day, 0.0, 1.0)))
	var az := (t / 24.0) * TAU + 0.6
	var sk: Dictionary = rd.sky
	var dayk := smoothstep(-0.15, 0.25, day)
	if day > -0.05:
		sun.rotation = Vector3(-elev, az, 0)
		sun.light_color = Color(1.0, 0.94, 0.86).lerp(Color(1.0, 0.62, 0.38), 1.0 - smoothstep(0.0, 0.35, day))
		sun.light_energy = float(sk.sun) * lerpf(0.15, 1.0, dayk)
	else:
		# moonlight
		sun.rotation = Vector3(-deg_to_rad(40.0), az + PI, 0)
		sun.light_color = Color(0.55, 0.65, 0.95)
		sun.light_energy = 0.22
	sky_mat.sky_top_color = Color(sk.top).lerp(Color("0b1224"), 1.0 - dayk)
	sky_mat.sky_horizon_color = Color(sk.horizon).lerp(Color("1c2540"), 1.0 - dayk).lerp(Color("e89a5c"), (1.0 - absf(day - 0.12) * 5.0) * 0.5 * float(day > -0.1 and day < 0.3))
	env.ambient_light_energy = lerpf(0.35, 0.95, dayk)
	if not _uw:
		env.fog_light_color = Color(sk.fog).lerp(Color("1a2236"), 1.0 - dayk)
	var lamp_e := 1.6 * (1.0 - dayk)
	for l in _lamps:
		l.light_energy = lamp_e
		l.visible = lamp_e > 0.05

# ================================================================== places
func _first_waystone() -> String:
	return rd.waystones[0].id if not rd.get("waystones", []).is_empty() else ""

func _build_waystones(hub: Vector3) -> void:
	for ws in rd.get("waystones", []):
		var p: Vector3 = hub if ws == rd.waystones[0] else ws.pos
		p.y = terrain.height_at(p.x, p.z)
		var n := Node3D.new()
		n.position = p
		add_child(n)
		var st := MeshKit.begin()
		MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 0.6, 0), 1.6, 1.4, 10, true, Vector2.ONE, Color("8a8478"))
		var base := MeshInstance3D.new()
		base.mesh = MeshKit.finish(st, MeshKit.vcol_pbr(0.85))
		n.add_child(base)
		var cs := MeshKit.begin()
		MeshKit.ellipsoid(cs, Vector3(0, 2.6, 0), Vector3(0.5, 1.6, 0.5), Basis(), 6, 4)
		var crystal := MeshInstance3D.new()
		crystal.mesh = MeshKit.finish(cs, MeshKit.pbr(Color("3f8fd0"), 0.08, 0.2, Color("4fb8ff"), 0.9))
		crystal.name = "Crystal"
		n.add_child(crystal)
		var light := OmniLight3D.new()
		light.light_color = Color("7fd4ff")
		light.omni_range = 10.0
		light.light_energy = 1.2
		light.position.y = 2.5
		n.add_child(light)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.5
		cyl.height = 1.2
		col.shape = cyl
		body.add_child(col)
		n.add_child(body)
		waystones[ws.id] = n
		var wid: String = ws.id
		add_interactable(p, 3.5, "Waystone", func(): _waystone_menu(wid), n)

func _build_exits() -> void:
	for e in rd.exits:
		var p := terrain.exit_point(e, 6.0)
		p.y = terrain.height_at(p.x, p.z)
		var n := Node3D.new()
		n.position = p
		add_child(n)
		var st := MeshKit.begin()
		MeshKit.tube(st, Vector3(2.5, 0, 0), Vector3(2.5, 2.6, 0), 0.1, 0.08, 6, true, Vector2.ONE, Color("4a3220"))
		MeshKit.box(st, Vector3(2.5, 2.3, 0), Vector3(1.4, 0.4, 0.08), Basis(), Color("7a5a3a"))
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.finish(st, MeshKit.vcol_pbr(0.8))
		n.add_child(mi)
		var glow := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 4.0
		cyl.bottom_radius = 4.0
		cyl.height = 6.0
		cyl.cap_top = false
		cyl.cap_bottom = false
		glow.mesh = cyl
		glow.material_override = fx.fx_mat if fx else null
		glow.position.y = 3.0
		n.add_child(glow)
		glow.set_instance_shader_parameter("tint", Color(0.4, 0.75, 1.0, 0.35))
		var to: String = e.to
		add_interactable(p, 6.0, "Travel to %s" % DB.regions[to].name, func(): travel(to), n)

func _build_gather_nodes(avoid: Array) -> void:
	var r2 := RandomNumberGenerator.new()
	r2.seed = int(rd.seed) + 77
	var extra := []
	for id in Game.active_quests():
		var o := Game.objective(id)
		if o.kind == "gather" and (Game.objective_region(id) == "" or Game.objective_region(id) == region_id) and not o.item in ["wisp_ember"]:
			extra.append([o.item, int(o.count) + 2, "pearl" if o.item == "pearl" else ("ore" if "ore" in o.item else "herb")])
	var w: Dictionary = Game.state.get("writ", {})
	if not w.is_empty() and w.kind == "gather" and w.region == region_id:
		extra.append([w.item, int(w.count) + 2, "pearl" if w.item == "pearl" else ("ore" if "ore" in w.item else "herb")])
	var list: Array = rd.get("gather", []).duplicate()
	list.append_array(extra)
	for g in list:
		for i in range(int(g[1])):
			var p := Vector3.ZERO
			var ok := false
			for _t in range(40):
				p = Vector3(r2.randf_range(-terrain.half + 40, terrain.half - 40), 0, r2.randf_range(-terrain.half + 40, terrain.half - 40))
				var h := terrain.height_at(p.x, p.z)
				if g[2] == "pearl":
					ok = h < terrain.water - 2.5 and h > terrain.water - 14.0
				else:
					ok = h > terrain.water + 0.8 and terrain.normal_at(p.x, p.z).y > 0.75
				if ok:
					break
			if not ok:
				continue
			p.y = terrain.height_at(p.x, p.z)
			_gather_node(p, g[0], g[2])

func _gather_node(p: Vector3, item: String, kind: String) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var st := MeshKit.begin()
	var mat: Material
	match kind:
		"ore":
			MeshKit.rock(st, Vector3(0, 0.4, 0), Vector3(0.9, 0.7, 0.8), int(p.x * 10))
			for k in range(4):
				MeshKit.ellipsoid(st, Vector3(randf_range(-0.5, 0.5), 0.6 + randf() * 0.4, randf_range(-0.4, 0.4)), Vector3.ONE * 0.14, Basis(), 6, 4, Callable(), Color("c9d6ff"))
			mat = MeshKit.vcol_pbr(0.5, 0.3)
		"log":
			MeshKit.tube(st, Vector3(-1.0, 0.3, 0), Vector3(1.0, 0.35, 0.1), 0.3, 0.28, 8, true, Vector2.ONE, Color("6b4a2e"))
			mat = MeshKit.vcol_pbr(0.85)
		"pearl":
			MeshKit.ellipsoid(st, Vector3(0, 0.15, 0), Vector3(0.45, 0.2, 0.4), Basis(), 10, 6, func(d: Vector3) -> bool: return d.y < 0.3, Color("d8c8b8"))
			MeshKit.ellipsoid(st, Vector3(0, 0.25, 0), Vector3.ONE * 0.12, Basis(), 8, 6, Callable(), Color("fff8f0"))
			mat = MeshKit.vcol_pbr(0.2)
			(mat as StandardMaterial3D).emission_enabled = true
			(mat as StandardMaterial3D).emission = Color("a0e0ff")
			(mat as StandardMaterial3D).emission_energy_multiplier = 0.6
		_:
			for k in range(6):
				var a := k * TAU / 6.0
				MeshKit.ellipsoid(st, Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3), Vector3(0.25, 0.35, 0.25), Basis(), 6, 4, Callable(), Color("6fa84a") if item != "sunleaf" else Color("e8c84a"))
			mat = MeshKit.vcol_pbr(0.7)
			if item == "sunleaf":
				(mat as StandardMaterial3D).emission_enabled = true
				(mat as StandardMaterial3D).emission = Color("ffd860")
				(mat as StandardMaterial3D).emission_energy_multiplier = 0.4
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st, mat)
	mi.visibility_range_end = 120.0
	n.add_child(mi)
	var verb: String = {"ore": "Mine", "log": "Chop", "pearl": "Collect", "herb": "Gather"}.get(kind, "Gather")
	var entry := add_interactable(p, 2.6 if kind != "pearl" else 3.0, "%s %s" % [verb, DB.item_name(item)], Callable(), n)
	entry.cb = func():
		player.start_gather(1.6, func():
			var n_items := 1 + (1 if randf() < Game.buff("gather") + 0.2 else 0)
			Game.add_item(item, n_items)
			remove_interactable(entry)
			n.queue_free())

# ================================================================== actors
func _spawn_npcs() -> void:
	var used := {}
	for id in DB.npcs:
		var d: Dictionary = DB.npcs[id]
		var spot: Dictionary = {}
		if d.get("region", "") == region_id and is_city:
			var role: String = d.role
			var list: Array = city_info.spots.get(role, [])
			var k := int(used.get(role, 0))
			if role in ["quest", "villager"] or k >= list.size():
				var a := float(hash(id) % 628) / 100.0
				var r := 12.0 + float(hash(id + "r") % 900) / 100.0
				var c: Vector3 = city_info.center
				var p := c + Vector3(cos(a), 0, sin(a)) * r
				spot = {"pos": p, "rot": a}
			else:
				spot = list[k]
				used[role] = k + 1
		else:
			# field NPCs (quest givers placed by quests)
			for qid in DB.quests:
				var q: Dictionary = DB.quests[qid]
				if q.get("giver", "") == id and q.get("giver_region", "") == region_id and (Game.quest_state(qid) != "" or Game.quest_available(qid)):
					spot = {"pos": q.giver_pos, "rot": 0.0}
			if spot.is_empty():
				continue
		if d.role == "writ_board":
			var bp: Vector3 = spot.pos
			add_interactable(bp, 3.0, "Guild Writ Board", func(): open_service("writ_board", ""), null)
			continue
		var n := NPC.new()
		add_child(n)
		var look := Game.appearance_for_npc(d)
		n.setup(self, id, d, look)
		var p: Vector3 = spot.pos
		p.y = terrain.height_at(p.x, p.z)
		n.global_position = p
		n.rotation.y = float(spot.rot) + PI
		npcs[id] = n
		var nid: String = id
		add_interactable(p, 2.8, "Talk to %s" % d.name, func(): talk_to(nid), n)
	# ambient townsfolk walking around the plaza
	if is_city:
		for i in range(6):
			var d := {"name": "Townsperson", "title": "", "role": "villager", "seed": int(rd.seed) * 100 + i, "outfit": ["simple_tunic", "desert_silks", "ranger_garb", "sea_coat"][i % 4]}
			var n := NPC.new()
			add_child(n)
			n.setup(self, "", d, Game.appearance_for_npc(d))
			var c: Vector3 = city_info.center
			var pts := []
			for k in range(4):
				var a := rng.randf() * TAU
				var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(10.0, 26.0)
				p.y = terrain.height_at(p.x, p.z)
				pts.append(p)
			n.global_position = pts[0]
			n.wander = pts

func _spawn_monsters() -> void:
	if is_city:
		return
	for s in rd.get("spawns", []):
		var mid: String = s[0]
		var count := int(s[1])
		var pack := int(DB.monsters[mid].get("pack", 1))
		var i := 0
		while i < count:
			var c := _random_land_point(40.0)
			for k in range(mini(pack, count - i)):
				var p := c + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
				spawn_monster(mid, p)
				i += 1

func _random_land_point(margin: float) -> Vector3:
	for _t in range(60):
		var p := Vector3(rng.randf_range(-terrain.half + margin, terrain.half - margin), 0, rng.randf_range(-terrain.half + margin, terrain.half - margin))
		if terrain.height_at(p.x, p.z) > terrain.water + 0.5 and terrain.normal_at(p.x, p.z).y > 0.8:
			var hub: Vector3 = waystones.values()[0].global_position if not waystones.is_empty() else Vector3.ZERO
			if p.distance_to(hub) > 30.0:
				p.y = terrain.height_at(p.x, p.z)
				return p
	return Vector3.ZERO

func spawn_monster(mid: String, p: Vector3, lvl_bonus := 0) -> Monster:
	var m := Monster.new()
	add_child(m)
	p.y = terrain.height_at(p.x, p.z) + 0.3
	if DB.monsters[mid].get("swims", false):
		p.y = maxf(p.y, terrain.water - 0.7)
	m.setup(self, mid, p, lvl_bonus)
	enemies.append(m)
	return m

func remove_monster(m: Monster) -> void:
	enemies.erase(m)
	if m.mission == "" and not m.is_large:
		_respawns.append([time_s + 90.0, m.id, m.home])
	m.queue_free()

func _spawn_player(hub: Vector3) -> void:
	player = Player.new()
	add_child(player)
	player.setup(self)
	var pos := Vector3.ZERO
	var from: String = Game.state.get("entry_from", "")
	if from != "":
		for e in rd.exits:
			if e.to == from:
				pos = terrain.exit_point(e, 16.0)
				var inward := -terrain.exit_point(e, 0.0).normalized()
				player.face_dir = Vector3(inward.x, 0, inward.z).normalized()
		Game.state.erase("entry_from")
	elif Game.state.get("pos", []).size() == 3:
		var a: Array = Game.state.pos
		pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
	if pos == Vector3.ZERO:
		pos = hub + Vector3(3, 0, 3)
	pos.y = maxf(terrain.height_at(pos.x, pos.z), pos.y) + 0.2
	player.global_position = pos
	player.yaw = atan2(-player.face_dir.x, -player.face_dir.z)
	player.rotation.y = player.yaw
	player.set_in_city(is_city)
	allies.append(player)

func _spawn_party() -> void:
	var lvl := Game.job_level()
	for cid in Game.state.get("party", []):
		var c: Dictionary = DB.companions[cid]
		var comp := Companion.new()
		add_child(comp)
		comp.display_name = c.name
		comp.setup(self, Game.appearance_for_npc(c), c.job, c.outfit, maxi(1, lvl - 1), "party")
		comp.global_position = player.global_position + Vector3(rng.randf_range(-2, 2), 0.5, rng.randf_range(1, 3))
		comp.model.set_sheathed(is_city)
		allies.append(comp)

func _build_lost_gil() -> void:
	var lg: Dictionary = Game.state.get("dropped_gil", {})
	if lg.is_empty() or lg.get("region", "") != region_id:
		return
	var a: Array = lg.pos
	var p := Vector3(float(a[0]), float(a[1]), float(a[2]))
	_lost_gil = Node3D.new()
	_lost_gil.position = p
	add_child(_lost_gil)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	mi.mesh = sm
	mi.material_override = MeshKit.pbr(Color("ffd860"), 0.2, 0.5, Color("ffc040"), 3.0)
	mi.position.y = 1.0
	_lost_gil.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color("ffc040")
	l.omni_range = 5.0
	l.position.y = 1.0
	_lost_gil.add_child(l)
	add_interactable(p, 2.5, "Recover lost gil (%d)" % int(lg.amount), func():
		Game.add_gil(int(lg.amount))
		Game.state.dropped_gil = {}
		_lost_gil.queue_free()
		hud.toast("You recovered your lost gil."), _lost_gil)

# ================================================================== loop
func _process(delta: float) -> void:
	if not _ready_done:
		return
	Engine.time_scale = 0.12 if Time.get_ticks_msec() < _hitstop_until else 1.0
	time_s += delta
	_update_time(delta)
	_update_camera_fx(delta)
	_update_interact()
	for i in range(_respawns.size() - 1, -1, -1):
		var r: Array = _respawns[i]
		if time_s > float(r[0]) and player.global_position.distance_to(r[2]) > 60.0:
			spawn_monster(r[1], r[2])
			_respawns.remove_at(i)
	for w in waystones.values():
		var c: Node3D = w.get_node("Crystal")
		c.rotation.y += delta * 0.6
		c.position.y = sin(time_s * 1.5) * 0.15
	if not busy and Input.is_action_just_pressed("menu") and player.controls:
		open_game_menu()
	elif not busy and Input.is_action_just_pressed("map") and player.controls:
		open_game_menu("Map")

func _update_camera_fx(delta: float) -> void:
	if player == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.25
		cam.v_offset = randf_range(-1, 1) * _shake * 0.25
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	var uw := cam.global_position.y < terrain.water - 0.05
	if uw != _uw:
		_uw = uw
		env.fog_density = 0.09 if uw else _base_fog
		env.fog_light_color = Color("1d4a6b") if uw else Color(rd.sky.fog)
		hud.set_underwater(uw)

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

## Brief freeze on heavy hits (game feel). Uses real time so it can't stretch itself.
func hitstop(t: float) -> void:
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(t * 1000.0))

func add_interactable(pos: Vector3, r: float, text: String, cb: Callable, node: Node = null) -> Dictionary:
	var e := {"pos": pos, "r": r, "text": text, "cb": cb, "node": node}
	interactables.append(e)
	return e

func remove_interactable(e: Dictionary) -> void:
	interactables.erase(e)

func _update_interact() -> void:
	if busy or player == null or not player.controls or player.state != "free":
		if not _prompt.is_empty():
			_prompt = {}
			hud.set_prompt("")
		return
	var best: Dictionary = {}
	var bd := 1e9
	for e in interactables:
		var n = e.node
		if n != null and not is_instance_valid(n):
			continue
		var p: Vector3 = (n as Node3D).global_position if n is Node3D else e.pos
		var d := Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length()
		if d < float(e.r) and absf(p.y - player.global_position.y) < 4.0 and d < bd:
			bd = d
			best = e
	if best != _prompt:
		_prompt = best
		hud.set_prompt("" if best.is_empty() else best.text)
	if not best.is_empty() and Input.is_action_just_pressed("interact"):
		best.cb.call()

# ================================================================== events
func on_actor_damaged(a: Actor, dmg: float, info: Dictionary) -> void:
	var col := Color("ffffff")
	if a is Player or a is Companion:
		col = Color("ff6a5c")
	elif info.get("crit", false):
		col = Color("ffb030")
	fx.number(a.center() + Vector3.UP * a.height * 0.4, int(dmg), col)
	if not (a is Player):
		fx.vfx("crit" if info.get("crit", false) else "hit", a.center(), 0.5 if not info.get("crit", false) else 0.9)
	if a is Player:
		shake(minf(0.35, dmg / a.max_hp * 2.0))
		hud.refresh_bars()

func on_monster_killed(m: Monster) -> void:
	var d: Dictionary = m.data
	Game.add_xp(int(float(d.xp) * (1.0 + (m.level - int(d.level)) * 0.15)))
	Game.add_gil(int(d.gil), false)
	for drop in d.drops:
		if randf() < float(drop[1]):
			Game.add_item(drop[0], 1)
	Game.on_monster_killed(m.id, region_id)
	if m.is_large:
		hud.boss(null)
		shake(0.6)
	if m.mission != "":
		mission.on_mission_monster_killed(m)

func on_large_engaged(m: Monster) -> void:
	hud.boss(m)

func on_escort_died(c: Companion) -> void:
	mission.on_escort_died(c)

func on_player_faint() -> void:
	busy = true
	player.controls = false
	hud.toast("You have fainted...")
	await get_tree().create_timer(2.0).timeout
	await hud.fade(1.0, 0.8)
	var failed: bool = mission.on_player_faint()
	if not failed and Game.state.get("writ", {}).is_empty() and mission.active_sources().is_empty():
		# Elden Ring style: drop some gil where you fell; recover it before fainting again
		var amount := int(int(Game.state.gil) * 0.3)
		if amount > 0:
			Game.state.gil = int(Game.state.gil) - amount
			Game.state.dropped_gil = {"region": region_id, "pos": [player.global_position.x, player.global_position.y, player.global_position.z], "amount": amount}
	var ws: String = Game.state.get("last_waystone", "")
	var p: Vector3 = waystones.values()[0].global_position + Vector3(2, 0.5, 2) if not waystones.is_empty() else player.global_position
	if ws != "" and waystones.has(ws):
		p = waystones[ws].global_position + Vector3(2, 0.5, 2)
	player.revive_at(p)
	for c in allies:
		if c is Companion:
			c.global_position = p + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2))
	if Game.state.get("dropped_gil", {}).get("region", "") == region_id and _lost_gil == null:
		_build_lost_gil()
	await hud.fade(0.0, 0.8)
	busy = false
	player.controls = true
	hud.refresh()

func _on_mission_event(kind: String, data: Dictionary) -> void:
	_refresh_markers()
	if kind == "ready" and data.has("quest"):
		var q: Dictionary = DB.quests[data.quest]
		if q.has("cutscene_post") and not Game.has_flag("seen_" + q.cutscene_post):
			Game.set_flag("seen_" + q.cutscene_post)
			await get_tree().create_timer(1.5).timeout
			await play_cutscene(q.cutscene_post)
	if kind in ["accepted", "ready", "writ_complete"]:
		mission.refresh()
	hud.refresh()

func _refresh_markers() -> void:
	for n in npcs.values():
		n.refresh_marker()
	if hud:
		hud.refresh()

func _check_pre_cutscenes() -> void:
	for id in Game.active_quests():
		var q: Dictionary = DB.quests[id]
		if q.has("cutscene_pre") and not Game.has_flag("seen_" + q.cutscene_pre) and Game.objective_region(id) == region_id:
			Game.set_flag("seen_" + q.cutscene_pre)
			await play_cutscene(q.cutscene_pre)
			return

func play_cutscene(id: String) -> void:
	busy = true
	player.controls = false
	player.state = "cutscene"
	hud.set_prompt("")
	await StoryScript.play(self, id)
	player.state = "free"
	player.forced_pose = ""
	player.cutscene_move = Vector3.ZERO
	player.controls = true
	busy = false
	hud.refresh()

# ================================================================== talking & services
func talk_to(npc_id: String) -> void:
	if busy:
		return
	busy = true
	player.controls = false
	var n: NPC = npcs.get(npc_id)
	if n:
		n.talking = true
	var d: Dictionary = DB.npcs[npc_id]
	var handled := false
	for qid in Game.quests_to_turn_in(npc_id):
		var q: Dictionary = DB.quests[qid]
		await hud.say(_lines(q.get("outro", []), npc_id))
		Game.complete_quest(qid)
		handled = true
	for qid in Game.quests_offered_by(npc_id):
		var q: Dictionary = DB.quests[qid]
		var intro: Array = q.get("intro", [])
		var lines := _lines(intro, npc_id)
		lines.append([d.name, Game.fmt(q.summary)])
		var choice := await hud.say(lines, ["Accept: " + q.name, "Not now"])
		if choice == 0:
			Game.start_quest(qid)
		handled = true
		break
	if n:
		n.talking = false
	var role: String = d.role
	if role in ["guild", "inn", "canteen", "smith", "materia", "outfitter", "merchant", "recruiter", "job_master"]:
		if not handled:
			var greet: Array = d.get("lines", ["Well met, adventurer."])
			await hud.say([[d.name, Game.fmt(greet[randi() % greet.size()])]])
		busy = false
		player.controls = true
		await open_service(role, npc_id)
		return
	if not handled:
		var lines2: Array = d.get("lines", ["Fine weather for adventuring, isn't it?"])
		await hud.say([[d.name, Game.fmt(lines2[randi() % lines2.size()])]])
	busy = false
	player.controls = true
	_refresh_markers()

func _lines(raw: Array, giver: String) -> Array:
	var out := []
	for l in raw:
		var sp: String = l[0]
		var name := ""
		if sp == "@giver":
			name = DB.npcs[giver].name
		elif sp == "":
			name = ""
		else:
			var rid := Game.resolve(sp)
			name = DB.npcs[rid].name if DB.npcs.has(rid) else sp
		out.append([name, Game.fmt(l[1])])
	return out

func open_service(kind: String, npc_id: String) -> void:
	busy = true
	player.controls = false
	var menu := ServiceMenu.new()
	menu.world = self
	menu.kind = kind
	menu.npc_id = npc_id
	hud.add_child(menu)
	await menu.closed
	busy = false
	player.controls = true
	player.refresh_from_state()
	_refresh_markers()

func open_game_menu(tab := "") -> void:
	busy = true
	player.controls = false
	get_tree().paused = true
	var menu := GameMenu.new()
	menu.world = self
	menu.start_tab = tab
	hud.add_child(menu)
	await menu.closed
	get_tree().paused = false
	busy = false
	player.controls = true
	if is_instance_valid(player):
		player.refresh_from_state()
	_refresh_markers()

func _waystone_menu(id: String) -> void:
	if not Game.state.waystones.has(id):
		_attune(id)
	Game.state.last_waystone = id
	await open_service("waystone", id)

func _attune(id: String, silent := false) -> void:
	Game.state.waystones.append(id)
	Game.state.last_waystone = id
	if not silent:
		fx.vfx("heal", waystones[id].global_position + Vector3.UP, 4.0)
		hud.toast("Waystone attuned. You can now travel here.")

## Rest: heal, respawn monsters, save (inns & waystones).
func rest(at_inn := false) -> void:
	await hud.fade(1.0, 0.6)
	player.hp = player.max_hp
	player.stamina = player.max_stamina
	player.mp = player.max_mp
	Game.state.hp_ratio = 1.0
	for c in allies:
		c.hp = c.max_hp
		c.alive = true
	if at_inn:
		Game.state.time = fmod(float(Game.state.time) + 8.0, 24.0)
		Game.on_rest()
		Game.state.writ_board = {}
	for r in _respawns:
		spawn_monster(r[1], r[2])
	_respawns.clear()
	save_game()
	await hud.fade(0.0, 0.6)
	hud.toast("Rested. Progress saved.")

func travel(to: String, entry_from := "") -> void:
	if busy and entry_from == "":
		return
	busy = true
	player.controls = false
	await hud.fade(1.0, 0.5)
	write_runtime_state()
	Game.state.entry_from = region_id if entry_from == "" else entry_from
	Game.state.region = to
	Saves.save(Game.current_slot, Game.state)
	Game.goto_world()

func fast_travel(ws_id: String) -> void:
	for r in DB.regions:
		for ws in DB.regions[r].get("waystones", []):
			if ws.id == ws_id:
				busy = true
				await hud.fade(1.0, 0.5)
				write_runtime_state()
				Game.state.region = r
				var p: Vector3 = ws.pos
				Game.state.pos = [p.x + 3.0, 0.0, p.z + 3.0]
				if DB.regions[r].type == "city":
					Game.state.pos = [0.0, 0.0, 0.0]
				Game.state.last_waystone = ws_id
				Saves.save(Game.current_slot, Game.state)
				Game.goto_world()
				return

func write_runtime_state() -> void:
	if player:
		player.write_state()

## Save the current game (position included) to the active slot.
func save_game() -> bool:
	write_runtime_state()
	return Saves.save(Game.current_slot, Game.state)

# ================================================================== spawning helpers used by actors
func spawn_vfx(kind: String, pos: Vector3, size := 1.0, dir := Vector3.ZERO) -> void:
	fx.vfx(kind, pos, size, dir)

func spawn_projectile(src: Actor, pos: Vector3, dir: Vector3, p: Dictionary, info: Dictionary, targets: Array) -> void:
	fx.projectile(src, pos, dir, p, info, targets)

func spawn_aoe(src: Actor, at: Vector3, radius: float, info: Dictionary, targets: Array, kind: String) -> void:
	fx.aoe(src, at, radius, info, targets, kind)

func spawn_telegraph(shape: String, m: Dictionary) -> Telegraph:
	return fx.telegraph(shape, m)

func popup_number(pos: Vector3, value: int, col: Color) -> void:
	fx.number(pos, value, col)

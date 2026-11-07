class_name CityBuilder
extends RefCounted
## Builds a walled city procedurally: plaza, guild hall, inn, canteen, shops, job guild halls,
## houses, streets, walls with a gate, plus style extras (docks/ships, giant trees, domes & palms).
## All buildings of a city merge into a few meshes (walls / roofs / wood / trim) = few draw calls.
## Returns NPC spots by role and the waystone/board positions.

const STYLES := {
	"port": {"wall": Color("d9d2c4"), "wall2": Color("c8bfae"), "roof": Color("9a3b2a"), "roof2": Color("7d2f22"), "trim": Color("3a3f4a"), "pave": Color("9a958c"), "roof_kind": "gable"},
	"forest": {"wall": Color("8a6a48"), "wall2": Color("a5845e"), "roof": Color("3f5a2c"), "roof2": Color("5b6b34"), "trim": Color("3a2a1c"), "pave": Color("7d7462"), "roof_kind": "steep"},
	"desert": {"wall": Color("dcc29a"), "wall2": Color("e8d6b4"), "roof": Color("c9a24a"), "roof2": Color("2f6f8a"), "trim": Color("6b4a2e"), "pave": Color("c8b48e"), "roof_kind": "flat"},
}

var terrain: Terrain
var rd: Dictionary
var style: Dictionary
var kind := "port"
var ground := 0.0
var rng := RandomNumberGenerator.new()
var walls := MeshKit.begin()
var roofs := MeshKit.begin()
var wood := MeshKit.begin()
var trim := MeshKit.begin()
var body: StaticBody3D
var spots := {}
var footprints := []      # [center Vector3, radius]
var streets := []         # [a, b]
var signs := []           # [pos, text, rot]
var lamps := []
var gate_dir := Vector3.FORWARD
var center := Vector3.ZERO

func prepare(t: Terrain, region: Dictionary) -> void:
	terrain = t
	rd = region
	kind = rd.city
	style = STYLES[kind]
	rng.seed = int(rd.seed) * 7
	center = Vector3(25, 0, 0) if kind == "port" else Vector3.ZERO
	ground = terrain.height_at(center.x, center.z)
	ground = maxf(ground, terrain.water + 1.6)
	terrain.flatten(center, 98.0, ground, 25.0, 0.0, true)
	var e: Dictionary = rd.exits[0]
	var gp := terrain.exit_point(e, 0.0)
	gate_dir = (gp - center)
	gate_dir.y = 0
	gate_dir = gate_dir.normalized()
	# plaza + main street (paved)
	terrain.flatten(center, 22.0, ground, 3.0, 1.0)
	terrain.road([center + gate_dir * 20.0, center + gate_dir * 104.0, gp], 7.0, 1.0, true)
	streets.append([center, center + gate_dir * 110.0])

func build(parent: Node3D) -> Dictionary:
	body = StaticBody3D.new()
	body.name = "CityBody"
	parent.add_child(body)
	var ring1 := ["guild", "inn", "canteen", "smith", "materia", "outfitter", "merchant", "recruiter"]
	var base_ang := atan2(gate_dir.z, gate_dir.x)
	# key buildings around the plaza, leaving the gate side open
	for i in range(ring1.size()):
		var role: String = ring1[i]
		var a := base_ang + PI + (i - (ring1.size() - 1) / 2.0) * (TAU * 0.78 / ring1.size())
		var dist := 36.0 if role != "guild" else 40.0
		var p := center + Vector3(cos(a), 0, sin(a)) * dist
		var size := Vector3(14, 9, 12) if role == "guild" else Vector3(rng.randf_range(9, 11), rng.randf_range(6, 8), rng.randf_range(8, 10))
		_building(p, size, center, role)
		streets.append([center, p])
		terrain.road([center + (p - center).normalized() * 18.0, p], 5.0, 1.0, true)
	# job guild halls on an outer ring
	for i in range(4):
		var a := base_ang + PI * 0.5 + i * (PI / 3.0) + (PI / 6.0 if i >= 2 else 0.0)
		if i >= 2:
			a = base_ang - PI * 0.5 - (i - 2) * (PI / 3.0)
		var p := center + Vector3(cos(a), 0, sin(a)) * 68.0
		if terrain.is_water(p.x, p.z, -1.0):
			p = center + Vector3(cos(a), 0, sin(a)) * 50.0
		_building(p, Vector3(10, 8, 9), center, "job_master")
		streets.append([center, p])
		terrain.road([center + (p - center).normalized() * 40.0, p], 4.0, 1.0, true)
	# houses
	var tries := 0
	var houses := 0
	while houses < 55 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(48.0, 92.0)
		var p := center + Vector3(cos(a), 0, sin(a)) * r
		var sz := Vector3(rng.randf_range(6, 9), rng.randf_range(4.5, 7.5), rng.randf_range(6, 9))
		if not _free(p, sz.length() * 0.55 + 2.0) or terrain.is_water(p.x, p.z, -1.5) or _near_street(p, 6.5):
			continue
		_building(p, sz, center, "")
		houses += 1
	_walls()
	_plaza()
	match kind:
		"port": _docks(parent)
		"forest": _forest_extras(parent)
		"desert": _desert_extras(parent)
	_lamps(parent)
	_finish(parent)
	var ws := center + gate_dir * 12.0 - gate_dir.cross(Vector3.UP) * 13.0
	return {"spots": spots, "waystone": ws, "center": center}

func _free(p: Vector3, r: float) -> bool:
	if p.distance_to(center) < 30.0:
		return false
	for f in footprints:
		if Vector2(p.x - f[0].x, p.z - f[0].z).length() < r + float(f[1]):
			return false
	return true

func _near_street(p: Vector3, w: float) -> bool:
	for s in streets:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		if Vector2(p.x - q.x, p.z - q.z).length() < w:
			return true
	return false

func _building(p: Vector3, size: Vector3, face_to: Vector3, role: String) -> void:
	var y := terrain.height_at(p.x, p.z)
	var to := face_to - p
	to.y = 0
	var ang := atan2(-to.x, -to.z)
	var basis := Basis(Vector3.UP, ang)
	var c := Vector3(p.x, y, p.z)
	var wc: Color = style.wall if rng.randf() < 0.6 else style.wall2
	# foundation + walls
	MeshKit.box(walls, c + Vector3.UP * (size.y * 0.5 - 0.5), Vector3(size.x, size.y + 1.0, size.z), basis, wc)
	MeshKit.box(trim, c + Vector3.UP * 0.25, Vector3(size.x + 0.4, 0.8, size.z + 0.4), basis, Color(style.trim).lightened(0.2))
	# corner beams (forest/port)
	if kind != "desert":
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				MeshKit.box(wood, c + basis * Vector3(sx * size.x * 0.5, size.y * 0.5, sz * size.z * 0.5), Vector3(0.45, size.y, 0.45), basis, Color(style.trim))
	# door + windows on the front (-Z after rotation)
	var front := basis * Vector3(0, 0, -size.z * 0.5)
	var fwd := front.normalized()
	MeshKit.box(trim, c + front + fwd * 0.05 + Vector3.UP * 1.4, Vector3(2.0 if role != "guild" else 3.4, 2.8 if role != "guild" else 4.0, 0.25), basis, Color("2a1d14"))
	for wx in [-1.0, 1.0]:
		for wy in range(int(size.y / 3.2)):
			MeshKit.box(trim, c + front + fwd * 0.05 + basis * Vector3(wx * size.x * 0.3, 0, 0) + Vector3.UP * (2.2 + wy * 2.8), Vector3(1.2, 1.4, 0.2), basis, Color("1d2430"))
	_roof(c + Vector3.UP * size.y, size, basis)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size + Vector3(0.3, 2.0, 0.3)
	cs.shape = bs
	cs.transform = Transform3D(basis, c + Vector3.UP * size.y * 0.5)
	body.add_child(cs)
	footprints.append([c, size.length() * 0.5])
	if role != "":
		var spot := c + front + fwd * 2.2
		if not spots.has(role):
			spots[role] = []
		spots[role].append({"pos": spot, "rot": ang})
		if role == "guild":
			var bp := c + front + fwd * 2.0 + basis * Vector3(4.5, 0, 0)
			spots["writ_board"] = [{"pos": bp, "rot": ang}]
			MeshKit.box(wood, bp + Vector3.UP * 1.2, Vector3(2.4, 1.6, 0.2), basis, Color("6b4a2e"))
			MeshKit.box(wood, bp + Vector3.UP * 0.5, Vector3(0.2, 1.0, 0.2), basis, Color("4a3220"))
		var names := {"guild": "Adventurers' Guild", "inn": "Inn", "canteen": "Canteen", "smith": "Smithy", "materia": "Materia Workshop",
			"outfitter": "Armorer & Outfitter", "merchant": "Provisioner", "recruiter": "Party Registry", "job_master": "Job Guild"}
		signs.append([c + front + fwd * 0.4 + Vector3.UP * (3.4 if role != "guild" else 5.0), names.get(role, ""), ang])

func _roof(top: Vector3, size: Vector3, basis: Basis) -> void:
	var rc: Color = style.roof if rng.randf() < 0.7 else style.roof2
	var ov := 0.6
	var w := size.x * 0.5 + ov
	var d := size.z * 0.5 + ov
	match style.roof_kind:
		"gable", "steep":
			var h := size.x * (0.35 if style.roof_kind == "gable" else 0.6)
			var p := [Vector3(-w, 0, -d), Vector3(w, 0, -d), Vector3(w, 0, d), Vector3(-w, 0, d), Vector3(0, h, -d), Vector3(0, h, d)]
			for i in range(p.size()):
				p[i] = top + basis * p[i]
			_quad(roofs, p[0], p[4], p[5], p[3], rc)
			_quad(roofs, p[1], p[2], p[5], p[4], rc)
			_tri(walls, p[0], p[1], p[4], style.wall)
			_tri(walls, p[2], p[3], p[5], style.wall)
		"flat":
			MeshKit.box(roofs, top + Vector3.UP * 0.2, Vector3(size.x + 0.6, 0.4, size.z + 0.6), basis, Color(style.wall).darkened(0.1))
			for sx in [-1.0, 1.0]:
				MeshKit.box(walls, top + basis * Vector3(sx * size.x * 0.5, 0.7, 0), Vector3(0.4, 1.0, size.z + 0.6), basis, style.wall)
			if rng.randf() < 0.45:
				MeshKit.ellipsoid(roofs, top + Vector3.UP * 0.4, Vector3(size.x * 0.32, size.x * 0.3, size.x * 0.32), Basis(), 14, 8, func(dd: Vector3) -> bool: return dd.y > -0.05, rc)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)
	for v in [a, c, b]:
		st.set_color(col)
		st.set_normal(-n)
		st.add_vertex(v)

func _walls() -> void:
	var R := 102.0
	var segs := 28
	var gate_ang := atan2(gate_dir.z, gate_dir.x)
	for i in range(segs):
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var mid := (a0 + a1) * 0.5
		var p0 := center + Vector3(cos(a0), 0, sin(a0)) * R
		var p1 := center + Vector3(cos(a1), 0, sin(a1)) * R
		var pm := (p0 + p1) * 0.5
		if absf(wrapf(mid - gate_ang, -PI, PI)) < 0.16:
			# gate towers
			for p in [p0, p1]:
				_tower(p, 9.0)
			continue
		if terrain.is_water(pm.x, pm.z, 0.5) or not terrain.in_bounds(pm.x, pm.z, 2.0):
			continue
		var y := minf(terrain.height_at(p0.x, p0.z), terrain.height_at(p1.x, p1.z))
		var len := p0.distance_to(p1) + 0.6
		var ang := atan2(-(p1 - p0).x, -(p1 - p0).z)
		var b := Basis(Vector3.UP, ang)
		MeshKit.box(walls, Vector3(pm.x, y + 3.0, pm.z), Vector3(2.2, 9.0, len), b, Color(style.wall2).darkened(0.1))
		for k in range(4):
			var mp := p0.lerp(p1, (k + 0.5) / 4.0)
			MeshKit.box(walls, Vector3(mp.x, y + 8.0, mp.z), Vector3(2.4, 1.0, 1.2), b, Color(style.wall2).darkened(0.1))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.2, 14.0, len)
		cs.shape = bs
		cs.transform = Transform3D(b, Vector3(pm.x, y + 4.0, pm.z))
		body.add_child(cs)
		if i % 3 == 0:
			_tower(p0, 11.0)

func _tower(p: Vector3, h: float) -> void:
	var y := terrain.height_at(p.x, p.z)
	if y < terrain.water:
		return
	MeshKit.tube(walls, Vector3(p.x, y - 1.0, p.z), Vector3(p.x, y + h, p.z), 2.6, 2.4, 12, true, Vector2.ONE, Color(style.wall2).darkened(0.15))
	MeshKit.cone(roofs, Vector3(p.x, y + h, p.z), Vector3(p.x, y + h + 4.0, p.z), 3.1, 12, Vector2.ONE, style.roof)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.6
	cyl.height = h + 2.0
	cs.shape = cyl
	cs.position = Vector3(p.x, y + h * 0.5, p.z)
	body.add_child(cs)
	footprints.append([Vector3(p.x, y, p.z), 3.0])

func _plaza() -> void:
	var c := Vector3(center.x, ground, center.z)
	if kind == "forest":
		# great tree at the heart of the city
		MeshKit.tube(wood, c, c + Vector3.UP * 16.0, 2.4, 1.4, 14, false, Vector2.ONE, Color("5b4632"))
		for k in range(6):
			var a := TAU * k / 6.0
			MeshKit.tube(wood, c + Vector3.UP * 0.5, c + Vector3(cos(a) * 4.0, -0.5, sin(a) * 4.0), 1.0, 0.4, 8, false, Vector2.ONE, Color("5b4632"))
			MeshKit.tube(wood, c + Vector3.UP * 12.0, c + Vector3(cos(a) * 7.0, 18.0, sin(a) * 7.0), 0.7, 0.3, 8, false, Vector2.ONE, Color("5b4632"))
			MeshKit.ellipsoid(roofs, c + Vector3(cos(a) * 7.5, 19.0, sin(a) * 7.5), Vector3(6.0, 3.5, 6.0), Basis(), 12, 8, Callable(), Color("4f7a34"), 0.2)
		MeshKit.ellipsoid(roofs, c + Vector3.UP * 21.0, Vector3(8.0, 4.5, 8.0), Basis(), 14, 8, Callable(), Color("5b8a3a"), 0.2)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 2.6
		cyl.height = 16.0
		cs.shape = cyl
		cs.position = c + Vector3.UP * 8.0
		body.add_child(cs)
	else:
		# fountain
		MeshKit.tube(walls, c, c + Vector3.UP * 0.8, 5.0, 5.0, 24, true, Vector2.ONE, Color(style.wall2))
		MeshKit.tube(trim, c + Vector3.UP * 0.8, c + Vector3.UP * 0.85, 4.4, 4.4, 24, true, Vector2.ONE, Color("3f8fb0"))
		MeshKit.tube(walls, c, c + Vector3.UP * 3.0, 0.6, 0.4, 10, true, Vector2.ONE, Color(style.wall))
		MeshKit.ellipsoid(walls, c + Vector3.UP * 3.0, Vector3(1.4, 0.3, 1.4), Basis(), 12, 6, Callable(), Color(style.wall))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 5.0
		cyl.height = 2.0
		cs.shape = cyl
		cs.position = c + Vector3.UP * 0.5
		body.add_child(cs)
	footprints.append([c, 6.0])
	# market stalls
	for i in range(5):
		var a := atan2(gate_dir.z, gate_dir.x) + 0.6 + i * 0.25
		var p := c + Vector3(cos(a), 0, sin(a)) * 17.0
		var b := Basis(Vector3.UP, -a + PI / 2)
		var awn: Color = [Color("b23a3a"), Color("2e4f8c"), Color("c9a24a"), Color("3c7a4a"), Color("7d4ea8")][i]
		MeshKit.box(wood, p + Vector3.UP * 0.5, Vector3(2.6, 1.0, 1.4), b, Color("6b4a2e"))
		for sx in [-1.0, 1.0]:
			MeshKit.box(wood, p + b * Vector3(sx * 1.2, 1.3, 0.6), Vector3(0.12, 2.6, 0.12), b, Color("4a3220"))
		MeshKit.box(roofs, p + Vector3.UP * 2.6, Vector3(3.0, 0.12, 2.0), b, awn)

func _docks(parent: Node3D) -> void:
	var x0 := -60.0
	for i in range(4):
		var z := -60.0 + i * 40.0
		var p0 := Vector3(x0 + 4.0, 0, z)
		var p1 := Vector3(x0 - 34.0, 0, z)
		var y := terrain.water + 0.9
		MeshKit.box(wood, Vector3((p0.x + p1.x) * 0.5, y, z), Vector3(absf(p1.x - p0.x), 0.35, 4.0), Basis(), Color("7a5a3a"))
		for k in range(8):
			var px := lerpf(p0.x, p1.x, k / 7.0)
			for sz in [-1.8, 1.8]:
				MeshKit.tube(wood, Vector3(px, terrain.water - 4.0, z + sz), Vector3(px, y + 0.6, z + sz), 0.2, 0.2, 6, true, Vector2.ONE, Color("4a3220"))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(absf(p1.x - p0.x), 0.4, 4.0)
		cs.shape = bs
		cs.position = Vector3((p0.x + p1.x) * 0.5, y, z)
		body.add_child(cs)
		if i % 2 == 0:
			_ship(Vector3(x0 - 24.0, terrain.water, z + 12.0))

func _ship(p: Vector3) -> void:
	var hull := Color("5a3c24")
	MeshKit.ellipsoid(wood, p + Vector3(0, 0.3, 0), Vector3(11.0, 2.4, 3.2), Basis(), 18, 8, func(d: Vector3) -> bool: return d.y < 0.25, hull)
	MeshKit.box(wood, p + Vector3(0, 0.9, 0), Vector3(20.0, 0.3, 5.4), Basis(), Color("8a6a48"))
	for mx in [-4.0, 4.0]:
		MeshKit.tube(wood, p + Vector3(mx, 0.9, 0), p + Vector3(mx, 15.0, 0), 0.3, 0.2, 8, true, Vector2.ONE, Color("4a3220"))
		MeshKit.sheet(roofs, [p + Vector3(mx + 0.3, 13.5, -4.0), p + Vector3(mx + 0.3, 13.5, 4.0)], [p + Vector3(mx + 1.2, 5.0, -4.6), p + Vector3(mx + 1.2, 5.0, 4.6)], Color("ece4d2"))

func _forest_extras(parent: Node3D) -> void:
	var avoid := []
	for f in footprints:
		avoid.append([f[0], float(f[1]) + 3.0])
	for s in streets:
		for k in range(12):
			avoid.append([(s[0] as Vector3).lerp(s[1], k / 11.0), 6.0])
	var rd2 := rd.duplicate()
	rd2.seed = int(rd.seed) + 5
	Vegetation.populate(parent, terrain, rd2, avoid, 0.5)

func _desert_extras(parent: Node3D) -> void:
	var avoid := []
	for f in footprints:
		avoid.append([f[0], float(f[1]) + 3.0])
	for s in streets:
		for k in range(12):
			avoid.append([(s[0] as Vector3).lerp(s[1], k / 11.0), 6.0])
	var rd2 := rd.duplicate()
	rd2.seed = int(rd.seed) + 5
	Vegetation.populate(parent, terrain, rd2, avoid, 0.6)

func _lamps(parent: Node3D) -> void:
	var mat := MeshKit.pbr(Color("ffd9a0"), 0.3, 0.0, Color("ffb860"), 3.0)
	var st := MeshKit.begin()
	for s in streets:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var L := a.distance_to(b)
		var side := (b - a).cross(Vector3.UP).normalized()
		var k := 22.0
		while k < L - 4.0:
			var p := a.lerp(b, k / L) + side * 4.2
			p.y = terrain.height_at(p.x, p.z)
			if not terrain.is_water(p.x, p.z):
				MeshKit.tube(trim, p, p + Vector3.UP * 3.6, 0.09, 0.07, 6, true, Vector2.ONE, Color("2a2a30"))
				MeshKit.ellipsoid(st, p + Vector3.UP * 3.7, Vector3(0.22, 0.28, 0.22), Basis(), 8, 6)
				lamps.append(p + Vector3.UP * 3.7)
			k += 18.0
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "LampGlow"
	parent.add_child(mi)

func _finish(parent: Node3D) -> void:
	var defs := [[walls, MeshKit.vcol_pbr(0.88)], [roofs, MeshKit.vcol_pbr(0.62)], [wood, MeshKit.vcol_pbr(0.8)], [trim, MeshKit.vcol_pbr(0.7)]]
	for d in defs:
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.finish(d[0], d[1])
		parent.add_child(mi)
	for s in signs:
		if s[1] == "":
			continue
		var l := Label3D.new()
		l.text = s[1]
		l.font_size = 64
		l.pixel_size = 0.012
		l.outline_size = 12
		l.modulate = Color("f2e2b0")
		l.position = s[0]
		l.rotation.y = float(s[2]) + PI
		l.double_sided = true
		parent.add_child(l)

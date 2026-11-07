class_name PartsBuilder
extends RefCounted
## Procedural character parts. Head parts use head-space coordinates: origin = head centre,
## -Z = face direction, head radii ~ (0.088, 0.112, 0.1) at scale 1. Meshes are cached per id.

const HEAD_R := Vector3(0.088, 0.112, 0.1)
const HairShader := preload("res://shaders/hair.gdshader")

static var _cache := {}

static func _cached(key: String, builder: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]

# ------------------------------------------------------------------ hair
static func hair_material(base: Color, highlight: Color, use_hl: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HairShader
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("highlight_color", highlight)
	m.set_shader_parameter("highlight_amount", 0.65 if use_hl else 0.0)
	return m

static func hair_mesh(style: String) -> Mesh:
	return _cached("hair_" + style, func(): return _build_hair(style))

static func _cap(st: SurfaceTool, scale: float, front_cut: float, back_cut: float, side_cut := -1.0, extra_keep := Callable()) -> void:
	# A hair shell around the skull. front_cut: lowest y (unit sphere) kept on the face side,
	# back_cut: lowest y kept at the back/sides.
	var keep := func(d: Vector3) -> bool:
		if extra_keep.is_valid() and not extra_keep.call(d):
			return false
		var facing := -d.z  # 1 = front of face
		var limit := lerpf(back_cut, front_cut, clampf((facing - 0.1) / 0.6, 0.0, 1.0))
		if side_cut > -1.0 and absf(d.x) > 0.75 and d.y < side_cut:
			return false
		return d.y > limit
	MeshKit.ellipsoid(st, Vector3(0, 0.012, 0.006), HEAD_R * scale, Basis(), 22, 16, keep)

static func _build_hair(style: String) -> Mesh:
	var st := MeshKit.begin()
	match style:
		"crop":
			_cap(st, 1.1, 0.5, -0.35)
			_fringe(st, 0.0, 0.42, 0.55)
		"swept":
			_cap(st, 1.12, 0.5, -0.3)
			MeshKit.ellipsoid(st, Vector3(0.03, 0.06, -0.085), Vector3(0.075, 0.035, 0.03), Basis(Vector3.FORWARD, -0.45), 12, 8)
			MeshKit.ellipsoid(st, Vector3(-0.05, 0.02, -0.08), Vector3(0.035, 0.05, 0.025), Basis(Vector3.FORWARD, 0.3), 10, 8)
		"long":
			_cap(st, 1.12, 0.48, -0.45)
			_fringe(st, 0.0, 0.4, 0.6)
			_curtain(st, 0.28, 0.0, 0.04)
			for sx in [-1.0, 1.0]:
				MeshKit.chain(st, [Vector3(sx * 0.085, 0.0, -0.03), Vector3(sx * 0.095, -0.12, -0.02), Vector3(sx * 0.09, -0.24, 0.0)], [0.03, 0.025, 0.01], 8, Vector2(0.6, 1.0))
		"ponytail":
			_cap(st, 1.07, 0.55, -0.5)
			MeshKit.ellipsoid(st, Vector3(0, 0.07, 0.1), Vector3(0.025, 0.025, 0.025), Basis(), 8, 6)
			MeshKit.chain(st, [Vector3(0, 0.08, 0.11), Vector3(0, 0.07, 0.17), Vector3(0, -0.02, 0.2), Vector3(0, -0.14, 0.18), Vector3(0, -0.24, 0.15)], [0.035, 0.045, 0.04, 0.03, 0.008], 10)
		"twintails":
			_cap(st, 1.08, 0.5, -0.45)
			_fringe(st, 0.0, 0.42, 0.5)
			for sx in [-1.0, 1.0]:
				MeshKit.chain(st, [Vector3(sx * 0.09, 0.07, 0.03), Vector3(sx * 0.14, 0.05, 0.05), Vector3(sx * 0.16, -0.06, 0.05), Vector3(sx * 0.15, -0.2, 0.04), Vector3(sx * 0.13, -0.32, 0.03)], [0.025, 0.04, 0.04, 0.03, 0.006], 10)
		"bob":
			_cap(st, 1.16, 0.42, -0.62, -1.0)
			_fringe(st, 0.0, 0.38, 0.62)
		"spiky":
			_cap(st, 1.1, 0.5, -0.3)
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			for i in range(16):
				var th := rng.randf() * TAU
				var ph := rng.randf_range(0.1, 1.2)
				var d := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
				if d.z < -0.6 and d.y < 0.6:
					continue
				var base := d * HEAD_R * 1.05 + Vector3(0, 0.012, 0)
				MeshKit.cone(st, base, base + (d + Vector3(0, 0.3, 0.25)).normalized() * rng.randf_range(0.06, 0.1), 0.028, 6)
		"braid":
			_cap(st, 1.07, 0.52, -0.5)
			var pts := []
			var rad := []
			for i in range(9):
				pts.append(Vector3(sin(i * 1.7) * 0.012, -0.02 - i * 0.045, 0.11 + 0.01 * i))
				rad.append(0.03 - i * 0.0022)
			MeshKit.chain(st, pts, rad, 8)
		"topknot":
			_cap(st, 1.06, 0.55, -0.4)
			MeshKit.ellipsoid(st, Vector3(0, 0.135, 0.03), Vector3(0.042, 0.038, 0.042), Basis(), 12, 8)
		"buzz":
			_cap(st, 1.03, 0.55, -0.35)
		"wavy":
			_cap(st, 1.14, 0.45, -0.55)
			_fringe(st, 0.01, 0.4, 0.55)
			for i in range(7):
				var th := lerpf(0.15, PI - 0.15, i / 6.0)
				var x := cos(th) * 0.1
				var z := sin(th) * 0.09 + 0.01
				MeshKit.chain(st, [Vector3(x, -0.02, z), Vector3(x * 1.12, -0.1, z * 1.1 + 0.01), Vector3(x * 1.05, -0.18, z * 1.15), Vector3(x * 1.15, -0.25, z * 1.1)], [0.03, 0.032, 0.026, 0.01], 8)
		"undercut":
			_cap(st, 1.12, 0.48, -0.3, -1.0, func(d: Vector3) -> bool: return not (d.x < -0.55 and d.y < 0.55))
			_cap(st, 1.015, 0.6, -0.3)
			MeshKit.ellipsoid(st, Vector3(0.03, 0.065, -0.07), Vector3(0.07, 0.04, 0.04), Basis(Vector3.FORWARD, -0.35), 12, 8)
		"bun":
			_cap(st, 1.07, 0.5, -0.45)
			_fringe(st, 0.0, 0.42, 0.5)
			MeshKit.ellipsoid(st, Vector3(0, -0.04, 0.115), Vector3(0.045, 0.042, 0.035), Basis(), 12, 8)
		"mohawk":
			_cap(st, 1.015, 0.6, -0.35)
			for i in range(9):
				var a := lerpf(-1.1, 1.9, i / 8.0)
				var d := Vector3(0, cos(a), -sin(a))
				var base := d * HEAD_R * 1.02 + Vector3(0, 0.012, 0)
				MeshKit.cone(st, base, base + d * 0.075 + Vector3(0, 0, 0.02), 0.03, 6, Vector2(0.35, 1.0))
		_:
			_cap(st, 1.1, 0.5, -0.35)
	return MeshKit.finish(st)

static func _fringe(st: SurfaceTool, x_off: float, y: float, width: float) -> void:
	# a soft fringe hanging over the forehead
	for i in range(5):
		var t := (i - 2) / 2.0
		var x := x_off + t * 0.05 * width / 0.55
		MeshKit.ellipsoid(st, Vector3(x, 0.055 - absf(t) * 0.01, -0.092 + absf(t) * 0.012), Vector3(0.024, 0.04, 0.016), Basis(Vector3.FORWARD, t * 0.25), 8, 6)

static func _curtain(st: SurfaceTool, length: float, x_off: float, depth: float) -> void:
	var top := []
	var bot := []
	for i in range(9):
		var th := lerpf(0.1, PI - 0.1, i / 8.0)
		var x := cos(th) * 0.1
		var z := sin(th) * 0.1 + depth
		top.append(Vector3(x + x_off, 0.0, z))
		bot.append(Vector3(x * 1.25 + x_off, -length, z + 0.03))
	MeshKit.sheet(st, top, bot)
	for i in range(8):
		var p: Vector3 = (top[i] + top[i + 1]) * 0.5
		MeshKit.chain(st, [p, p + Vector3(p.x * 0.1, -length * 0.5, 0.02), p + Vector3(p.x * 0.25, -length, 0.03)], [0.022, 0.02, 0.008], 6)

# ------------------------------------------------------------------ eyes / brows / human ears
static func eye_meshes() -> Array:
	var sclera := _cached("sclera", func():
		var st := MeshKit.begin()
		MeshKit.ellipsoid(st, Vector3.ZERO, Vector3(0.0165, 0.0135, 0.012), Basis(), 12, 8)
		return MeshKit.finish(st))
	var iris := _cached("iris", func():
		var st := MeshKit.begin()
		MeshKit.ellipsoid(st, Vector3.ZERO, Vector3(0.0085, 0.0085, 0.003), Basis(), 12, 6)
		return MeshKit.finish(st))
	var pupil := _cached("pupil", func():
		var st := MeshKit.begin()
		MeshKit.ellipsoid(st, Vector3.ZERO, Vector3(0.0038, 0.0042, 0.0015), Basis(), 8, 4)
		return MeshKit.finish(st))
	return [sclera, iris, pupil]

static func brow_mesh() -> Mesh:
	return _cached("brow", func():
		var st := MeshKit.begin()
		MeshKit.tube(st, Vector3(-0.012, 0.0, 0), Vector3(0.016, 0.004, 0.003), 0.0035, 0.002, 6, true, Vector2(1.0, 0.5))
		return MeshKit.finish(st))

static func human_ear_mesh() -> Mesh:
	return _cached("ear_human", func():
		var st := MeshKit.begin()
		MeshKit.ellipsoid(st, Vector3.ZERO, Vector3(0.012, 0.026, 0.018), Basis(), 8, 6)
		return MeshKit.finish(st))

# ------------------------------------------------------------------ race features (head space)
## Returns [mesh, uses_hair_color] for a race ear style, or [] for none.
static func race_ears(style: String) -> Array:
	match style:
		"human": return []
		"long", "swept", "short_pointed", "small_pointed":
			var m := _cached("ears_" + style, func():
				var st := MeshKit.begin()
				var L: float = {"long": 0.11, "swept": 0.09, "short_pointed": 0.05, "small_pointed": 0.05}[style]
				var up: float = {"long": 0.03, "swept": 0.07, "short_pointed": 0.02, "small_pointed": 0.0}[style]
				for sx in [-1.0, 1.0]:
					var a := Vector3(sx * 0.084, -0.005, 0.01)
					MeshKit.tube(st, a, a + Vector3(sx * L, up + 0.02, L * 0.35), 0.024, 0.002, 8, true, Vector2(1.0, 0.35))
				return MeshKit.finish(st))
			return [m, false]
		"cat", "cat_tufted", "cat_folded":
			var m := _cached("ears_" + style, func():
				var st := MeshKit.begin()
				for sx in [-1.0, 1.0]:
					var base := Vector3(sx * 0.055, 0.095, 0.0)
					var tip := base + Vector3(sx * 0.03, 0.075, 0.005)
					if style == "cat_folded":
						tip = base + Vector3(sx * 0.045, 0.035, -0.03)
					MeshKit.cone(st, base, tip, 0.032, 6, Vector2(1.0, 0.45))
					if style == "cat_tufted":
						MeshKit.cone(st, tip - (tip - base) * 0.1, tip + Vector3(0, 0.025, 0), 0.008, 4)
				return MeshKit.finish(st))
			return [m, true]
		"wolf", "wolf_tall":
			var m := _cached("ears_" + style, func():
				var st := MeshKit.begin()
				var h := 0.09 if style == "wolf" else 0.12
				for sx in [-1.0, 1.0]:
					var base := Vector3(sx * 0.06, 0.09, 0.01)
					MeshKit.cone(st, base, base + Vector3(sx * 0.035, h, 0.01), 0.036, 6, Vector2(1.0, 0.5))
				return MeshKit.finish(st))
			return [m, true]
		"rabbit", "rabbit_lop", "rabbit_short":
			var m := _cached("ears_" + style, func():
				var st := MeshKit.begin()
				for sx in [-1.0, 1.0]:
					var b := Vector3(sx * 0.035, 0.1, 0.01)
					var pts := [b, b + Vector3(sx * 0.01, 0.1, 0.02), b + Vector3(sx * 0.02, 0.2, 0.035), b + Vector3(sx * 0.025, 0.25, 0.04)]
					if style == "rabbit_lop":
						pts = [b, b + Vector3(sx * 0.05, 0.03, 0.01), b + Vector3(sx * 0.09, -0.06, 0.0), b + Vector3(sx * 0.095, -0.14, -0.01)]
					elif style == "rabbit_short":
						pts = [b, b + Vector3(sx * 0.01, 0.07, 0.015), b + Vector3(sx * 0.015, 0.12, 0.02)]
					var rr := [0.022, 0.03, 0.026, 0.006] if pts.size() == 4 else [0.022, 0.028, 0.008]
					MeshKit.chain(st, pts, rr, 8, Vector2(1.0, 0.4), Color.WHITE, false)
				return MeshKit.finish(st))
			return [m, true]
		"fin":
			var m := _cached("ears_fin", func():
				var st := MeshKit.begin()
				for sx in [-1.0, 1.0]:
					var a := Vector3(sx * 0.085, 0.0, 0.0)
					MeshKit.sheet(st, [a, a + Vector3(sx * 0.01, 0.0, 0.07)], [a + Vector3(sx * 0.04, 0.03, 0.01), a + Vector3(sx * 0.03, 0.05, 0.09)])
				return MeshKit.finish(st))
			return [m, false]
	return []

static func horn_mesh(style: String) -> Mesh:
	return _cached("horn_" + style, func():
		var st := MeshKit.begin()
		for sx in [-1.0, 1.0]:
			match style:
				"swept":
					MeshKit.chain(st, [Vector3(sx * 0.06, 0.07, -0.06), Vector3(sx * 0.08, 0.1, 0.0), Vector3(sx * 0.09, 0.11, 0.08), Vector3(sx * 0.09, 0.1, 0.15)], [0.018, 0.014, 0.009, 0.001], 7, Vector2.ONE, Color.WHITE, false)
				"crown":
					for k in range(3):
						var b := Vector3(sx * (0.03 + k * 0.025), 0.1 - k * 0.012, -0.02 + k * 0.03)
						MeshKit.cone(st, b, b + Vector3(sx * 0.01, 0.06 - k * 0.012, 0.02), 0.01, 6)
				"curled":
					var pts := []
					var rr := []
					for k in range(7):
						var a := k * 0.7
						pts.append(Vector3(sx * (0.08 + 0.02 * k), 0.07 + sin(a) * 0.03, cos(a) * 0.035 + 0.01 * k))
						rr.append(0.02 - k * 0.0028)
					MeshKit.chain(st, pts, rr, 7)
				_:
					MeshKit.cone(st, Vector3(sx * 0.05, 0.08, -0.05), Vector3(sx * 0.07, 0.16, -0.02), 0.016, 6)
		return MeshKit.finish(st))

## Tail in hips-bone space (origin at hips joint, +Z = behind).
static func tail_mesh(style: String, length: float) -> Mesh:
	var key := "tail_%s_%d" % [style, int(length * 10)]
	return _cached(key, func():
		var st := MeshKit.begin()
		var L := lerpf(0.7, 1.3, length)
		match style:
			"cat_long":
				MeshKit.chain(st, [Vector3(0, -0.02, 0.09), Vector3(0, -0.1 * L, 0.2 * L), Vector3(0, -0.22 * L, 0.32 * L), Vector3(0, -0.26 * L, 0.46 * L), Vector3(0, -0.2 * L, 0.6 * L)], [0.02, 0.018, 0.016, 0.014, 0.008], 8)
			"cat_short":
				MeshKit.chain(st, [Vector3(0, -0.02, 0.09), Vector3(0, -0.08 * L, 0.18 * L), Vector3(0, -0.14 * L, 0.26 * L)], [0.02, 0.018, 0.01], 8)
			"dragon":
				MeshKit.chain(st, [Vector3(0, -0.04, 0.08), Vector3(0, -0.2 * L, 0.2 * L), Vector3(0, -0.42 * L, 0.34 * L), Vector3(0, -0.6 * L, 0.42 * L), Vector3(0, -0.72 * L, 0.5 * L)], [0.06, 0.05, 0.036, 0.022, 0.004], 10)
			"wolf":
				MeshKit.chain(st, [Vector3(0, -0.03, 0.09), Vector3(0, -0.12 * L, 0.18 * L), Vector3(0, -0.3 * L, 0.25 * L), Vector3(0, -0.45 * L, 0.26 * L)], [0.03, 0.06, 0.055, 0.015], 10)
		return MeshKit.finish(st))

# ------------------------------------------------------------------ weapons
const TIER_COLORS := [Color("8c6a46"), Color("8a8d91"), Color("b8bec7"), Color("9fc4e6"), Color("3d3f4a"), Color("f0d27a")]

static func metal_mat(tier: int) -> StandardMaterial3D:
	var t := clampi(tier, 0, 5)
	var m := MeshKit.pbr(TIER_COLORS[t], [0.55, 0.42, 0.28, 0.2, 0.3, 0.18][t], 0.92)
	if t == 5:
		m.emission_enabled = true
		m.emission = Color("ffd98a")
		m.emission_energy_multiplier = 0.6
	elif t == 3:
		m.emission_enabled = true
		m.emission = Color("7fc8ff")
		m.emission_energy_multiplier = 0.15
	return m

static var _wood_mat: StandardMaterial3D
static var _grip_mat: StandardMaterial3D

static func wood_mat() -> StandardMaterial3D:
	if not _wood_mat:
		_wood_mat = MeshKit.pbr(Color("5a3c24"), 0.75, 0.0)
	return _wood_mat

static func grip_mat() -> StandardMaterial3D:
	if not _grip_mat:
		_grip_mat = MeshKit.pbr(Color("2e2118"), 0.85, 0.0)
	return _grip_mat

## Builds weapon nodes. Returns {"right": Node3D, "left": Node3D (or null)}.
## Hand space: grip at origin, blades extend along -Z ("grip axis"), +X runs along the forearm.
static func weapon(kind: String, tier: int) -> Dictionary:
	var metal := metal_mat(tier)
	var out := {"right": null, "left": null}
	match kind:
		"sword_shield":
			out.right = _blade(0.85, 0.045, 0.012, metal, true)
			out.left = _shield(metal)
		"greatsword":
			out.right = _blade(1.45, 0.11, 0.02, metal, true, 0.3)
		"katana":
			out.right = _blade(1.0, 0.035, 0.01, metal, true, 0.24, 0.06)
		"greataxe":
			out.right = _axe(metal)
		"scythe":
			out.right = _scythe(metal)
		"lance":
			out.right = _lance(metal)
		"daggers":
			out.right = _blade(0.32, 0.03, 0.008, metal, true, 0.1)
			out.left = _blade(0.32, 0.03, 0.008, metal, true, 0.1)
		"fists":
			out.right = _knuckle(metal)
			out.left = _knuckle(metal)
		"bow":
			out.left = _bow(metal)
		"gun":
			out.right = _gun(metal)
		"staff":
			out.right = _staff(metal, Color("ff7a3a"))
		"cane":
			out.right = _staff(metal, Color("fff2b0"), 0.9)
	return out

static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

static func _blade(length: float, width: float, thick: float, metal: Material, guard: bool, handle := 0.18, curve := 0.0) -> Node3D:
	var n := Node3D.new()
	var st := MeshKit.begin()
	var segs := 6
	for i in range(segs):
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var y0 := curve * t0 * t0
		var y1 := curve * t1 * t1
		var w0 := width * (1.0 - t0 * 0.35)
		var w1 := width * (1.0 - t1 * 0.35) if i < segs - 1 else 0.001
		MeshKit.tube(st, Vector3(0, y0, -0.06 - t0 * length), Vector3(0, y1, -0.06 - t1 * length), 1.0, 1.0, 4, false, Vector2(w0 if i < segs else w1, thick))
		if i == segs - 1:
			MeshKit.cone(st, Vector3(0, y0, -0.06 - t0 * length), Vector3(0, y1 + 0.01, -0.06 - length - width * 1.2), 1.0, 4, Vector2(w0, thick))
	n.add_child(_mi(MeshKit.finish(st), metal))
	var st2 := MeshKit.begin()
	MeshKit.tube(st2, Vector3(0, 0, handle * 0.5), Vector3(0, 0, -0.05), 0.016, 0.016, 8)
	if guard:
		MeshKit.box(st2, Vector3(0, 0, -0.055), Vector3(0.025, width * 3.2 + 0.05, 0.025))
	MeshKit.ellipsoid(st2, Vector3(0, 0, handle * 0.5 + 0.015), Vector3.ONE * 0.022, Basis(), 8, 6)
	n.add_child(_mi(MeshKit.finish(st2), grip_mat()))
	return n

static func _shield(metal: Material) -> Node3D:
	# Shield face lies in the hand's XZ plane and faces +Y (back of the hand).
	var n := Node3D.new()
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3(0.02, 0.06, 0.0), Vector3(0.26, 0.04, 0.32), Basis(), 16, 8)
	n.add_child(_mi(MeshKit.finish(st), metal))
	var st2 := MeshKit.begin()
	MeshKit.ellipsoid(st2, Vector3(0.02, 0.1, 0.0), Vector3(0.06, 0.03, 0.06), Basis(), 10, 6)
	n.add_child(_mi(MeshKit.finish(st2), MeshKit.pbr(Color("c9a24a"), 0.3, 1.0)))
	return n

static func _axe(metal: Material) -> Node3D:
	var n := Node3D.new()
	var st := MeshKit.begin()
	MeshKit.tube(st, Vector3(0, 0, 0.35), Vector3(0, 0, -1.05), 0.022, 0.02, 8)
	n.add_child(_mi(MeshKit.finish(st), wood_mat()))
	var st2 := MeshKit.begin()
	for sy in [-1.0, 1.0]:
		MeshKit.sheet(st2, [Vector3(0, 0, -0.75), Vector3(0, 0, -1.05)], [Vector3(0, sy * 0.3, -0.62), Vector3(0, sy * 0.32, -1.16)])
		MeshKit.box(st2, Vector3(0, sy * 0.15, -0.9), Vector3(0.03, 0.3, 0.28))
	n.add_child(_mi(MeshKit.finish(st2), metal))
	return n

static func _scythe(metal: Material) -> Node3D:
	var n := Node3D.new()
	var st := MeshKit.begin()
	MeshKit.tube(st, Vector3(0, 0, 0.55), Vector3(0, 0, -1.2), 0.02, 0.02, 8)
	n.add_child(_mi(MeshKit.finish(st), wood_mat()))
	var st2 := MeshKit.begin()
	var a := []
	var b := []
	for i in range(8):
		var t := i / 7.0
		var p := Vector3(0, 0.05 + t * 0.85, -1.15 + sin(t * 1.4) * 0.35)
		a.append(p)
		b.append(p + Vector3(0, 0, -0.14 * (1.0 - t)))
	MeshKit.sheet(st2, a, b)
	n.add_child(_mi(MeshKit.finish(st2), metal))
	return n

static func _lance(metal: Material) -> Node3D:
	# Lance points along the forearm (+X) so thrusts follow the arm.
	var n := Node3D.new()
	var st := MeshKit.begin()
	MeshKit.tube(st, Vector3(-0.6, 0, 0), Vector3(1.4, 0, 0), 0.022, 0.02, 8)
	n.add_child(_mi(MeshKit.finish(st), wood_mat()))
	var st2 := MeshKit.begin()
	MeshKit.cone(st2, Vector3(1.4, 0, 0), Vector3(1.85, 0, 0), 0.06, 6, Vector2(1.0, 0.3))
	MeshKit.tube(st2, Vector3(1.33, 0, 0), Vector3(1.42, 0, 0), 0.04, 0.04, 8)
	n.add_child(_mi(MeshKit.finish(st2), metal))
	return n

static func _knuckle(metal: Material) -> Node3D:
	var n := Node3D.new()
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3(0.08, 0.0, 0.0), Vector3(0.055, 0.035, 0.05), Basis(), 10, 6)
	MeshKit.tube(st, Vector3(-0.08, 0, 0), Vector3(0.03, 0, 0), 0.045, 0.05, 10)
	n.add_child(_mi(MeshKit.finish(st), metal))
	return n

static func _bow(metal: Material) -> Node3D:
	var n := Node3D.new()
	var st := MeshKit.begin()
	var pts := []
	var rr := []
	for i in range(9):
		var t := (i - 4) / 4.0
		pts.append(Vector3(0.02, 0, 0) + Vector3(-0.12 * (1.0 - t * t) + 0.04 * absf(t) * absf(t) * absf(t), 0, t * 0.7))
		rr.append(0.018 - absf(t) * 0.009)
	MeshKit.chain(st, pts, rr, 6)
	n.add_child(_mi(MeshKit.finish(st), wood_mat()))
	var st2 := MeshKit.begin()
	MeshKit.tube(st2, pts[0], pts[8], 0.003, 0.003, 4)
	n.add_child(_mi(MeshKit.finish(st2), MeshKit.pbr(Color("e8e0d0"), 0.6)))
	var st3 := MeshKit.begin()
	MeshKit.tube(st3, Vector3(0.0, 0, 0.06), Vector3(0.0, 0, -0.06), 0.022, 0.022, 8)
	n.add_child(_mi(MeshKit.finish(st3), metal))
	return n

static func _gun(metal: Material) -> Node3D:
	# Rifle barrel runs along the forearm (+X).
	var n := Node3D.new()
	var st := MeshKit.begin()
	MeshKit.tube(st, Vector3(0.05, 0.03, 0), Vector3(0.95, 0.03, 0), 0.02, 0.018, 8)
	MeshKit.box(st, Vector3(0.12, 0.02, 0), Vector3(0.18, 0.06, 0.045))
	n.add_child(_mi(MeshKit.finish(st), metal))
	var st2 := MeshKit.begin()
	MeshKit.box(st2, Vector3(-0.15, -0.0, 0), Vector3(0.36, 0.07, 0.05), Basis(Vector3.BACK, 0.15))
	MeshKit.box(st2, Vector3(0.0, -0.05, 0), Vector3(0.05, 0.1, 0.04))
	MeshKit.box(st2, Vector3(0.4, 0.0, 0), Vector3(0.5, 0.04, 0.05))
	n.add_child(_mi(MeshKit.finish(st2), wood_mat()))
	return n

static func _staff(metal: Material, gem: Color, length := 1.4) -> Node3D:
	var n := Node3D.new()
	var st := MeshKit.begin()
	MeshKit.tube(st, Vector3(0, 0, 0.45 * length), Vector3(0, 0, -0.85 * length), 0.02, 0.024, 8)
	n.add_child(_mi(MeshKit.finish(st), wood_mat()))
	var st2 := MeshKit.begin()
	var top := Vector3(0, 0, -0.85 * length)
	for k in range(4):
		var a := k * TAU / 4.0
		MeshKit.chain(st2, [top, top + Vector3(cos(a) * 0.06, sin(a) * 0.06, -0.08), top + Vector3(cos(a) * 0.03, sin(a) * 0.03, -0.2)], [0.012, 0.01, 0.003], 5, Vector2.ONE, Color.WHITE, false)
	n.add_child(_mi(MeshKit.finish(st2), metal))
	var st3 := MeshKit.begin()
	MeshKit.ellipsoid(st3, top + Vector3(0, 0, -0.12), Vector3(0.045, 0.045, 0.06), Basis(), 10, 6)
	var gm := MeshKit.pbr(gem, 0.1, 0.0, gem, 2.5)
	n.add_child(_mi(MeshKit.finish(st3), gm))
	return n

# ------------------------------------------------------------------ armor pieces (bone space)
static func armor_piece(kind: String) -> Mesh:
	return _cached("armor_" + kind, func():
		var st := MeshKit.begin()
		match kind:
			"belt":
				MeshKit.tube(st, Vector3(0, -0.025, 0), Vector3(0, 0.025, 0), 1.0, 1.0, 16, false, Vector2(0.14, 0.105))
				MeshKit.box(st, Vector3(0, 0, -0.105), Vector3(0.05, 0.045, 0.015))
			"bracer":
				MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0.14, 0, 0), 0.042, 0.034, 10)
			"pauldron_light":
				MeshKit.ellipsoid(st, Vector3(0, 0.02, 0), Vector3(0.075, 0.05, 0.075), Basis(), 12, 8, func(d: Vector3) -> bool: return d.y > -0.1)
			"pauldron_heavy":
				MeshKit.ellipsoid(st, Vector3(0, 0.03, 0), Vector3(0.1, 0.065, 0.095), Basis(), 12, 8, func(d: Vector3) -> bool: return d.y > -0.2)
				MeshKit.ellipsoid(st, Vector3(0, -0.01, 0), Vector3(0.09, 0.05, 0.085), Basis(), 12, 8, func(d: Vector3) -> bool: return d.y > 0.0)
			"mantle":
				MeshKit.ellipsoid(st, Vector3(0, 0.0, 0.0), Vector3(0.21, 0.09, 0.15), Basis(), 18, 8, func(d: Vector3) -> bool: return d.y > 0.0)
			"cape":
				var top := []
				var bot := []
				for i in range(7):
					var t := (i - 3) / 3.0
					top.append(Vector3(t * 0.17, 0.0, 0.1 - absf(t) * 0.03))
					bot.append(Vector3(t * 0.3, -0.95, 0.24))
				MeshKit.sheet(st, top, bot)
			"coat_tails":
				var top := []
				var bot := []
				for i in range(7):
					var t := (i - 3) / 3.0
					var a := t * 2.2
					top.append(Vector3(sin(a) * 0.145, 0.0, cos(a) * 0.11))
					bot.append(Vector3(sin(a) * 0.2, -0.55, cos(a) * 0.17))
				MeshKit.sheet(st, top, bot)
			"sash":
				MeshKit.tube(st, Vector3(0, -0.04, 0), Vector3(0, 0.04, 0), 1.0, 1.0, 16, false, Vector2(0.145, 0.11))
				MeshKit.sheet(st, [Vector3(0.06, 0, -0.1), Vector3(0.09, -0.35, -0.12)], [Vector3(0.12, 0, -0.08), Vector3(0.15, -0.33, -0.1)])
		return MeshKit.finish(st))

# ------------------------------------------------------------------ placeholder headwear (head space)
static func headwear(kind: String) -> Mesh:
	return _cached("head_" + kind, func():
		var st := MeshKit.begin()
		match kind:
			"helm":
				MeshKit.ellipsoid(st, Vector3(0, 0.02, 0.005), HEAD_R * 1.2, Basis(), 18, 12, func(d: Vector3) -> bool: return d.y > -0.25 and not (d.z < -0.55 and d.y < 0.35 and d.y > -0.25))
				MeshKit.box(st, Vector3(0, 0.03, -0.112), Vector3(0.02, 0.09, 0.02))
			"hood":
				MeshKit.ellipsoid(st, Vector3(0, 0.02, 0.012), HEAD_R * 1.24, Basis(), 18, 12, func(d: Vector3) -> bool: return d.z > -0.45 or d.y > 0.55)
				MeshKit.cone(st, Vector3(0, 0.06, 0.1), Vector3(0, -0.02, 0.24), 0.07, 8)
			"hat":
				MeshKit.tube(st, Vector3(0, 0.07, 0), Vector3(0, 0.08, 0), 0.19, 0.19, 20, true)
				MeshKit.tube(st, Vector3(0, 0.07, 0), Vector3(0, 0.2, 0.01), 0.1, 0.075, 16, true)
			"cap":
				MeshKit.ellipsoid(st, Vector3(0, 0.035, 0.005), HEAD_R * 1.12, Basis(), 16, 10, func(d: Vector3) -> bool: return d.y > 0.25)
				MeshKit.box(st, Vector3(0, 0.06, -0.11), Vector3(0.12, 0.012, 0.06))
			"turban":
				MeshKit.ellipsoid(st, Vector3(0, 0.05, 0.0), Vector3(0.105, 0.09, 0.115), Basis(), 16, 10, func(d: Vector3) -> bool: return d.y > -0.3)
				MeshKit.tube(st, Vector3(0, 0.0, 0), Vector3(0, 0.05, 0), 1.0, 1.0, 18, false, Vector2(0.105, 0.115))
			"bandana":
				MeshKit.ellipsoid(st, Vector3(0, 0.02, 0.005), HEAD_R * 1.08, Basis(), 16, 10, func(d: Vector3) -> bool: return d.y > 0.1)
				MeshKit.cone(st, Vector3(0, 0.04, 0.1), Vector3(0.02, -0.06, 0.16), 0.03, 6)
			"circlet":
				MeshKit.tube(st, Vector3(0, 0.035, 0), Vector3(0, 0.05, 0), 1.0, 1.0, 20, false, Vector2(0.095, 0.105))
				MeshKit.ellipsoid(st, Vector3(0, 0.045, -0.106), Vector3(0.014, 0.018, 0.008), Basis(), 8, 6)
		return MeshKit.finish(st))

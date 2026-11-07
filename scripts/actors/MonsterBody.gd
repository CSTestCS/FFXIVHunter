class_name MonsterBody
extends Node3D
## Procedural creature visuals + animation. Each body plan is built from MeshKit primitives into a
## handful of meshes (one per moving part) sharing one vertex-coloured PBR material.
## Faces -Z. Animation is driven by MonsterAI through animate().

var kind := "quadruped"
var c1 := Color.GRAY
var c2 := Color.WHITE
var mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var root: Node3D
var body: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var leg_phase: Array[float] = []
var tail: Node3D
var wings: Array[Node3D] = []
var segments: Array[Node3D] = []
var claws: Array[Node3D] = []
var glow: MeshInstance3D
var light: OmniLight3D
var t := 0.0
var walk := 0.0
var base_y := 0.0
var size := 1.0

func build(p_kind: String, colors: Array, scale_f: float) -> void:
	kind = p_kind
	c1 = Color(colors[0])
	c2 = Color(colors[1])
	size = scale_f
	mat = MeshKit.vcol_pbr(0.72, 0.0)
	eye_mat = MeshKit.pbr(Color("ffd36a"), 0.2, 0.0, Color("ffb030"), 2.0)
	root = Node3D.new()
	add_child(root)
	root.scale = Vector3.ONE * scale_f
	match kind:
		"quadruped", "quadruped_heavy", "hopper": _quadruped()
		"crab": _crab()
		"toad": _toad()
		"serpent": _serpent()
		"wyvern": _wyvern()
		"worm": _worm()
		"golem": _golem()
		"wisp": _wisp()
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = 160.0 * maxf(1.0, scale_f)

func _mesh(parent: Node3D, st: SurfaceTool, m: Material = null, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = m if m else mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _eyes(parent: Node3D, pos: Vector3, sep: float, r: float) -> void:
	var st := MeshKit.begin()
	for sx in [-1.0, 1.0]:
		MeshKit.ellipsoid(st, pos + Vector3(sx * sep, 0, 0), Vector3.ONE * r, Basis(), 8, 6)
	_mesh(parent, st, eye_mat)

# ------------------------------------------------------------------ body plans
func _quadruped() -> void:
	var heavy := kind == "quadruped_heavy"
	var hop := kind == "hopper"
	var leg_h := 0.55 if not hop else 0.25
	base_y = leg_h
	body = _pivot(root, Vector3(0, leg_h, 0))
	var st := MeshKit.begin()
	var blen := 0.55 if not heavy else 0.75
	MeshKit.ellipsoid(st, Vector3(0, 0.12, 0), Vector3(0.3 if not hop else 0.25, 0.27 if not hop else 0.22, blen), Basis(), 14, 10, Callable(), c1)
	MeshKit.ellipsoid(st, Vector3(0, 0.0, 0.05), Vector3(0.24, 0.18, blen * 0.85), Basis(), 12, 8, Callable(), c2)
	if heavy:
		for i in range(6):
			MeshKit.cone(st, Vector3(0, 0.36, -0.4 + i * 0.16), Vector3(0, 0.62 - i * 0.03, -0.32 + i * 0.16), 0.07, 5, Vector2.ONE, c2.darkened(0.3))
		MeshKit.ellipsoid(st, Vector3(0, 0.22, -0.35), Vector3(0.38, 0.34, 0.4), Basis(), 12, 8, Callable(), c1.darkened(0.15))
	_mesh(body, st)
	head = _pivot(body, Vector3(0, 0.22, -blen - 0.05))
	var hs := MeshKit.begin()
	if hop:
		MeshKit.ellipsoid(hs, Vector3(0, 0.05, -0.1), Vector3(0.17, 0.16, 0.18), Basis(), 12, 8, Callable(), c1)
		for sx in [-1.0, 1.0]:
			MeshKit.chain(hs, [Vector3(sx * 0.06, 0.15, -0.05), Vector3(sx * 0.1, 0.4, 0.0), Vector3(sx * 0.11, 0.55, 0.05)], [0.05, 0.05, 0.02], 6, Vector2(1, 0.45), c1, false)
	else:
		MeshKit.ellipsoid(hs, Vector3(0, 0.02, -0.15), Vector3(0.2, 0.2, 0.26), Basis(), 12, 8, Callable(), c1)
		MeshKit.tube(hs, Vector3(0, -0.02, -0.3), Vector3(0, -0.06, -0.55 if not heavy else -0.62), 0.12, 0.08, 10, true, Vector2.ONE, c2)
		if heavy:
			for sx in [-1.0, 1.0]:
				MeshKit.chain(hs, [Vector3(sx * 0.1, -0.08, -0.5), Vector3(sx * 0.22, 0.0, -0.66), Vector3(sx * 0.26, 0.18, -0.72)], [0.045, 0.035, 0.008], 6, Vector2.ONE, Color("efe6d0"), false)
		for sx in [-1.0, 1.0]:
			MeshKit.cone(hs, Vector3(sx * 0.12, 0.17, -0.08), Vector3(sx * 0.16, 0.38, -0.02), 0.06, 5, Vector2(1, 0.5), c1.darkened(0.2))
	_mesh(head, hs)
	_eyes(head, Vector3(0, 0.08, -0.33 if not hop else -0.24), 0.11 if not hop else 0.09, 0.03)
	var lz := [-blen * 0.7, blen * 0.7]
	for z in lz:
		for sx in [-1.0, 1.0]:
			var p := _pivot(body, Vector3(sx * 0.2, 0.0, z))
			var ls := MeshKit.begin()
			var th := 0.1 if not heavy else 0.14
			MeshKit.tube(ls, Vector3.ZERO, Vector3(0, -leg_h * 0.55, 0.04), th, th * 0.8, 8, false, Vector2.ONE, c1)
			MeshKit.tube(ls, Vector3(0, -leg_h * 0.55, 0.04), Vector3(0, -leg_h, -0.02), th * 0.8, th * 0.6, 8, true, Vector2.ONE, c2.darkened(0.25))
			_mesh(p, ls)
			legs.append(p)
			leg_phase.append(0.0 if (sx > 0) == (z < 0) else PI)
	tail = _pivot(body, Vector3(0, 0.2, blen))
	var ts := MeshKit.begin()
	if hop:
		MeshKit.ellipsoid(ts, Vector3(0, 0.02, 0.05), Vector3.ONE * 0.09, Basis(), 8, 6, Callable(), c2)
	else:
		MeshKit.chain(ts, [Vector3.ZERO, Vector3(0, -0.12, 0.3), Vector3(0, -0.3, 0.5)], [0.07, 0.05, 0.015], 6, Vector2.ONE, c1)
	_mesh(tail, ts)

func _crab() -> void:
	base_y = 0.35
	body = _pivot(root, Vector3(0, base_y, 0))
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3(0, 0.1, 0), Vector3(0.6, 0.22, 0.45), Basis(), 14, 8, Callable(), c1)
	for i in range(5):
		MeshKit.cone(st, Vector3((i - 2) * 0.18, 0.28, 0.0), Vector3((i - 2) * 0.2, 0.42, 0.08), 0.06, 5, Vector2.ONE, c2)
	_mesh(body, st)
	head = _pivot(body, Vector3(0, 0.15, -0.42))
	_eyes(head, Vector3(0, 0.12, 0), 0.1, 0.035)
	var es := MeshKit.begin()
	for sx in [-1.0, 1.0]:
		MeshKit.tube(es, Vector3(sx * 0.1, 0, 0), Vector3(sx * 0.1, 0.12, 0), 0.015, 0.015, 5, false, Vector2.ONE, c1)
	_mesh(head, es)
	for sx in [-1.0, 1.0]:
		for i in range(3):
			var p := _pivot(body, Vector3(sx * 0.5, 0.05, -0.2 + i * 0.22))
			var ls := MeshKit.begin()
			MeshKit.chain(ls, [Vector3.ZERO, Vector3(sx * 0.3, 0.15, 0), Vector3(sx * 0.5, -base_y, 0.05)], [0.05, 0.04, 0.02], 6, Vector2.ONE, c1.darkened(0.15), false)
			_mesh(p, ls)
			legs.append(p)
			leg_phase.append(float(i) * 2.1 + (0.0 if sx > 0 else PI))
		var cp := _pivot(body, Vector3(sx * 0.45, 0.1, -0.35))
		var cs := MeshKit.begin()
		MeshKit.tube(cs, Vector3.ZERO, Vector3(sx * 0.15, 0.05, -0.3), 0.07, 0.06, 8, false, Vector2.ONE, c1)
		MeshKit.ellipsoid(cs, Vector3(sx * 0.18, 0.06, -0.45), Vector3(0.14, 0.1, 0.2), Basis(), 10, 6, Callable(), c2)
		_mesh(cp, cs)
		claws.append(cp)

func _toad() -> void:
	base_y = 0.25
	body = _pivot(root, Vector3(0, base_y, 0))
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3(0, 0.25, 0.05), Vector3(0.5, 0.36, 0.55), Basis(), 14, 10, Callable(), c1)
	MeshKit.ellipsoid(st, Vector3(0, 0.12, -0.05), Vector3(0.42, 0.25, 0.48), Basis(), 12, 8, Callable(), c2)
	_mesh(body, st)
	head = _pivot(body, Vector3(0, 0.35, -0.45))
	var hs := MeshKit.begin()
	MeshKit.ellipsoid(hs, Vector3(0, 0.0, -0.05), Vector3(0.42, 0.2, 0.25), Basis(), 12, 8, Callable(), c1)
	_mesh(head, hs)
	_eyes(head, Vector3(0, 0.17, -0.08), 0.22, 0.07)
	for z in [-0.35, 0.35]:
		for sx in [-1.0, 1.0]:
			var p := _pivot(body, Vector3(sx * 0.4, 0.1, z))
			var ls := MeshKit.begin()
			MeshKit.chain(ls, [Vector3.ZERO, Vector3(sx * 0.2, 0.05, z * 0.3), Vector3(sx * 0.25, -base_y, z * 0.2)], [0.1, 0.07, 0.05], 6, Vector2.ONE, c1.darkened(0.1), false)
			_mesh(p, ls)
			legs.append(p)
			leg_phase.append(0.0 if (sx > 0) == (z < 0) else PI)

func _serpent() -> void:
	base_y = 0.6
	body = _pivot(root, Vector3(0, 0, 0))
	for i in range(14):
		var p := _pivot(body, Vector3(0, base_y, i * 0.55))
		var st := MeshKit.begin()
		var r := 0.5 * (1.0 - i / 18.0)
		MeshKit.ellipsoid(st, Vector3.ZERO, Vector3(r, r * 0.9, 0.42), Basis(), 10, 8, Callable(), c1)
		if i % 2 == 0:
			MeshKit.sheet(st, [Vector3(0, r * 0.8, -0.2), Vector3(0, r * 0.8, 0.25)], [Vector3(0, r * 0.8 + 0.35, -0.05), Vector3(0, r * 0.8 + 0.25, 0.3)], c2)
		_mesh(p, st)
		segments.append(p)
	head = _pivot(root, Vector3(0, base_y + 0.4, -0.6))
	var hs := MeshKit.begin()
	MeshKit.ellipsoid(hs, Vector3(0, 0, -0.2), Vector3(0.45, 0.35, 0.65), Basis(), 12, 8, Callable(), c1)
	MeshKit.ellipsoid(hs, Vector3(0, -0.18, -0.35), Vector3(0.38, 0.15, 0.55), Basis(), 10, 6, Callable(), c2)
	for sx in [-1.0, 1.0]:
		MeshKit.sheet(hs, [Vector3(sx * 0.35, 0.1, 0.0), Vector3(sx * 0.4, 0.1, 0.35)], [Vector3(sx * 0.9, 0.35, 0.2), Vector3(sx * 0.75, 0.2, 0.55)], c2)
		MeshKit.cone(hs, Vector3(sx * 0.15, 0.3, 0.05), Vector3(sx * 0.25, 0.65, 0.4), 0.08, 5, Vector2.ONE, c2.darkened(0.2))
	_mesh(head, hs)
	_eyes(head, Vector3(0, 0.15, -0.55), 0.27, 0.07)
	_add_glow(head, Vector3(0, -0.1, -0.85), Color("7fe8ff"))

func _wyvern() -> void:
	base_y = 1.0
	body = _pivot(root, Vector3(0, base_y, 0))
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3(0, 0.1, 0), Vector3(0.45, 0.42, 0.85), Basis(), 14, 10, Callable(), c1)
	MeshKit.ellipsoid(st, Vector3(0, -0.08, -0.1), Vector3(0.36, 0.3, 0.7), Basis(), 12, 8, Callable(), c2)
	for i in range(6):
		MeshKit.cone(st, Vector3(0, 0.45, -0.5 + i * 0.22), Vector3(0, 0.72, -0.4 + i * 0.22), 0.07, 5, Vector2.ONE, c2.darkened(0.3))
	MeshKit.chain(st, [Vector3(0, 0.25, -0.7), Vector3(0, 0.6, -1.1), Vector3(0, 0.85, -1.35)], [0.24, 0.2, 0.17], 10, Vector2.ONE, c1)
	_mesh(body, st)
	head = _pivot(body, Vector3(0, 0.9, -1.45))
	var hs := MeshKit.begin()
	MeshKit.ellipsoid(hs, Vector3(0, 0, -0.25), Vector3(0.22, 0.2, 0.45), Basis(), 12, 8, Callable(), c1)
	MeshKit.ellipsoid(hs, Vector3(0, -0.1, -0.35), Vector3(0.17, 0.08, 0.38), Basis(), 10, 6, Callable(), c2)
	for sx in [-1.0, 1.0]:
		MeshKit.chain(hs, [Vector3(sx * 0.12, 0.12, -0.05), Vector3(sx * 0.2, 0.25, 0.25), Vector3(sx * 0.22, 0.32, 0.5)], [0.05, 0.035, 0.005], 6, Vector2.ONE, Color("2a2420"), false)
	_mesh(head, hs)
	_eyes(head, Vector3(0, 0.1, -0.42), 0.13, 0.04)
	_add_glow(head, Vector3(0, -0.08, -0.72), Color("ff7a2a"))
	for sx in [-1.0, 1.0]:
		var p := _pivot(body, Vector3(sx * 0.32, -0.15, 0.15))
		var ls := MeshKit.begin()
		MeshKit.chain(ls, [Vector3.ZERO, Vector3(0, -0.45, -0.2), Vector3(0, -0.85, 0.05)], [0.16, 0.11, 0.08], 8, Vector2.ONE, c1, false)
		for k in range(3):
			MeshKit.cone(ls, Vector3(0, -0.85, 0.05), Vector3((k - 1) * 0.1, -0.9, -0.2), 0.035, 4, Vector2.ONE, Color("2a2420"))
		_mesh(p, ls)
		legs.append(p)
		leg_phase.append(0.0 if sx > 0 else PI)
		var wp := _pivot(body, Vector3(sx * 0.35, 0.35, -0.3))
		var ws := MeshKit.begin()
		var bone := [Vector3.ZERO, Vector3(sx * 0.9, 0.5, 0.1), Vector3(sx * 1.9, 0.3, 0.3), Vector3(sx * 2.6, -0.1, 0.6)]
		MeshKit.chain(ws, bone, [0.08, 0.06, 0.04, 0.01], 6, Vector2.ONE, c1.darkened(0.2), false)
		MeshKit.sheet(ws, bone, [Vector3(0, 0, 0.6), Vector3(sx * 0.9, 0.0, 1.0), Vector3(sx * 1.8, -0.2, 1.1), Vector3(sx * 2.6, -0.15, 0.7)], c2.darkened(0.35))
		_mesh(wp, ws)
		wings.append(wp)
	tail = _pivot(body, Vector3(0, 0.0, 0.8))
	var ts := MeshKit.begin()
	MeshKit.chain(ts, [Vector3.ZERO, Vector3(0, -0.15, 0.6), Vector3(0, -0.35, 1.3), Vector3(0, -0.5, 2.0), Vector3(0, -0.55, 2.5)], [0.28, 0.2, 0.13, 0.07, 0.02], 8, Vector2.ONE, c1)
	for k in range(4):
		MeshKit.cone(ts, Vector3(0, 0.0 - k * 0.12, 0.5 + k * 0.5), Vector3(0, 0.25 - k * 0.12, 0.6 + k * 0.5), 0.06, 4, Vector2.ONE, c2.darkened(0.3))
	_mesh(tail, ts)

func _worm() -> void:
	base_y = 0.0
	body = _pivot(root, Vector3.ZERO)
	for i in range(10):
		var p := _pivot(body, Vector3(0, 0.6 + i * 0.5, 0))
		var st := MeshKit.begin()
		var r := 0.62 - i * 0.025
		MeshKit.ellipsoid(st, Vector3.ZERO, Vector3(r, 0.35, r), Basis(), 12, 6, Callable(), c1 if i % 2 == 0 else c1.darkened(0.12))
		_mesh(p, st)
		segments.append(p)
	head = _pivot(root, Vector3(0, 5.6, 0))
	var hs := MeshKit.begin()
	MeshKit.tube(hs, Vector3(0, 0, 0), Vector3(0, 0.35, -0.2), 0.55, 0.62, 12, false, Vector2.ONE, c1)
	for k in range(10):
		var a := TAU * k / 10.0
		MeshKit.cone(hs, Vector3(cos(a) * 0.5, 0.35, -0.2 + sin(a) * 0.5), Vector3(cos(a) * 0.3, 0.1, -0.2 + sin(a) * 0.3), 0.07, 4, Vector2.ONE, Color("efe6d0"))
	MeshKit.ellipsoid(hs, Vector3(0, 0.2, -0.2), Vector3(0.45, 0.05, 0.45), Basis(), 10, 4, Callable(), c2)
	_mesh(head, hs)
	_add_glow(head, Vector3(0, 0.2, -0.2), Color("ffb060"))

func _golem() -> void:
	base_y = 1.0
	body = _pivot(root, Vector3(0, base_y, 0))
	var st := MeshKit.begin()
	MeshKit.rock(st, Vector3(0, 0.55, 0), Vector3(0.65, 0.6, 0.45), 3, c1)
	MeshKit.rock(st, Vector3(0, 0.0, 0.05), Vector3(0.45, 0.35, 0.35), 4, c1.darkened(0.1))
	for i in range(8):
		MeshKit.ellipsoid(st, Vector3(randf_range(-0.5, 0.5), 0.9 + randf_range(0, 0.25), randf_range(-0.3, 0.3)), Vector3(0.2, 0.08, 0.2), Basis(), 6, 4, Callable(), c2)
	_mesh(body, st)
	head = _pivot(body, Vector3(0, 1.15, -0.15))
	var hs := MeshKit.begin()
	MeshKit.rock(hs, Vector3(0, 0.1, 0), Vector3(0.25, 0.22, 0.24), 9, c1)
	_mesh(head, hs)
	_eyes(head, Vector3(0, 0.12, -0.2), 0.09, 0.045)
	eye_mat.emission = Color("7fffb0")
	for sx in [-1.0, 1.0]:
		var ap := _pivot(body, Vector3(sx * 0.75, 0.8, 0))
		var as_ := MeshKit.begin()
		MeshKit.rock(as_, Vector3(sx * 0.1, -0.35, 0), Vector3(0.25, 0.4, 0.25), 11 + int(sx), c1)
		MeshKit.rock(as_, Vector3(sx * 0.15, -1.0, -0.05), Vector3(0.32, 0.35, 0.3), 13 + int(sx), c1.darkened(0.1))
		_mesh(ap, as_)
		claws.append(ap)
		var lp := _pivot(body, Vector3(sx * 0.3, -0.25, 0))
		var ls := MeshKit.begin()
		MeshKit.rock(ls, Vector3(0, -0.4, 0), Vector3(0.24, 0.42, 0.24), 21 + int(sx), c1)
		_mesh(lp, ls)
		legs.append(lp)
		leg_phase.append(0.0 if sx > 0 else PI)

func _wisp() -> void:
	base_y = 1.6
	body = _pivot(root, Vector3(0, base_y, 0))
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3.ZERO, Vector3.ONE * 0.3, Basis(), 12, 8)
	var m := MeshKit.pbr(c1, 0.2, 0.0, c1, 3.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.85
	_mesh(body, st, m)
	head = _pivot(body, Vector3.ZERO)
	for i in range(4):
		var p := _pivot(body, Vector3.ZERO)
		var ms := MeshKit.begin()
		MeshKit.ellipsoid(ms, Vector3(0.55, 0, 0), Vector3.ONE * 0.07, Basis(), 6, 4)
		_mesh(p, ms, MeshKit.pbr(c2, 0.2, 0.0, c2, 3.0))
		p.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		segments.append(p)
	light = OmniLight3D.new()
	light.light_color = c1
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.shadow_enabled = false
	body.add_child(light)

func _add_glow(parent: Node3D, pos: Vector3, col: Color) -> void:
	var st := MeshKit.begin()
	MeshKit.ellipsoid(st, Vector3.ZERO, Vector3.ONE * 0.18, Basis(), 8, 6)
	var m := MeshKit.pbr(col, 0.2, 0.0, col, 6.0)
	glow = _mesh(parent, st, m, pos)
	glow.scale = Vector3.ZERO

func set_rage(on: bool) -> void:
	eye_mat.emission = Color("ff2a1a") if on else (Color("7fffb0") if kind == "golem" else Color("ffb030"))
	eye_mat.emission_energy_multiplier = 4.0 if on else 2.0

# ------------------------------------------------------------------ animation
## anim: current attack anim ("" when moving), ph: 0 windup / 1 active / 2 recover, k: 0..1 in phase.
func animate(delta: float, speed: float, anim: String, ph: int, k: float, stagger: bool) -> void:
	t += delta
	walk += delta * speed * (2.6 / maxf(size, 0.6))
	var bob := sin(t * 2.0) * 0.02
	var lean := 0.0
	var head_rot := Vector3.ZERO
	var root_y := 0.0
	var spin := 0.0
	var tell := 0.0
	if ph == 0:
		tell = k
	match anim:
		"bite":
			if ph == 0: head_rot = Vector3(0.5 * k, 0, 0); lean = 0.1 * k
			elif ph == 1: head_rot = Vector3(-0.5, 0, 0); lean = -0.2
		"lunge", "charge":
			if ph == 0: lean = 0.25 * k; root_y = -0.15 * k
			elif ph == 1: lean = -0.3; head_rot = Vector3(-0.3, 0, 0)
		"slam", "overhead":
			if ph == 0: lean = 0.55 * k; root_y = 0.25 * k
			elif ph == 1: lean = -0.35 * (1.0 - k * 0.5); root_y = -0.1
		"spin", "tail":
			if ph == 0: spin = -0.5 * k
			elif ph == 1: spin = -0.5 + TAU * k
		"breath", "projectile":
			if ph == 0: head_rot = Vector3(0.6 * k, 0, 0); lean = 0.15 * k
			elif ph == 1: head_rot = Vector3(-0.25, sin(t * 4.0) * 0.4 if anim == "breath" else 0.0, 0)
		"roar":
			head_rot = Vector3(0.7, 0, 0) if ph <= 1 else Vector3.ZERO
			lean = 0.2 if ph <= 1 else 0.0
		"leap":
			if ph == 0: root_y = -0.25 * k; lean = 0.2 * k
			elif ph == 1: lean = -0.2
		"dive", "burrow":
			if ph == 0: root_y = -3.5 * smoothstep(0.0, 0.5, k)
			elif ph == 1: root_y = lerpf(-3.5, 0.6, smoothstep(0.0, 0.6, k)); head_rot = Vector3(0.6, 0, 0)
			elif ph == 2: root_y = 0.6 * (1.0 - k)
	if stagger:
		lean = sin(t * 18.0) * 0.08 - 0.2
		head_rot = Vector3(-0.4, sin(t * 9.0) * 0.3, 0)
	var w := 1.0 - exp(-10.0 * delta)
	if body:
		body.rotation.x = lerpf(body.rotation.x, lean, w)
		body.rotation.y = spin if anim in ["spin", "tail"] and ph <= 1 else lerp_angle(body.rotation.y, 0.0, w)
		body.position.y = lerpf(body.position.y, base_y + bob + root_y, w * 2.0 if absf(root_y) > 1.0 else w)
	if head:
		head.rotation = head.rotation.lerp(head_rot + Vector3(sin(t * 1.3) * 0.05, sin(t * 0.7) * 0.1, 0), w)
	var amp := clampf(speed / 3.0, 0.0, 1.0) * 0.6
	for i in range(legs.size()):
		legs[i].rotation.x = sin(walk + leg_phase[i]) * amp
	if tail:
		tail.rotation.y = sin(t * 1.5 + walk * 0.5) * 0.25
		if anim == "tail" and ph == 1:
			tail.rotation.y = sin(k * PI) * 1.2
	for i in range(wings.size()):
		var flap := sin(t * (6.0 if anim == "leap" and ph >= 0 else 1.2)) * (0.6 if anim == "leap" else 0.12)
		wings[i].rotation.z = (flap + (0.4 if ph == 0 and anim in ["breath", "roar"] else 0.0)) * (1.0 if i == 0 else -1.0)
	for i in range(claws.size()):
		claws[i].rotation.x = lerpf(claws[i].rotation.x, (-1.2 * tell if anim == "slam" else 0.0) + (0.8 if anim == "slam" and ph == 1 else 0.0), w)
	if kind == "serpent":
		for i in range(segments.size()):
			var s := segments[i]
			s.position.x = sin(t * 2.0 + i * 0.55 + walk * 0.6) * 0.35 * (i / 6.0)
			s.position.y = base_y + sin(t * 1.4 + i * 0.4) * 0.15 + root_y * (1.0 - i / 14.0)
		head.position.y = base_y + 0.4 + root_y + (0.6 if ph == 0 and anim in ["breath", "bite"] else 0.0) * tell
	elif kind == "worm":
		for i in range(segments.size()):
			segments[i].position = Vector3(sin(t * 1.6 + i * 0.5) * 0.25 * i / 10.0, 0.6 + i * 0.5, cos(t * 1.2 + i * 0.4) * 0.15 * i / 10.0)
		head.position = Vector3(segments[-1].position.x, 5.6, segments[-1].position.z)
		head.rotation.x = lerpf(head.rotation.x, -0.6 if (ph == 1 and anim in ["bite", "slam"]) else 0.0, w)
		root.position.y = lerpf(root.position.y, root_y, w * 2.0)
	elif kind == "wisp":
		for i in range(segments.size()):
			segments[i].rotate_object_local(Vector3.UP, delta * (2.0 + i))
		body.position.y = base_y + sin(t * 2.0) * 0.15
	if glow:
		var gs := 0.0
		if anim in ["breath", "burrow", "dive"] and ph <= 1:
			gs = (k if ph == 0 else 1.2)
		glow.scale = glow.scale.lerp(Vector3.ONE * gs, w)

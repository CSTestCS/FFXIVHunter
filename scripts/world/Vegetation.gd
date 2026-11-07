class_name Vegetation
extends RefCounted
## Trees, rocks and grass. Everything is instanced with MultiMesh (a few draw calls per type),
## grass lives in 32 m chunks with short visibility ranges so only nearby chunks render.

const FoliageShader := preload("res://shaders/foliage.gdshader")
const GrassShader := preload("res://shaders/grass.gdshader")

static var _meshes := {}

static func tree_meshes(kind: String) -> Array:
	if _meshes.has(kind):
		return _meshes[kind]
	var trunk := MeshKit.begin()
	var leaves := MeshKit.begin()
	var bark := Color("5b4632")
	var g1 := Color(1, 1, 1)
	var g2 := Color(0.82, 0.92, 0.75)
	match kind:
		"broadleaf", "giant":
			MeshKit.tube(trunk, Vector3.ZERO, Vector3(0, 4.2, 0), 0.32, 0.2, 8, false, Vector2.ONE, bark)
			for k in range(4):
				var a := TAU * k / 4.0 + 0.4
				MeshKit.tube(trunk, Vector3(0, 3.2, 0), Vector3(cos(a) * 1.3, 4.8, sin(a) * 1.3), 0.12, 0.05, 6, false, Vector2.ONE, bark)
			for k in range(7):
				var a := TAU * k / 7.0
				var c := Vector3(cos(a) * 1.3, 5.2 + sin(k * 2.3) * 0.6, sin(a) * 1.3) if k > 0 else Vector3(0, 6.0, 0)
				MeshKit.ellipsoid(leaves, c, Vector3(1.6, 1.25, 1.6), Basis(), 10, 6, Callable(), g1 if k % 2 == 0 else g2, 0.18)
		"pine":
			MeshKit.tube(trunk, Vector3.ZERO, Vector3(0, 7.5, 0), 0.26, 0.08, 7, false, Vector2.ONE, bark)
			for k in range(5):
				var y := 1.8 + k * 1.25
				MeshKit.cone(leaves, Vector3(0, y, 0), Vector3(0, y + 2.0, 0), 2.1 - k * 0.35, 9, Vector2.ONE, g1 if k % 2 == 0 else g2)
		"palm":
			var pts := [Vector3.ZERO, Vector3(0.3, 2.0, 0), Vector3(0.9, 4.0, 0), Vector3(1.6, 5.8, 0)]
			MeshKit.chain(trunk, pts, [0.25, 0.22, 0.18, 0.15], 7, Vector2.ONE, Color("7a6248"))
			var top: Vector3 = pts[3]
			for k in range(8):
				var a := TAU * k / 8.0
				var dir := Vector3(cos(a), 0, sin(a))
				var side := dir.cross(Vector3.UP) * 0.45
				var mid := top + dir * 1.6 + Vector3.UP * 0.4
				var tip := top + dir * 3.0 - Vector3.UP * 0.6
				MeshKit.sheet(leaves, [top, mid, tip], [top + side * 0.2, mid + side, tip + side * 0.2], g1 if k % 2 == 0 else g2)
		"dead":
			MeshKit.tube(trunk, Vector3.ZERO, Vector3(0.2, 4.0, 0), 0.25, 0.12, 7, false, Vector2.ONE, Color("6a5a4a"))
			for k in range(5):
				var a := TAU * k / 5.0
				MeshKit.tube(trunk, Vector3(0.1, 2.0 + k * 0.4, 0), Vector3(cos(a) * 1.4, 3.2 + k * 0.4, sin(a) * 1.4), 0.09, 0.02, 5, false, Vector2.ONE, Color("6a5a4a"))
		"mangrove":
			MeshKit.tube(trunk, Vector3(0, 0.8, 0), Vector3(0, 4.0, 0), 0.3, 0.2, 7, false, Vector2.ONE, Color("4a3f30"))
			for k in range(6):
				var a := TAU * k / 6.0
				MeshKit.tube(trunk, Vector3(0, 1.2, 0), Vector3(cos(a) * 1.4, -0.3, sin(a) * 1.4), 0.1, 0.07, 5, false, Vector2.ONE, Color("4a3f30"))
			for k in range(5):
				var a := TAU * k / 5.0
				MeshKit.ellipsoid(leaves, Vector3(cos(a) * 1.4, 4.4, sin(a) * 1.4), Vector3(1.8, 0.8, 1.8), Basis(), 9, 5, Callable(), g1 if k % 2 == 0 else g2, 0.2)
		"cactus":
			MeshKit.tube(leaves, Vector3.ZERO, Vector3(0, 3.0, 0), 0.3, 0.28, 10, true, Vector2.ONE, g1)
			MeshKit.chain(leaves, [Vector3(0, 1.4, 0), Vector3(0.7, 1.5, 0), Vector3(0.75, 2.3, 0)], [0.18, 0.18, 0.16], 8, Vector2.ONE, g2)
			MeshKit.chain(leaves, [Vector3(0, 1.9, 0), Vector3(-0.6, 2.0, 0), Vector3(-0.65, 2.6, 0)], [0.16, 0.16, 0.14], 8, Vector2.ONE, g2)
			MeshKit.tube(trunk, Vector3(0, 0, 0), Vector3(0, 0.05, 0), 0.01, 0.01, 3, false)
	var out := [MeshKit.finish(trunk), MeshKit.finish(leaves)]
	_meshes[kind] = out
	return out

static func rock_mesh(v: int) -> Mesh:
	var key := "rock_%d" % v
	if not _meshes.has(key):
		var st := MeshKit.begin()
		MeshKit.rock(st, Vector3(0, 0.3, 0), Vector3(1.0, 0.7, 0.85), 100 + v)
		_meshes[key] = MeshKit.finish(st)
	return _meshes[key]

static func grass_mesh() -> Mesh:
	if _meshes.has("grass"):
		return _meshes.grass
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in range(7):
		var a := rng.randf() * TAU
		var off := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var h := rng.randf_range(0.35, 0.7)
		var side := Vector3(cos(a), 0, sin(a)) * 0.05
		var lean := Vector3(sin(a), 0, -cos(a)) * rng.randf_range(0.05, 0.2)
		var col := Color(1, 1, 1).darkened(rng.randf() * 0.25)
		var b0 := off - side
		var b1 := off + side
		var tp := off + lean + Vector3.UP * h
		var n := (b1 - b0).cross(tp - b0).normalized()
		st.set_color(col); st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(b0)
		st.set_color(col); st.set_normal(n); st.set_uv(Vector2(1, 0)); st.add_vertex(b1)
		st.set_color(col); st.set_normal(n); st.set_uv(Vector2(0.5, 1)); st.add_vertex(tp)
	_meshes.grass = MeshKit.finish(st)
	return _meshes.grass

## Populate a field/city region. `avoid` = Array of [Vector3 center, radius].
static func populate(parent: Node3D, terrain: Terrain, rd: Dictionary, avoid: Array, density_mult := 1.0) -> void:
	var bio: Dictionary = DB.biomes[rd.get("biome", "grass")]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rd.seed) * 31
	var q := Settings.vegetation_density() * density_mult
	var noise := FastNoiseLite.new()
	noise.seed = int(rd.seed) + 99
	noise.frequency = 0.012
	var bark_mat := MeshKit.vcol_pbr(0.9)
	var leaf_mat := ShaderMaterial.new()
	leaf_mat.shader = FoliageShader
	leaf_mat.set_shader_parameter("leaf", Color(bio.grass).darkened(0.15))
	var body := StaticBody3D.new()
	body.name = "VegetationBody"
	parent.add_child(body)
	# trees
	var kinds: Array = bio.trees
	var per_kind := {}
	for k in kinds:
		per_kind[k] = []
	var step := 11.0 / sqrt(maxf(float(bio.tree_density) * q, 0.05))
	var x := -terrain.half + 20.0
	while x < terrain.half - 20.0:
		var z := -terrain.half + 20.0
		while z < terrain.half - 20.0:
			var px := x + rng.randf_range(-step * 0.45, step * 0.45)
			var pz := z + rng.randf_range(-step * 0.45, step * 0.45)
			z += step
			if noise.get_noise_2d(px, pz) < -0.15:
				continue
			if not _ok(terrain, px, pz, avoid, 0.82, 1.0):
				continue
			var kind: String = kinds[rng.randi() % kinds.size()]
			if kind == "giant" and rng.randf() > 0.15:
				kind = "broadleaf"
			per_kind[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3) * (3.0 if kind == "giant" else 1.0)), Vector3(px, terrain.height_at(px, pz) - 0.2, pz)))
		x += step
	for kind in per_kind:
		var list: Array = per_kind[kind]
		if list.is_empty():
			continue
		var meshes := tree_meshes(kind)
		for group in _chunked(list, 128.0):
			_multimesh(parent, meshes[0], bark_mat, group, 300.0, true)
			_multimesh(parent, meshes[1], leaf_mat, group, 300.0, true)
		for xf in list:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.35 * (xf as Transform3D).basis.get_scale().x
			cyl.height = 4.0
			cs.shape = cyl
			cs.position = (xf as Transform3D).origin + Vector3.UP * 2.0
			body.add_child(cs)
	# rocks
	var rock_mat := MeshKit.pbr(Color(bio.rock), 0.85)
	var rock_lists := [[], [], []]
	var n_rocks := int(90 * float(bio.rocks) * maxf(q, 0.5))
	for i in range(n_rocks):
		var px := rng.randf_range(-terrain.half + 15.0, terrain.half - 15.0)
		var pz := rng.randf_range(-terrain.half + 15.0, terrain.half - 15.0)
		if not _ok(terrain, px, pz, avoid, 0.6, 0.0):
			continue
		var s := rng.randf_range(0.5, 2.6)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.1), s)), Vector3(px, terrain.height_at(px, pz) - 0.25 * s, pz))
		rock_lists[i % 3].append(xf)
		if s > 1.2:
			var cs := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 0.75 * s
			cs.shape = sph
			cs.position = xf.origin + Vector3.UP * 0.2 * s
			body.add_child(cs)
	for v in range(3):
		for group in _chunked(rock_lists[v], 128.0):
			_multimesh(parent, rock_mesh(v), rock_mat, group, 300.0, true)
	# grass chunks
	if not Settings.grass_enabled() or float(bio.grass_density) <= 0.0:
		return
	var gmat := ShaderMaterial.new()
	gmat.shader = GrassShader
	gmat.set_shader_parameter("base_col", Color(bio.grass).darkened(0.35))
	gmat.set_shader_parameter("tip_col", Color(bio.grass2).lightened(0.1))
	var gm := grass_mesh()
	var chunk := 32.0
	var per := int(260 * float(bio.grass_density) * Settings.vegetation_density())
	var cx := -terrain.half
	while cx < terrain.half:
		var cz := -terrain.half
		while cz < terrain.half:
			var list := []
			for i in range(per):
				var px := cx + rng.randf() * chunk
				var pz := cz + rng.randf() * chunk
				if noise.get_noise_2d(px * 2.0, pz * 2.0) < -0.3:
					continue
				if not _ok(terrain, px, pz, [], 0.85, 0.6, 0.3):
					continue
				list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(px, terrain.height_at(px, pz) - 0.03, pz)))
			if not list.is_empty():
				var mmi := _multimesh(parent, gm, gmat, list, 55.0, false)
				mmi.visibility_range_end_margin = 10.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			cz += chunk
		cx += chunk

static func _ok(terrain: Terrain, x: float, z: float, avoid: Array, min_ny: float, water_margin: float, max_mask := 0.05) -> bool:
	if not terrain.in_bounds(x, z, 12.0):
		return false
	var h := terrain.height_at(x, z)
	if h < terrain.water + water_margin:
		return false
	if terrain.normal_at(x, z).y < min_ny:
		return false
	if terrain.mask_at(x, z) > max_mask:
		return false
	for a in avoid:
		var c: Vector3 = a[0]
		if Vector2(x - c.x, z - c.z).length() < float(a[1]):
			return false
	return true

static func _chunked(list: Array, size: float) -> Array:
	var groups := {}
	for xf in list:
		var o: Vector3 = (xf as Transform3D).origin
		var key := Vector2i(floori(o.x / size), floori(o.z / size))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(xf)
	return groups.values()

## One MultiMesh positioned at the centre of its instances (so visibility ranges and culling
## are measured from the right place).
static func _multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array, range_end: float, shadows: bool) -> MultiMeshInstance3D:
	if mesh.get_surface_count() == 0:
		return null
	var c := Vector3.ZERO
	for xf in xforms:
		c += (xf as Transform3D).origin
	c /= maxf(1.0, xforms.size())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		var xf: Transform3D = xforms[i]
		xf.origin -= c
		mm.set_instance_transform(i, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.position = c
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.visibility_range_end = range_end
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi

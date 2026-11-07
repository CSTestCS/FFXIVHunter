class_name Terrain
extends RefCounted
## Heightfield terrain generated from region data. One height grid feeds the render mesh
## (8x8 culled chunks), the collision HeightMapShape3D, and fast height queries for AI/props.

const N := 257                 # vertices per side
const CHUNKS := 8

var size := 512.0
var cell := 2.0
var half := 256.0
var water := -1000.0
var h := PackedFloat32Array()
var path_mask := PackedFloat32Array()  # 0..1 dirt road
var pave_mask := PackedFloat32Array()  # 0..1 city paving
var rd: Dictionary
var exits_world := []                  # [{pos: Vector3, data: Dictionary}]
var hub := Vector3.ZERO

func generate(region: Dictionary) -> void:
	rd = region
	size = float(region.size)
	half = size * 0.5
	cell = size / float(N - 1)
	water = float(region.get("water", -1000.0))
	h.resize(N * N)
	path_mask.resize(N * N)
	pave_mask.resize(N * N)
	path_mask.fill(0.0)
	pave_mask.fill(0.0)
	var noise := FastNoiseLite.new()
	noise.seed = int(region.seed)
	noise.frequency = float(region.get("freq", 0.006))
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.45
	var ridge := FastNoiseLite.new()
	ridge.seed = int(region.seed) + 7
	ridge.frequency = float(region.get("freq", 0.006)) * 1.7
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	var base := float(region.get("base", 8.0))
	var amp := float(region.get("amp", 10.0))
	var biome: String = region.get("biome", "grass")
	for zi in range(N):
		for xi in range(N):
			var x := -half + xi * cell
			var z := -half + zi * cell
			var v := noise.get_noise_2d(x, z)
			var y := base + v * amp
			if biome in ["highland", "snow"]:
				y += maxf(0.0, ridge.get_noise_2d(x, z)) * amp * 0.6
			elif biome in ["canyon", "volcanic"]:
				# mesas and gorges: terrace the noise and carve ridged gullies
				var r := ridge.get_noise_2d(x, z)
				y = base + (round(v * 3.0) / 3.0 * 0.7 + v * 0.3) * amp - maxf(0.0, r) * amp * 0.5
			elif biome == "desert":
				y += sin(x * 0.03 + noise.get_noise_2d(z, x) * 3.0) * amp * 0.12
			h[zi * N + xi] = y
	# sea side
	if region.has("sea"):
		var start := float(region.get("sea_start", 100.0))
		for zi in range(N):
			for xi in range(N):
				var x := -half + xi * cell
				var z := -half + zi * cell
				var d := 0.0
				match region.sea:
					"south": d = z - start
					"north": d = -z - start
					"west": d = -x + start
					"east": d = x - start
				if d > -40.0:
					var i := zi * N + xi
					h[i] = lerpf(h[i], water - 9.0, smoothstep(-40.0, 50.0, d))
	for lake in region.get("lakes", []):
		var c: Vector3 = lake[0]
		var r: float = lake[1]
		_apply_radial(c, r, water - 5.0, 0.35)
	# rim of cliffs around the region edge (except near exits), like zone borders
	var exits: Array = region.get("exits", [])
	for e in exits:
		exits_world.append({"pos": exit_point(e, 0.0), "data": e})
	for zi in range(N):
		for xi in range(N):
			var x := -half + xi * cell
			var z := -half + zi * cell
			var edge := half - maxf(absf(x), absf(z))
			if edge < 30.0:
				var near_exit := 999.0
				for ew in exits_world:
					near_exit = minf(near_exit, Vector2(x, z).distance_to(Vector2(ew.pos.x, ew.pos.z)))
				var k := smoothstep(30.0, 0.0, edge) * smoothstep(14.0, 32.0, near_exit)
				if region.has("sea") and h[zi * N + xi] < water:
					k = 0.0
				h[zi * N + xi] += k * (18.0 + amp * 0.5)

## Point on the region edge for an exit, `inset` metres inside.
func exit_point(e: Dictionary, inset: float) -> Vector3:
	var o := float(e.get("offset", 0))
	var edge := half - inset
	match e.side:
		"north": return Vector3(o, 0, -edge)
		"south": return Vector3(o, 0, edge)
		"west": return Vector3(-edge, 0, o)
		_: return Vector3(edge, 0, o)

func _apply_radial(c: Vector3, r: float, target: float, inner: float) -> void:
	var x0 := maxi(0, int((c.x - r + half) / cell))
	var x1 := mini(N - 1, int((c.x + r + half) / cell) + 1)
	var z0 := maxi(0, int((c.z - r + half) / cell))
	var z1 := mini(N - 1, int((c.z + r + half) / cell) + 1)
	for zi in range(z0, z1 + 1):
		for xi in range(x0, x1 + 1):
			var d := Vector2(-half + xi * cell - c.x, -half + zi * cell - c.z).length()
			if d < r:
				var i := zi * N + xi
				h[i] = lerpf(h[i], target, smoothstep(r, r * inner, d))

## Flatten a disc to `height` (or to its own average when height is NAN), with soft falloff.
func flatten(c: Vector3, r: float, height := NAN, falloff := 8.0, pave := 0.0, keep_water := false) -> float:
	if is_nan(height):
		height = maxf(height_at(c.x, c.z), water + 0.6)
	var R := r + falloff
	var x0 := maxi(0, int((c.x - R + half) / cell))
	var x1 := mini(N - 1, int((c.x + R + half) / cell) + 1)
	var z0 := maxi(0, int((c.z - R + half) / cell))
	var z1 := mini(N - 1, int((c.z + R + half) / cell) + 1)
	for zi in range(z0, z1 + 1):
		for xi in range(x0, x1 + 1):
			var d := Vector2(-half + xi * cell - c.x, -half + zi * cell - c.z).length()
			if d < R:
				var i := zi * N + xi
				if keep_water and h[i] < water + 0.2:
					continue
				var k := 1.0 - smoothstep(r, R, d)
				h[i] = lerpf(h[i], height, k)
				if pave > 0.0:
					pave_mask[i] = maxf(pave_mask[i], k * pave)
	return height

## Carve a gentle road along a polyline: smooths height and paints dirt.
func road(points: Array, width := 4.0, paint := 1.0, pave := false) -> void:
	var samples := []
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 2.0))
		for k in range(n):
			samples.append(a.lerp(b, float(k) / n))
	samples.append(points[-1])
	# target heights: smoothed along the path, kept above water
	var heights := []
	for p in samples:
		heights.append(maxf(height_at(p.x, p.z), water + 0.5))
	for _pass in range(6):
		for i in range(1, heights.size() - 1):
			heights[i] = (heights[i - 1] + heights[i] * 2.0 + heights[i + 1]) * 0.25
	var R := width + 4.0
	for si in range(samples.size()):
		var p: Vector3 = samples[si]
		var x0 := maxi(0, int((p.x - R + half) / cell))
		var x1 := mini(N - 1, int((p.x + R + half) / cell) + 1)
		var z0 := maxi(0, int((p.z - R + half) / cell))
		var z1 := mini(N - 1, int((p.z + R + half) / cell) + 1)
		for zi in range(z0, z1 + 1):
			for xi in range(x0, x1 + 1):
				var d := Vector2(-half + xi * cell - p.x, -half + zi * cell - p.z).length()
				if d < R:
					var i := zi * N + xi
					var k := 1.0 - smoothstep(width * 0.5, R, d)
					h[i] = lerpf(h[i], heights[si], k * 0.85)
					var m := (1.0 - smoothstep(width * 0.3, width * 0.75, d)) * paint
					if pave:
						pave_mask[i] = maxf(pave_mask[i], m)
					else:
						path_mask[i] = maxf(path_mask[i], m)

## Wiggly road between two points.
func road_between(a: Vector3, b: Vector3, rng: RandomNumberGenerator, width := 4.0) -> void:
	var pts := [a]
	var n := maxi(2, int(a.distance_to(b) / 40.0))
	var side := (b - a).cross(Vector3.UP).normalized()
	for i in range(1, n):
		var t := float(i) / n
		pts.append(a.lerp(b, t) + side * rng.randf_range(-12.0, 12.0) * sin(t * PI))
	pts.append(b)
	road(pts, width)

# ------------------------------------------------------------------ queries
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + half) / cell, 0.0, N - 1.001)
	var fz := clampf((z + half) / cell, 0.0, N - 1.001)
	var xi := int(fx)
	var zi := int(fz)
	var tx := fx - xi
	var tz := fz - zi
	var i := zi * N + xi
	var a := lerpf(h[i], h[i + 1], tx)
	var b := lerpf(h[i + N], h[i + N + 1], tx)
	return lerpf(a, b, tz)

func normal_at(x: float, z: float) -> Vector3:
	var e := cell
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()

func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height_at(p.x, p.z), p.z)

func is_water(x: float, z: float, margin := 0.0) -> bool:
	return height_at(x, z) < water - margin

func mask_at(x: float, z: float) -> float:
	var xi := clampi(int(round((x + half) / cell)), 0, N - 1)
	var zi := clampi(int(round((z + half) / cell)), 0, N - 1)
	return maxf(path_mask[zi * N + xi], pave_mask[zi * N + xi])

func in_bounds(x: float, z: float, margin := 30.0) -> bool:
	return absf(x) < half - margin and absf(z) < half - margin

# ------------------------------------------------------------------ build
func build(parent: Node3D, mat: Material) -> void:
	var cs := (N - 1) / CHUNKS
	var normals := PackedVector3Array()
	normals.resize(N * N)
	for zi in range(N):
		for xi in range(N):
			var l := h[zi * N + maxi(xi - 1, 0)]
			var r := h[zi * N + mini(xi + 1, N - 1)]
			var d := h[maxi(zi - 1, 0) * N + xi]
			var u := h[mini(zi + 1, N - 1) * N + xi]
			normals[zi * N + xi] = Vector3(l - r, 2.0 * cell, d - u).normalized()
	for cz in range(CHUNKS):
		for cx in range(CHUNKS):
			var verts := PackedVector3Array()
			var nrms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var w := cs + 1
			for zi in range(cz * cs, cz * cs + w):
				for xi in range(cx * cs, cx * cs + w):
					var i := zi * N + xi
					verts.append(Vector3(-half + xi * cell, h[i], -half + zi * cell))
					nrms.append(normals[i])
					cols.append(Color(path_mask[i], 0.0, pave_mask[i], 1.0))
			for z in range(cs):
				for x in range(cs):
					var a := z * w + x
					idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = nrms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.name = "Terrain_%d_%d" % [cx, cz]
			parent.add_child(mi)
	# collision: uniform-scaled heightmap
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	var scaled := PackedFloat32Array()
	scaled.resize(N * N)
	for i in range(N * N):
		scaled[i] = h[i] / cell
	shape.map_data = scaled
	var cs3 := CollisionShape3D.new()
	cs3.shape = shape
	cs3.scale = Vector3.ONE * cell
	body.add_child(cs3)
	parent.add_child(body)
	# invisible walls on the region border
	for side in [[Vector3(0, 0, -half), Vector3(size, 200, 2)], [Vector3(0, 0, half), Vector3(size, 200, 2)],
			[Vector3(-half, 0, 0), Vector3(2, 200, size)], [Vector3(half, 0, 0), Vector3(2, 200, size)]]:
		var wcs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = side[1]
		wcs.shape = bs
		wcs.position = side[0]
		body.add_child(wcs)

## Small top-down image of the region for the map / minimap (no extra rendering cost).
func map_image(px := 256) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	var bio: Dictionary = DB.biomes[rd.get("biome", "grass")]
	var grass := Color(bio.grass)
	var rock := Color(bio.rock)
	var sand := Color(bio.sand)
	var dirt := Color(bio.dirt)
	var deep := Color("1d4a6b")
	var shallow := Color("3f8fb0")
	for y in range(px):
		for x in range(px):
			var wx := -half + (x + 0.5) / px * size
			var wz := -half + (y + 0.5) / px * size
			var ht := height_at(wx, wz)
			var c := grass
			var n := normal_at(wx, wz)
			if n.y < 0.8:
				c = rock
			if ht < water + 1.0:
				c = sand
			if ht < water:
				c = shallow.lerp(deep, clampf((water - ht) / 6.0, 0.0, 1.0))
			c = c.lerp(dirt, mask_at(wx, wz))
			var shade := clampf(0.75 + (n.x - n.z) * 0.8, 0.5, 1.2)
			img.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade))
	return img

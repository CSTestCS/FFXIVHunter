class_name MeshKit
extends RefCounted
## Tiny procedural modelling kit. Everything is appended to a SurfaceTool with explicit
## normals, so a whole prop/creature part becomes ONE mesh (one draw call).

static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func finish(st: SurfaceTool, mat: Material = null) -> ArrayMesh:
	var m := st.commit()
	if mat and m.get_surface_count() > 0:
		m.surface_set_material(0, mat)
	return m

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col := Color.WHITE) -> void:
	st.set_color(col); st.set_normal(na); st.add_vertex(a)
	st.set_color(col); st.set_normal(nb); st.add_vertex(b)
	st.set_color(col); st.set_normal(nc); st.add_vertex(c)

## Ellipsoid. `keep` (optional) receives the unit-sphere direction and returns false to cut a patch away.
static func ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, basis := Basis(), seg := 12, rings := 8, keep := Callable(), col := Color.WHITE, noise_amp := 0.0) -> void:
	var grid := []
	var ngrid := []
	var dirs := []
	for i in range(rings + 1):
		var ph := PI * i / rings
		var row := []
		var nrow := []
		var drow := []
		for j in range(seg + 1):
			var th := TAU * j / seg
			var d := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var amp := 1.0
			if noise_amp > 0.0:
				amp += noise_amp * (sin(d.x * 7.1 + d.y * 3.3) * sin(d.z * 5.7 + d.y * 4.1))
			row.append(c + basis * (d * r * amp))
			nrow.append((basis * (d / r)).normalized())
			drow.append(d)
		grid.append(row)
		ngrid.append(nrow)
		dirs.append(drow)
	for i in range(rings):
		for j in range(seg):
			if keep.is_valid():
				var mid: Vector3 = (dirs[i][j] + dirs[i + 1][j + 1]) * 0.5
				if not keep.call(mid.normalized()):
					continue
			_tri(st, grid[i][j], grid[i + 1][j], grid[i][j + 1], ngrid[i][j], ngrid[i + 1][j], ngrid[i][j + 1], col)
			_tri(st, grid[i][j + 1], grid[i + 1][j], grid[i + 1][j + 1], ngrid[i][j + 1], ngrid[i + 1][j], ngrid[i + 1][j + 1], col)

## Tapered tube between a and b (with optional end caps). sq squashes the cross-section.
static func tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, seg := 10, caps := true, sq := Vector2.ONE, col := Color.WHITE) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.0001:
		return
	var dn := d / L
	var up := Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT
	var u := dn.cross(up).normalized()
	var v := dn.cross(u)
	var slope := (ra - rb) / L
	for j in range(seg):
		var t0 := TAU * j / seg
		var t1 := TAU * (j + 1) / seg
		var d0 := (u * cos(t0) * sq.x + v * sin(t0) * sq.y)
		var d1 := (u * cos(t1) * sq.x + v * sin(t1) * sq.y)
		var n0 := (d0 + dn * slope).normalized()
		var n1 := (d1 + dn * slope).normalized()
		var a0 := a + d0 * ra
		var a1 := a + d1 * ra
		var b0 := b + d0 * rb
		var b1 := b + d1 * rb
		_tri(st, a0, b0, a1, n0, n0, n1, col)
		_tri(st, a1, b0, b1, n1, n0, n1, col)
		if caps:
			_tri(st, a, a0, a1, -dn, -dn, -dn, col)
			if rb > 0.0005:
				_tri(st, b, b1, b0, dn, dn, dn, col)

## Smooth chain of tubes + spheres through points (tails, ponytails, braids, serpents).
static func chain(st: SurfaceTool, pts: Array, radii: Array, seg := 10, sq := Vector2.ONE, col := Color.WHITE, joints := true) -> void:
	for i in range(pts.size() - 1):
		tube(st, pts[i], pts[i + 1], radii[i], radii[i + 1], seg, false, sq, col)
		if joints and radii[i + 1] > 0.002:
			ellipsoid(st, pts[i + 1], Vector3(radii[i + 1] * sq.x, radii[i + 1], radii[i + 1] * sq.y), Basis(), seg, maxi(4, seg / 2), Callable(), col)
	if joints:
		ellipsoid(st, pts[0], Vector3.ONE * radii[0], Basis(), seg, maxi(4, seg / 2), Callable(), col)

static func cone(st: SurfaceTool, base: Vector3, tip: Vector3, r: float, seg := 8, sq := Vector2.ONE, col := Color.WHITE) -> void:
	tube(st, base, tip, r, 0.0, seg, true, sq, col)

static func box(st: SurfaceTool, c: Vector3, size: Vector3, basis := Basis(), col := Color.WHITE) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var o := n * h
		var ea := a * h
		var eb := b * h
		var p0: Vector3 = c + basis * (o - ea - eb)
		var p1: Vector3 = c + basis * (o + ea - eb)
		var p2: Vector3 = c + basis * (o + ea + eb)
		var p3: Vector3 = c + basis * (o - ea + eb)
		var wn: Vector3 = (basis * n).normalized()
		_tri(st, p0, p2, p1, wn, wn, wn, col)
		_tri(st, p0, p3, p2, wn, wn, wn, col)

## Flat double-sided quad strip (capes, fins, wings). pts_a/pts_b are matching edge points.
static func sheet(st: SurfaceTool, pts_a: Array, pts_b: Array, col := Color.WHITE) -> void:
	for i in range(pts_a.size() - 1):
		var a0: Vector3 = pts_a[i]
		var a1: Vector3 = pts_a[i + 1]
		var b0: Vector3 = pts_b[i]
		var b1: Vector3 = pts_b[i + 1]
		var n := (a1 - a0).cross(b0 - a0).normalized()
		_tri(st, a0, b0, a1, n, n, n, col)
		_tri(st, a1, b0, b1, n, n, n, col)
		_tri(st, a0, a1, b0, -n, -n, -n, col)
		_tri(st, a1, b1, b0, -n, -n, -n, col)

## Deformed low-poly rock / boulder.
static func rock(st: SurfaceTool, c: Vector3, r: Vector3, seed: int, col := Color.WHITE) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var k1 := rng.randf_range(2.0, 5.0)
	var k2 := rng.randf_range(2.0, 5.0)
	var amp := rng.randf_range(0.12, 0.25)
	ellipsoid(st, c, r, Basis(Vector3.UP, rng.randf() * TAU), 9, 6, Callable(), col, amp * (0.5 + 0.5 * sin(k1 + k2)))

static func pbr(color: Color, rough := 0.6, metal := 0.0, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m

static func vcol_pbr(rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := pbr(Color.WHITE, rough, metal)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m

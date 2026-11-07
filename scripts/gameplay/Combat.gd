class_name Combat
extends RefCounted
## Analytic hit tests (no physics queries, no per-swing Area3D) - cheap and deterministic.

## Is point p inside an attack shape? fwd must be flat & normalised.
static func in_shape(p: Vector3, shape: String, origin: Vector3, fwd: Vector3, radius: float, angle_deg := 90.0,
		length := 0.0, width := 0.0, inner := 0.0, pad := 0.0) -> bool:
	var d := p - origin
	if absf(d.y) > maxf(radius, 4.0) + 3.0:
		return false
	d.y = 0
	match shape:
		"circle":
			return d.length() <= radius + pad
		"donut":
			var l := d.length()
			return l <= radius + pad and l >= inner - pad
		"cone":
			var l := d.length()
			if l > radius + pad:
				return false
			if l < 0.8:
				return true
			return rad_to_deg(fwd.angle_to(d.normalized())) <= angle_deg * 0.5 + rad_to_deg(atan2(pad, l))
		"line":
			var along := d.dot(fwd)
			var side := absf(d.dot(fwd.cross(Vector3.UP)))
			return along >= -pad and along <= length + pad and side <= width * 0.5 + pad
	return false

## Targets of `faction` hit by a melee cone from `src`.
static func cone_targets(targets: Array, origin: Vector3, fwd: Vector3, reach: float, arc_deg: float) -> Array:
	var out := []
	for t in targets:
		var a := t as Actor
		if a == null or not a.alive:
			continue
		var shape := "circle" if arc_deg >= 359.0 else "cone"
		if in_shape(a.global_position, shape, origin, fwd, reach + a.radius, arc_deg, 0, 0, 0, a.radius * 0.6):
			if absf(a.global_position.y - origin.y) < a.height + 2.0:
				out.append(a)
	return out

static func nearest(targets: Array, from: Vector3, max_dist: float, fwd := Vector3.ZERO, max_angle := 180.0) -> Actor:
	var best: Actor = null
	var bd := max_dist
	for t in targets:
		var a := t as Actor
		if a == null or not a.alive:
			continue
		var d := a.global_position.distance_to(from)
		if d > bd:
			continue
		if fwd != Vector3.ZERO:
			var dir := a.global_position - from
			dir.y = 0
			if dir.length() > 0.5 and rad_to_deg(fwd.angle_to(dir.normalized())) > max_angle:
				continue
		bd = d
		best = a
	return best

static func roll_crit(crit: float) -> bool:
	return randf() < crit

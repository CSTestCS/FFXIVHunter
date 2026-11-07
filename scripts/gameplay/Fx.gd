class_name Fx
extends Node3D
## Effects hub for one world: ground telegraphs, projectiles, area attacks, flashes and damage
## numbers. Projectiles and effects are plain data updated in one loop (no per-object scripts),
## all effects share a single additive material, and number labels are pooled.

const FxShader := preload("res://shaders/fx.gdshader")
const TeleShader := preload("res://shaders/telegraph.gdshader")

var world: Node
var fx_mat: ShaderMaterial
var sphere: SphereMesh
var ring: TorusMesh
var bolt: CapsuleMesh
var effects := []        # {node, t, dur, grow, base_scale, vel}
var projectiles := []    # {node, pos, dir, speed, range, travelled, radius, info, targets, pierce, hit}
var labels: Array[Label3D] = []
var label_i := 0

const COLORS := {
	"fire": Color(1.0, 0.45, 0.15), "ice": Color(0.5, 0.85, 1.0), "lightning": Color(0.75, 0.7, 1.0), "holy": Color(1.0, 0.95, 0.65),
	"dark": Color(0.6, 0.2, 0.9), "arrow": Color(0.9, 0.85, 0.7), "arrows": Color(0.95, 0.85, 0.6), "heal": Color(0.4, 1.0, 0.55),
	"blink": Color(0.6, 0.8, 1.0), "charge": Color(1.0, 0.85, 0.4), "parry": Color(1.0, 0.95, 0.6), "block": Color(0.7, 0.85, 1.0),
	"hit": Color(1.0, 0.8, 0.5), "crit": Color(1.0, 0.5, 0.2), "orb_fall": Color(0.5, 0.9, 1.0), "splash": Color(0.6, 0.85, 1.0),
	"dust": Color(0.9, 0.75, 0.5), "breath": Color(1.0, 0.5, 0.15), "bullet": Color(1.0, 0.85, 0.5), "light": Color(1.0, 0.95, 0.8),
}

func _ready() -> void:
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = FxShader
	sphere = SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	ring = TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 6
	bolt = CapsuleMesh.new()
	bolt.radius = 0.12
	bolt.height = 0.9
	for i in range(16):
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0012
		l.font_size = 36
		l.outline_size = 10
		l.visible = false
		add_child(l)
		labels.append(l)

func _inst(mesh: Mesh, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = fx_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.set_instance_shader_parameter("tint", col)
	return mi

## Generic flash/expanding effect.
func vfx(kind: String, pos: Vector3, size := 1.0, dir := Vector3.ZERO) -> void:
	var col: Color = COLORS.get(kind, Color(1, 0.7, 0.3))
	match kind:
		"heal", "orb_fall", "splash", "dust":
			if kind == "heal":
				Audio.sfx("heal", pos)
			var r := _inst(ring, col)
			r.global_position = pos + Vector3.UP * 0.2
			effects.append({"node": r, "t": 0.0, "dur": 0.7, "grow": size, "base": 0.2})
			var s := _inst(sphere, col)
			s.global_position = pos + Vector3.UP * (0.5 if kind != "orb_fall" else 6.0)
			effects.append({"node": s, "t": 0.0, "dur": 0.6, "grow": size * 0.7, "base": 0.3, "vel": Vector3.DOWN * 10.0 if kind == "orb_fall" else Vector3.UP * 1.5})
		"breath":
			for i in range(10):
				var s := _inst(sphere, col)
				s.global_position = pos
				var d := dir.rotated(Vector3.UP, randf_range(-0.3, 0.3))
				effects.append({"node": s, "t": -i * 0.08, "dur": 0.9, "grow": 2.5, "base": 0.6, "vel": d * size * 1.1})
		"fire", "ice", "lightning", "holy", "dark", "arrows":
			var r := _inst(ring, col)
			r.global_position = pos + Vector3.UP * 0.15
			effects.append({"node": r, "t": 0.0, "dur": 0.6, "grow": size, "base": 0.5})
			var s := _inst(sphere if kind != "lightning" else bolt, col)
			s.global_position = pos + Vector3.UP * (1.0 if kind != "lightning" else 3.0)
			effects.append({"node": s, "t": 0.0, "dur": 0.5, "grow": size * (0.9 if kind != "lightning" else 0.4), "base": 0.4})
		_:
			var s := _inst(sphere, col)
			s.global_position = pos
			effects.append({"node": s, "t": 0.0, "dur": 0.25 if kind in ["hit", "crit", "block"] else 0.45, "grow": size, "base": 0.2})

func number(pos: Vector3, value: int, col: Color) -> void:
	if not Settings.data.show_damage_numbers:
		return
	var l := labels[label_i]
	label_i = (label_i + 1) % labels.size()
	l.text = str(value)
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	l.visible = true
	l.set_meta("t", 0.0)

func projectile(src: Actor, pos: Vector3, dir: Vector3, p: Dictionary, info: Dictionary, targets: Array) -> void:
	var kind: String = p.get("fx", "bullet")
	var col: Color = COLORS.get(kind, COLORS.bullet)
	var mi := _inst(bolt if kind in ["arrow", "bullet"] else sphere, col)
	mi.scale = Vector3.ONE * (float(p.radius) * (1.0 if kind in ["arrow", "bullet"] else 2.0))
	mi.global_position = pos
	if kind in ["arrow", "bullet"]:
		mi.look_at(pos + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	projectiles.append({"node": mi, "pos": pos, "dir": dir.normalized(), "speed": float(p.speed), "range": float(p.range), "travelled": 0.0,
		"radius": float(p.radius), "info": info, "targets": targets, "pierce": p.get("pierce", false), "hit": {}, "kind": kind, "src": src})

func aoe(src: Actor, at: Vector3, radius: float, info: Dictionary, targets: Array, kind: String) -> void:
	vfx(kind, at, radius)
	Audio.sfx({"lightning": "thunder", "arrows": "bow"}.get(kind, kind) if kind in ["fire", "ice", "lightning", "holy", "dark", "arrows"] else "fire", at, 2.0)
	for t in targets:
		var a := t as Actor
		if a and a.alive and Vector2(a.global_position.x - at.x, a.global_position.z - at.z).length() <= radius + a.radius:
			var i := info.duplicate()
			i.dir = (a.global_position - at).normalized()
			var dealt := a.take_hit(i)
			if dealt > 0.0 and src is Player:
				(src as Player)._on_dealt(a, dealt, i)

func telegraph(shape: String, m: Dictionary) -> Telegraph:
	var t := Telegraph.new()
	t.setup(shape, m, TeleShader)
	add_child(t)
	return t

func _process(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e.t += delta
		var n: MeshInstance3D = e.node
		if e.t < 0.0:
			n.visible = false
			continue
		n.visible = true
		var k: float = e.t / e.dur
		if k >= 1.0:
			n.queue_free()
			effects.remove_at(i)
			continue
		var s: float = lerpf(e.base, e.grow, ease(k, 0.4))
		n.scale = Vector3(s, s if n.mesh != ring else 1.0, s)
		if e.has("vel"):
			n.global_position += e.vel * delta
		n.set_instance_shader_parameter("fade", 1.0 - k)
	for l in labels:
		if l.visible:
			var t: float = l.get_meta("t", 0.0) + delta
			l.set_meta("t", t)
			l.global_position.y += delta * 1.2
			l.modulate.a = 1.0 - t / 0.9
			if t > 0.9:
				l.visible = false

func _physics_process(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		var step: float = p.speed * delta
		p.pos += p.dir * step
		p.travelled += step
		var n: MeshInstance3D = p.node
		n.global_position = p.pos
		var done: bool = p.travelled >= p.range
		if world.terrain.height_at(p.pos.x, p.pos.z) > p.pos.y:
			done = true
		for t in p.targets:
			var a := t as Actor
			if a == null or not a.alive or p.hit.has(a):
				continue
			if a.center().distance_to(p.pos) <= p.radius + a.radius + a.height * 0.3:
				p.hit[a] = true
				var info: Dictionary = p.info.duplicate()
				info.dir = p.dir
				var dealt := a.take_hit(info)
				if dealt > 0.0 and p.src is Player and is_instance_valid(p.src):
					(p.src as Player)._on_dealt(a, dealt, info)
				vfx("hit", p.pos, 0.6)
				if not p.pierce:
					done = true
					break
		if done:
			if p.kind in ["fire", "holy", "dark", "ice"]:
				vfx(p.kind, p.pos, 1.2)
				Audio.sfx(p.kind, p.pos, -6.0)
			n.queue_free()
			projectiles.remove_at(i)

class_name Poses
extends RefCounted
## Procedural pose library (no animation files). Poses are humanoid-bone -> Euler degrees in
## character space (forward -Z, right +X, up +Y), applied relative to the VRM T-pose.
## Arms are described as (pitch: 0 = hanging, 90 = forward, 180 = up; yaw: + toward body centre;
## out: sideways lift; bend: elbow). Keys starting with "_" are whole-body extras.

static func arm(side: String, pitch: float, yaw := 0.0, out := 12.0, bend := 10.0) -> Dictionary:
	var s := 1.0 if side == "left" else -1.0
	return {side + "UpperArm": Vector3(pitch, -s * yaw, s * (90.0 - out)), side + "LowerArm": Vector3(0, -s * bend, 0)}

static func leg(side: String, swing: float, knee := 0.0, spread := 0.0) -> Dictionary:
	var s := 1.0 if side == "left" else -1.0
	return {side + "UpperLeg": Vector3(swing, 0, -s * spread), side + "LowerLeg": Vector3(-knee, 0, 0), side + "Foot": Vector3(knee * 0.35 - swing * 0.2, 0, 0)}

static func merge(parts: Array) -> Dictionary:
	var out := {}
	for p in parts:
		for k in p:
			out[k] = p[k]
	return out

# ------------------------------------------------------------------ locomotion
static func idle(t: float, weapon := "") -> Dictionary:
	var br := sin(t * 1.6)
	var p := merge([
		{"spine": Vector3(-1 + br * 0.6, 0, 0), "chest": Vector3(br * 0.8, 0, 0), "neck": Vector3(2, 0, 0), "head": Vector3(-2 + br * 0.5, sin(t * 0.3) * 4.0, 0)},
		arm("left", 4, 0, 12, 12), arm("right", 4, 0, 12, 12),
		leg("left", 0, 2, 2), leg("right", 0, 2, 2),
		{"_hips": Vector3(0, -0.005 + br * 0.003, 0)},
	])
	return _stance(p, weapon, 0.0)

static func move(phase: float, speed: float, t: float, weapon := "") -> Dictionary:
	# speed: 0 idle .. 1 walk .. 2 run .. 3 sprint
	var k := clampf(speed, 0.0, 3.0)
	var sw := lerpf(22.0, 38.0, clampf(k - 1.0, 0.0, 1.0)) + maxf(0.0, k - 2.0) * 10.0
	var s := sin(phase)
	var c := cos(phase)
	var knee_l := 8.0 + maxf(0.0, -c) * lerpf(35.0, 85.0, clampf(k - 1.0, 0.0, 1.0)) + maxf(0.0, s) * 10.0
	var knee_r := 8.0 + maxf(0.0, c) * lerpf(35.0, 85.0, clampf(k - 1.0, 0.0, 1.0)) + maxf(0.0, -s) * 10.0
	var armsw := sw * lerpf(0.6, 1.1, clampf(k - 1.0, 0.0, 1.0))
	var bend := lerpf(15.0, 80.0, clampf(k - 1.0, 0.0, 1.0))
	var lean := -lerpf(3.0, 14.0, clampf(k - 1.0, 0.0, 1.0)) - maxf(0.0, k - 2.0) * 6.0
	var p := merge([
		{"spine": Vector3(lean, s * 6.0, 0), "chest": Vector3(-2, -s * 8.0, 0), "neck": Vector3(0, s * 3.0, 0), "head": Vector3(-lean * 0.6, 0, 0)},
		arm("left", -s * armsw + 6, 0, 10, bend), arm("right", s * armsw + 6, 0, 10, bend),
		leg("left", s * sw, knee_l), leg("right", -s * sw, knee_r),
		{"_hips": Vector3(0, -absf(sin(phase * 2.0 + 0.4)) * 0.025 * k - 0.01 * k, 0)},
	])
	if k > 0.0 and k <= 1.0:
		p = blend(idle(t, weapon), p, k)
	return _stance(p, weapon, clampf(k - 1.5, 0.0, 1.0))

static func swim(phase: float, moving: float, t: float) -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	var p := merge([
		{"spine": Vector3(4, s * 8.0 * moving, 0), "chest": Vector3(4, 0, 0), "neck": Vector3(-28 * moving, 0, 0), "head": Vector3(-25 * moving, 0, 0)},
		arm("left", lerpf(60.0, 150.0 + s * 30.0, moving), 10, lerpf(50.0, 20.0, moving), 30 + 30 * maxf(0.0, c)),
		arm("right", lerpf(60.0, 150.0 - s * 30.0, moving), 10, lerpf(50.0, 20.0, moving), 30 + 30 * maxf(0.0, -c)),
		leg("left", sin(phase * 2.0) * 18.0 * moving - 10.0 * (1.0 - moving) + sin(t * 2.0) * 10.0, 15),
		leg("right", -sin(phase * 2.0) * 18.0 * moving + 10.0 * (1.0 - moving) - sin(t * 2.0) * 10.0, 15),
		{"_pitch": -78.0 * moving, "_hips": Vector3(0, 0, 0)},
	])
	return p

static func airborne(vy: float) -> Dictionary:
	var up := clampf(vy / 5.0, -1.0, 1.0)
	return merge([
		{"spine": Vector3(-6, 0, 0), "head": Vector3(4, 0, 0)},
		arm("left", 30 + up * 20.0, 0, 30, 40), arm("right", 30 + up * 20.0, 0, 30, 40),
		leg("left", 35 + up * 10.0, 60), leg("right", -5 + up * 10.0, 30),
	])

static func roll(k: float) -> Dictionary:
	var curl := sin(clampf(k, 0, 1) * PI)
	return merge([
		{"spine": Vector3(-40 * curl, 0, 0), "chest": Vector3(-20 * curl, 0, 0), "head": Vector3(-30 * curl, 0, 0)},
		arm("left", 60 * curl, 30 * curl, 10, 90 * curl), arm("right", 60 * curl, 30 * curl, 10, 90 * curl),
		leg("left", 100 * curl, 130 * curl), leg("right", 90 * curl, 130 * curl),
		{"_roll": clampf(k, 0.0, 1.0), "_hips": Vector3(0, -0.35 * curl, 0)},
	])

static func step(k: float) -> Dictionary:
	var e := sin(clampf(k, 0, 1) * PI)
	return merge([
		{"spine": Vector3(-14 * e, 0, 0)},
		arm("left", 30 * e, 10, 30 * e + 10, 50), arm("right", 30 * e, 10, 30 * e + 10, 50),
		leg("left", 30 * e, 40 * e), leg("right", -20 * e, 20 * e), {"_hips": Vector3(0, -0.12 * e, 0)},
	])

static func hurt(k: float) -> Dictionary:
	var e := sin(clampf(k, 0, 1) * PI)
	return merge([
		{"spine": Vector3(14 * e, 0, 0), "chest": Vector3(8 * e, 0, 0), "head": Vector3(16 * e, 0, 0)},
		arm("left", 25 * e, 0, 30 * e + 12, 40), arm("right", 25 * e, 0, 30 * e + 12, 40),
		leg("left", -8 * e, 20 * e), leg("right", 12 * e, 30 * e),
	])

static func knockdown(k: float) -> Dictionary:
	# 0..0.35 fall back, 0.35..0.75 lie, 0.75..1 get up
	var fall := smoothstep(0.0, 0.35, k) * (1.0 - smoothstep(0.75, 1.0, k))
	return merge([
		{"spine": Vector3(10 * fall, 0, 0), "head": Vector3(-10 * fall, 0, 0)},
		arm("left", 40 * fall, 0, 40 * fall + 12, 30), arm("right", 40 * fall, 0, 40 * fall + 12, 30),
		leg("left", 20 * fall, 30 * fall), leg("right", 5 * fall, 10 * fall),
		{"_lie": fall},
	])

static func lying(t: float) -> Dictionary:
	var br := sin(t * 1.1)
	return merge([
		{"spine": Vector3(4, 0, 0), "chest": Vector3(br, 0, 0), "head": Vector3(-6, 22, 0)},
		arm("left", 10, 0, 45, 25), arm("right", 30, -20, 25, 70), leg("left", 8, 14), leg("right", 24, 50, 6),
		{"_lie": 1.0},
	])

static func sit(t: float) -> Dictionary:
	return merge([
		{"spine": Vector3(-4 + sin(t * 1.5), 0, 0), "head": Vector3(4, 0, 0)},
		arm("left", 35, 20, 8, 70), arm("right", 35, 20, 8, 70), leg("left", 85, 90), leg("right", 85, 90),
		{"_hips": Vector3(0, -0.42, 0.05)},
	])

static func talk(t: float) -> Dictionary:
	var g := sin(t * 2.3)
	return merge([idle(t), arm("right", 30 + g * 12.0, 25, 15, 70 + g * 15.0), {"head": Vector3(-2, sin(t * 0.9) * 8.0, g * 2.0)}])

static func wave(t: float) -> Dictionary:
	return merge([idle(t), arm("right", 150, 0, 40, 40 + sin(t * 9.0) * 25.0)])

static func cheer(t: float) -> Dictionary:
	return merge([idle(t), arm("right", 165, 0, 20, 10), arm("left", 165, 0, 20, 10), {"_hips": Vector3(0, absf(sin(t * 6.0)) * 0.06, 0)}])

static func kneel(t: float) -> Dictionary:
	return merge([
		{"spine": Vector3(-14, 0, 0), "head": Vector3(-8, 0, 0)},
		arm("left", 50, 20, 10, 80), arm("right", 40, 0, 15, 30), leg("left", 90, 90), leg("right", -10, 110),
		{"_hips": Vector3(0, -0.45, 0)},
	])

# ------------------------------------------------------------------ weapon stances
static func _stance(p: Dictionary, weapon: String, sprint: float) -> Dictionary:
	if weapon == "" or sprint > 0.5:
		return p
	var hold := {}
	match weapon:
		"sword_shield": hold = merge([arm("right", 28, 0, 12, 35), arm("left", 42, 25, 12, 70)])
		"greatsword", "greataxe", "scythe": hold = merge([arm("right", 35, 18, 10, 45), arm("left", 45, 40, 6, 55), {"chest": Vector3(0, -12, 0)}])
		"lance": hold = merge([arm("right", 30, 5, 10, 70), arm("left", 55, 30, 8, 45)])
		"katana": hold = merge([arm("right", 30, 20, 8, 50), arm("left", 34, 35, 6, 55)])
		"daggers": hold = merge([arm("right", 32, 0, 18, 75), arm("left", 32, 0, 18, 75)])
		"fists": hold = merge([arm("right", 48, 22, 15, 115), arm("left", 52, 22, 15, 115)])
		"bow": hold = merge([arm("left", 18, 0, 14, 20)])
		"gun": hold = merge([arm("right", 22, 0, 10, 60), arm("left", 48, 35, 8, 70)])
		"staff", "cane": hold = merge([arm("right", 24, 0, 14, 60)])
	var out := p.duplicate()
	for key in hold:
		out[key] = hold[key]
	return out

static func guard(weapon: String) -> Dictionary:
	var base := idle(0.0)
	match weapon:
		"sword_shield": return merge([base, arm("left", 82, 32, 8, 80), arm("right", 40, 0, 15, 70), leg("left", 15, 25), leg("right", -10, 20), {"spine": Vector3(-6, 0, 0), "_hips": Vector3(0, -0.06, 0)}])
		"lance": return merge([base, arm("left", 85, 30, 6, 60), arm("right", 55, 10, 10, 90), leg("left", 15, 25), leg("right", -10, 20), {"_hips": Vector3(0, -0.08, 0)}])
		_: return merge([base, arm("right", 75, 40, 10, 60), arm("left", 75, 55, 5, 70), leg("left", 15, 25), leg("right", -10, 20), {"_hips": Vector3(0, -0.08, 0)}])

# ------------------------------------------------------------------ attacks: [windup, strike, follow]
static var _key_cache := {}

static func attack_keys(anim: String) -> Array:
	if not _key_cache.has(anim):
		_key_cache[anim] = _build_attack_keys(anim)
	return _key_cache[anim]

static func _build_attack_keys(anim: String) -> Array:
	match anim:
		"slash_r":
			return [merge([{"spine": Vector3(-4, -30, 0), "chest": Vector3(0, -20, 0)}, arm("right", 85, -75, 15, 45), arm("left", 30, 20, 15, 40), leg("left", 18, 20), leg("right", -10, 15)]),
				merge([{"spine": Vector3(-8, 25, 0), "chest": Vector3(0, 20, 0)}, arm("right", 88, 35, 10, 8), arm("left", 25, 0, 20, 30), leg("left", 25, 30), leg("right", -15, 10)]),
				merge([{"spine": Vector3(-8, 35, 0), "chest": Vector3(0, 25, 0)}, arm("right", 70, 75, 10, 30), arm("left", 25, 0, 25, 30), leg("left", 25, 30), leg("right", -15, 10)])]
		"slash_l":
			return [merge([{"spine": Vector3(-4, 30, 0), "chest": Vector3(0, 20, 0)}, arm("right", 85, 70, 5, 85), arm("left", 25, 0, 20, 30), leg("left", 10, 15), leg("right", 10, 15)]),
				merge([{"spine": Vector3(-8, -25, 0), "chest": Vector3(0, -20, 0)}, arm("right", 88, -40, 15, 10), arm("left", 25, 0, 25, 30), leg("left", 25, 30), leg("right", -15, 10)]),
				merge([{"spine": Vector3(-8, -35, 0), "chest": Vector3(0, -25, 0)}, arm("right", 75, -80, 20, 25), arm("left", 20, 0, 25, 30), leg("left", 25, 30), leg("right", -15, 10)])]
		"overhead":
			return [merge([{"spine": Vector3(10, -10, 0), "chest": Vector3(8, 0, 0)}, arm("right", 170, 10, 10, 70), arm("left", 40, 20, 15, 40), leg("left", 10, 10), leg("right", -5, 10)]),
				merge([{"spine": Vector3(-22, 5, 0), "chest": Vector3(-10, 0, 0)}, arm("right", 75, 10, 10, 5), arm("left", 20, 0, 20, 30), leg("left", 35, 45), leg("right", -20, 15), {"_hips": Vector3(0, -0.1, 0)}]),
				merge([{"spine": Vector3(-26, 5, 0), "chest": Vector3(-12, 0, 0)}, arm("right", 40, 10, 10, 15), arm("left", 20, 0, 20, 30), leg("left", 35, 45), leg("right", -20, 15), {"_hips": Vector3(0, -0.12, 0)}])]
		"upper":
			return [merge([{"spine": Vector3(-18, -15, 0)}, arm("right", 15, -25, 15, 25), arm("left", 35, 20, 15, 50), leg("left", 30, 50), leg("right", -10, 30), {"_hips": Vector3(0, -0.12, 0)}]),
				merge([{"spine": Vector3(8, 10, 0)}, arm("right", 165, 10, 10, 20), arm("left", 25, 0, 20, 40), leg("left", 10, 10), leg("right", -5, 5)]),
				merge([{"spine": Vector3(10, 10, 0)}, arm("right", 160, 15, 15, 35), arm("left", 25, 0, 20, 40), leg("left", 10, 10), leg("right", -5, 5)])]
		"thrust":
			return [merge([{"spine": Vector3(-4, -25, 0)}, arm("right", 75, -10, 10, 100), arm("left", 70, 30, 8, 70), leg("left", 15, 25), leg("right", -10, 15)]),
				merge([{"spine": Vector3(-16, 12, 0)}, arm("right", 90, 0, 8, 0), arm("left", 85, 20, 6, 25), leg("left", 40, 45), leg("right", -25, 10), {"_hips": Vector3(0, -0.1, 0)}]),
				merge([{"spine": Vector3(-14, 10, 0)}, arm("right", 88, 0, 8, 10), arm("left", 80, 20, 6, 30), leg("left", 38, 45), leg("right", -25, 10), {"_hips": Vector3(0, -0.1, 0)}])]
		"slam_2h", "charge_2h":
			var deep := 1.3 if anim == "charge_2h" else 1.0
			return [merge([{"spine": Vector3(12 * deep, -10, 0), "chest": Vector3(8, -5, 0)}, arm("right", 168, 15, 8, 55 * deep), arm("left", 165, 30, 5, 60 * deep), leg("left", 15, 20 * deep), leg("right", -10, 15 * deep), {"_hips": Vector3(0, -0.06 * deep, 0)}]),
				merge([{"spine": Vector3(-32, 5, 0), "chest": Vector3(-12, 0, 0)}, arm("right", 62, 20, 5, 8), arm("left", 60, 40, 4, 12), leg("left", 45, 55), leg("right", -25, 20), {"_hips": Vector3(0, -0.18, 0)}]),
				merge([{"spine": Vector3(-36, 5, 0), "chest": Vector3(-14, 0, 0)}, arm("right", 38, 20, 5, 15), arm("left", 36, 40, 4, 18), leg("left", 45, 55), leg("right", -25, 20), {"_hips": Vector3(0, -0.2, 0)}])]
		"sweep_2h", "scythe_reap":
			return [merge([{"spine": Vector3(-6, -55, 0), "chest": Vector3(0, -25, 0)}, arm("right", 80, -60, 10, 30), arm("left", 75, -25, 10, 40), leg("left", 15, 25), leg("right", -10, 20), {"_hips": Vector3(0, -0.06, 0)}]),
				merge([{"spine": Vector3(-12, 35, 0), "chest": Vector3(0, 20, 0)}, arm("right", 85, 40, 10, 10), arm("left", 80, 70, 8, 20), leg("left", 30, 35), leg("right", -15, 15), {"_hips": Vector3(0, -0.1, 0)}]),
				merge([{"spine": Vector3(-12, 60, 0), "chest": Vector3(0, 25, 0)}, arm("right", 70, 80, 10, 25), arm("left", 70, 95, 8, 30), leg("left", 30, 35), leg("right", -15, 15), {"_hips": Vector3(0, -0.1, 0)}])]
		"spin":
			return [merge([{"spine": Vector3(-8, -45, 0)}, arm("right", 85, -40, 25, 20), arm("left", 80, -10, 20, 30), leg("left", 20, 30), leg("right", -10, 20), {"_hips": Vector3(0, -0.1, 0)}]),
				merge([{"spine": Vector3(-10, 10, 0)}, arm("right", 88, -10, 30, 5), arm("left", 85, 30, 25, 15), leg("left", 20, 30), leg("right", -10, 20), {"_hips": Vector3(0, -0.12, 0), "_spin": 1.0}]),
				merge([{"spine": Vector3(-10, 30, 0)}, arm("right", 75, 50, 20, 20), arm("left", 70, 60, 20, 25), leg("left", 20, 30), leg("right", -10, 20), {"_hips": Vector3(0, -0.1, 0)}])]
		"shield_bash":
			return [merge([{"spine": Vector3(-4, 25, 0)}, arm("left", 70, 50, 10, 90), arm("right", 30, 0, 15, 50), leg("left", 10, 20), leg("right", -5, 15)]),
				merge([{"spine": Vector3(-16, -10, 0)}, arm("left", 92, 10, 10, 15), arm("right", 25, 0, 20, 40), leg("left", 40, 45), leg("right", -25, 10), {"_hips": Vector3(0, -0.08, 0)}]),
				merge([{"spine": Vector3(-14, -10, 0)}, arm("left", 88, 10, 10, 25), arm("right", 25, 0, 20, 40), leg("left", 38, 45), leg("right", -25, 10), {"_hips": Vector3(0, -0.08, 0)}])]
		"guard":
			return [guard("sword_shield"), guard("sword_shield"), guard("sword_shield")]
		"punch_r", "flurry":
			return [merge([{"spine": Vector3(-6, -22, 0)}, arm("right", 55, 15, 15, 125), arm("left", 55, 25, 15, 110), leg("left", 20, 25), leg("right", -10, 20), {"_hips": Vector3(0, -0.06, 0)}]),
				merge([{"spine": Vector3(-12, 25, 0)}, arm("right", 90, 15, 8, 0), arm("left", 50, 25, 15, 115), leg("left", 30, 35), leg("right", -15, 15), {"_hips": Vector3(0, -0.08, 0)}]),
				merge([{"spine": Vector3(-12, 25, 0)}, arm("right", 88, 15, 8, 10), arm("left", 50, 25, 15, 115), leg("left", 30, 35), leg("right", -15, 15), {"_hips": Vector3(0, -0.08, 0)}])]
		"punch_l":
			return [merge([{"spine": Vector3(-6, 22, 0)}, arm("left", 55, 15, 15, 125), arm("right", 55, 25, 15, 110), leg("left", 20, 25), leg("right", -10, 20), {"_hips": Vector3(0, -0.06, 0)}]),
				merge([{"spine": Vector3(-12, -25, 0)}, arm("left", 90, 15, 8, 0), arm("right", 50, 25, 15, 115), leg("left", 30, 35), leg("right", -15, 15), {"_hips": Vector3(0, -0.08, 0)}]),
				merge([{"spine": Vector3(-12, -25, 0)}, arm("left", 88, 15, 8, 10), arm("right", 50, 25, 15, 115), leg("left", 30, 35), leg("right", -15, 15), {"_hips": Vector3(0, -0.08, 0)}])]
		"kick":
			return [merge([{"spine": Vector3(6, 15, 0)}, arm("right", 40, 20, 25, 90), arm("left", 40, 20, 25, 90), leg("right", 45, 95), leg("left", -5, 15)]),
				merge([{"spine": Vector3(14, 25, -10)}, arm("right", 20, 0, 45, 60), arm("left", 50, 20, 30, 90), leg("right", 100, 5), leg("left", -10, 15)]),
				merge([{"spine": Vector3(10, 20, -6)}, arm("right", 25, 0, 40, 60), arm("left", 45, 20, 30, 90), leg("right", 70, 30), leg("left", -10, 15)])]
		"dash_slash":
			return [merge([{"spine": Vector3(-25, 20, 0)}, arm("right", 60, 70, 10, 50), arm("left", 60, -40, 25, 50), leg("left", 45, 70), leg("right", -20, 40), {"_hips": Vector3(0, -0.2, 0)}]),
				merge([{"spine": Vector3(-25, -30, 0)}, arm("right", 85, -80, 15, 5), arm("left", 70, 60, 15, 20), leg("left", 50, 60), leg("right", -30, 30), {"_hips": Vector3(0, -0.22, 0)}]),
				merge([{"spine": Vector3(-20, -35, 0)}, arm("right", 75, -95, 20, 15), arm("left", 60, 60, 15, 30), leg("left", 45, 55), leg("right", -25, 30), {"_hips": Vector3(0, -0.18, 0)}])]
		"iai":
			return [merge([{"spine": Vector3(-14, 32, 0)}, arm("right", 25, 55, 5, 75), arm("left", 20, 25, 8, 45), leg("left", 35, 55), leg("right", -20, 35), {"_hips": Vector3(0, -0.2, 0)}]),
				merge([{"spine": Vector3(-16, -40, 0)}, arm("right", 88, -85, 15, 0), arm("left", 25, 30, 10, 45), leg("left", 45, 55), leg("right", -25, 30), {"_hips": Vector3(0, -0.22, 0)}]),
				merge([{"spine": Vector3(-14, -45, 0)}, arm("right", 105, -110, 25, 10), arm("left", 25, 30, 10, 45), leg("left", 45, 55), leg("right", -25, 30), {"_hips": Vector3(0, -0.2, 0)}])]
		"cast":
			return [merge([{"spine": Vector3(4, -10, 0)}, arm("right", 110, 10, 15, 60), arm("left", 60, 20, 20, 50), leg("left", 10, 10), leg("right", -5, 10)]),
				merge([{"spine": Vector3(-8, 8, 0)}, arm("right", 95, 0, 10, 5), arm("left", 40, 15, 25, 40), leg("left", 15, 15), leg("right", -10, 10)]),
				merge([{"spine": Vector3(-6, 8, 0)}, arm("right", 90, 0, 10, 15), arm("left", 40, 15, 25, 40), leg("left", 15, 15), leg("right", -10, 10)])]
		"cast_big":
			return [merge([{"spine": Vector3(14, 0, 0), "head": Vector3(10, 0, 0)}, arm("right", 160, -10, 35, 25), arm("left", 160, -10, 35, 25), leg("left", 10, 10, 6), leg("right", -5, 10, 6), {"_hips": Vector3(0, -0.04, 0)}]),
				merge([{"spine": Vector3(-14, 0, 0)}, arm("right", 92, 15, 15, 0), arm("left", 92, 15, 15, 0), leg("left", 30, 35), leg("right", -20, 15), {"_hips": Vector3(0, -0.1, 0)}]),
				merge([{"spine": Vector3(-10, 0, 0)}, arm("right", 85, 15, 15, 15), arm("left", 85, 15, 15, 15), leg("left", 30, 35), leg("right", -20, 15), {"_hips": Vector3(0, -0.08, 0)}])]
		"heal":
			return [merge([{"spine": Vector3(-4, 0, 0)}, arm("right", 100, 25, 25, 50), arm("left", 100, 25, 25, 50)]),
				merge([{"spine": Vector3(12, 0, 0), "head": Vector3(14, 0, 0)}, arm("right", 160, -10, 45, 15), arm("left", 160, -10, 45, 15)]),
				merge([{"spine": Vector3(10, 0, 0), "head": Vector3(10, 0, 0)}, arm("right", 150, -10, 45, 20), arm("left", 150, -10, 45, 20)])]
		"bow_draw":
			return [merge([{"spine": Vector3(-2, -35, 0), "head": Vector3(0, 30, 0)}, arm("left", 88, -30, 5, 0), arm("right", 90, 25, 5, 140), leg("left", 15, 15, 8), leg("right", -10, 10, 8)]),
				merge([{"spine": Vector3(-2, -35, 0), "head": Vector3(0, 30, 0)}, arm("left", 88, -30, 5, 0), arm("right", 85, -30, 15, 165), leg("left", 15, 15, 8), leg("right", -10, 10, 8)]),
				merge([{"spine": Vector3(-2, -30, 0), "head": Vector3(0, 25, 0)}, arm("left", 80, -25, 5, 5), arm("right", 75, -50, 25, 150), leg("left", 15, 15, 8), leg("right", -10, 10, 8)])]
		"gun_fire":
			return [merge([{"spine": Vector3(-4, -20, 0), "head": Vector3(-4, 18, 0)}, arm("right", 88, 5, 5, 25), arm("left", 92, 35, 3, 45), leg("left", 15, 15, 6), leg("right", -10, 10, 6)]),
				merge([{"spine": Vector3(6, -20, 0), "head": Vector3(2, 18, 0)}, arm("right", 98, 5, 5, 35), arm("left", 100, 35, 3, 55), leg("left", 15, 15, 6), leg("right", -10, 10, 6)]),
				merge([{"spine": Vector3(0, -20, 0), "head": Vector3(-2, 18, 0)}, arm("right", 90, 5, 5, 28), arm("left", 94, 35, 3, 48), leg("left", 15, 15, 6), leg("right", -10, 10, 6)])]
		"reload":
			var r := merge([{"spine": Vector3(-14, 0, 0), "head": Vector3(-20, 0, 0)}, arm("right", 50, 30, 10, 100), arm("left", 55, 35, 10, 90)])
			return [r, r, r]
		"leap_strike":
			return [merge([{"spine": Vector3(-25, 0, 0)}, arm("right", 140, 10, 15, 60), arm("left", 120, 30, 10, 60), leg("left", 70, 110), leg("right", 60, 110), {"_hips": Vector3(0, -0.35, 0)}]),
				merge([{"spine": Vector3(-30, 0, 0)}, arm("right", 60, 10, 10, 0), arm("left", 70, 30, 10, 20), leg("left", 50, 60), leg("right", -10, 40)]),
				merge([{"spine": Vector3(-30, 0, 0)}, arm("right", 40, 10, 10, 10), arm("left", 50, 30, 10, 30), leg("left", 70, 90), leg("right", -10, 80), {"_hips": Vector3(0, -0.3, 0)}])]
	return [idle(0), idle(0), idle(0)]

## Pose for an attack at a phase. phase: 0 startup, 1 active, 2 recovery; k: 0..1 within phase.
static func attack(anim: String, phase: int, k: float, ready: Dictionary) -> Dictionary:
	var keys := attack_keys(anim)
	if anim == "flurry" and phase == 1:
		var alt := fmod(k * 7.0, 1.0)
		var a := attack_keys("punch_r") if int(k * 7.0) % 2 == 0 else attack_keys("punch_l")
		return blend(a[0], a[1], smoothstep(0.0, 0.5, alt))
	match phase:
		0: return blend(ready, keys[0], ease(clampf(k, 0, 1), 0.5))
		1:
			if k < 0.45:
				return blend(keys[0], keys[1], smoothstep(0.0, 0.45, k))
			return blend(keys[1], keys[2], smoothstep(0.45, 1.0, k))
		_: return blend(keys[2], ready, smoothstep(0.0, 1.0, k))

## Linear blend of two pose dictionaries (Euler space; fine for the moderate angles used here).
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		out[k] = a[k]
	for k in b:
		var av = a.get(k, null)
		var bv = b[k]
		if av == null:
			av = Vector3.ZERO if bv is Vector3 else 0.0
		out[k] = lerp(av, bv, t)
	for k in a:
		if not b.has(k):
			var av = a[k]
			out[k] = lerp(av, Vector3.ZERO if av is Vector3 else 0.0, t)
	return out

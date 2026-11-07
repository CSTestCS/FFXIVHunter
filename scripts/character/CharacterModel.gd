class_name CharacterModel
extends Node3D
## A humanoid character built from a VRM file at runtime.
##
## Model lookup order (first file found wins) in each CustomModels folder
## (next to the .exe, then %APPDATA%/AetherHunter/CustomModels):
##   outfits/<race>_<body>_<outfit>.vrm  -> full model wearing that outfit (VRoid export)
##   outfits/<outfit>_<body>.vrm         -> same, any race
##   bodies/<race>_<body>.vrm            -> race-specific base body (race ears/tails assumed included)
##   bodies/<body>.vrm                   -> base body for every race
## Otherwise the bundled placeholder (models/placeholder/body_<body>.vrm) is used.
## See docs/CUSTOM_MODELS.md for the full guide.

const BodyShader := preload("res://shaders/placeholder_body.gdshader")
const REGION_KEYS := ["head", "neck", "torso", "uarm", "larm", "hand", "pelvis", "thigh", "shin", "foot", "bust"]
const RacesData := preload("res://scripts/data/races.gd")

static var _templates := {}

var look: Dictionary = {}
var outfit := "none"
var visual: Node3D
var model: Node3D
var skel: Skeleton3D
var anim: HumanoidAnimator
var bone_map := {}
var skel_to_char := Transform3D()
var placeholder := true
var race_parts_included := false
var meshes: Array[MeshInstance3D] = []
var body_mat: ShaderMaterial
var unit := 1.0              # model scale factor (head height / placeholder head height)
var height_m := 1.65
var weapon_kind := ""
var weapon_tier := 0
var sheathed := false
var _weapon_nodes: Array[Node3D] = []
var _armor_nodes: Array[Node3D] = []
var _sockets := {}
var _tail: Node3D
var _eyes: Array[Node3D] = []
var _t := 0.0
var _extras := {"_lie": 0.0, "_roll": 0.0, "_pitch": 0.0, "_spin": 0.0}
var _blink := 3.0
var _vis_scale := 1.0

func build(p_look: Dictionary, p_outfit := "none", p_weapon := "", p_tier := 0) -> void:
	look = p_look
	outfit = p_outfit
	weapon_kind = p_weapon
	weapon_tier = p_tier
	for c in get_children():
		c.queue_free()
	_sockets.clear()
	_weapon_nodes.clear()
	_armor_nodes.clear()
	_eyes.clear()
	meshes.clear()
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var path := _pick_model_path()
	var tpl := _load_template(path)
	if tpl == null:
		tpl = _load_template(_placeholder_path())
	model = tpl.duplicate() as Node3D
	visual.add_child(model)
	var sk := model.find_children("*", "Skeleton3D", true, false)
	skel = sk[0] if sk.size() > 0 else null
	if skel == null:
		push_error("Model has no skeleton: " + path)
		return
	for m in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m)
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	bone_map = HumanoidAnimator.build_map(skel, tpl.get_meta("vrm_bones", {}))
	skel_to_char = _relative_xform(skel, visual)
	# Face -Z like every other node in the game (VRM 1.0 / some exporters face +Z).
	if bone_map.has("leftToes") and bone_map.has("leftFoot"):
		var toe := (skel_to_char * skel.get_bone_global_rest(bone_map.leftToes)).origin
		var foot := (skel_to_char * skel.get_bone_global_rest(bone_map.leftFoot)).origin
		if toe.z > foot.z:
			model.rotate_y(PI)
			skel_to_char = _relative_xform(skel, visual)
	elif tpl.get_meta("vrm_version", 0) == 1:
		model.rotate_y(PI)
		skel_to_char = _relative_xform(skel, visual)
	anim = HumanoidAnimator.new()
	anim.setup(skel, bone_map, skel_to_char)
	var head_y := 1.445
	if bone_map.has("head"):
		head_y = (skel_to_char * skel.get_bone_global_rest(bone_map.head)).origin.y
	unit = head_y / 1.445
	var base_h := head_y + 0.19 * unit
	height_m = RacesData.height_cm(look) / 100.0
	_vis_scale = height_m / base_h
	visual.scale = Vector3.ONE * _vis_scale
	if bone_map.has("head"):
		var hs: float = DB.races.get(look.race, {}).get("head_scale", 1.0)
		skel.set_bone_pose_scale(bone_map.head, Vector3.ONE * hs)
	_apply_materials()
	_apply_morphs()
	if placeholder:
		_add_face()
	if placeholder:
		_add_hair()
	if not race_parts_included:
		_add_race_parts()
	_build_armor_parts()
	_build_weapon()

# ------------------------------------------------------------------ model loading
static func custom_dirs() -> Array:
	var dirs := []
	if not OS.has_feature("editor"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join("CustomModels"))
	dirs.append(ProjectSettings.globalize_path("user://CustomModels"))
	return dirs

static func find_custom(candidates: Array) -> String:
	for d in custom_dirs():
		for c in candidates:
			var p: String = d.path_join(c)
			if FileAccess.file_exists(p):
				return p
	return ""

func _placeholder_path() -> String:
	return "res://models/placeholder/body_%s.vrm" % look.get("body", "feminine")

func _pick_model_path() -> String:
	var race: String = look.get("race", "hume")
	var body: String = look.get("body", "feminine")
	placeholder = false
	race_parts_included = false
	var p := find_custom(["outfits/%s_%s_%s.vrm" % [race, body, outfit]])
	if p != "":
		race_parts_included = true
		return p
	p = find_custom(["outfits/%s_%s.vrm" % [outfit, body]])
	if p != "":
		return p
	p = find_custom(["bodies/%s_%s.vrm" % [race, body]])
	if p != "":
		race_parts_included = true
		return p
	p = find_custom(["bodies/%s.vrm" % body])
	if p != "":
		return p
	placeholder = true
	return _placeholder_path()

static func _load_template(path: String) -> Node3D:
	if _templates.has(path):
		return _templates[path]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	if err != OK:
		push_warning("Could not load model %s (error %d)" % [path, err])
		_templates[path] = null
		return null
	var scene := doc.generate_scene(st) as Node3D
	# VRM humanoid bone mapping (0.x: extensions.VRM, 1.0: extensions.VRMC_vrm)
	var names := {}
	var js: Dictionary = st.json
	var nodes: Array = js.get("nodes", [])
	var ext: Dictionary = js.get("extensions", {})
	var version := 0
	if ext.has("VRM"):
		for hb in ext.VRM.get("humanoid", {}).get("humanBones", []):
			var ni := int(hb.get("node", -1))
			if ni >= 0 and ni < nodes.size():
				names[hb.bone] = String(nodes[ni].get("name", ""))
	elif ext.has("VRMC_vrm"):
		version = 1
		var hbs: Dictionary = ext.VRMC_vrm.get("humanoid", {}).get("humanBones", {})
		for b in hbs:
			var ni := int(hbs[b].get("node", -1))
			if ni >= 0 and ni < nodes.size():
				names[b] = String(nodes[ni].get("name", ""))
	scene.set_meta("vrm_bones", names)
	scene.set_meta("vrm_version", version)
	_templates[path] = scene
	return scene

static func _relative_xform(node: Node3D, root: Node) -> Transform3D:
	var x := Transform3D()
	var n: Node = node
	while n and n != root:
		if n is Node3D:
			x = (n as Node3D).transform * x
		n = n.get_parent()
	return x

# ------------------------------------------------------------------ materials
func _apply_materials() -> void:
	var skin := RacesData.skin_color(look)
	if placeholder:
		body_mat = ShaderMaterial.new()
		body_mat.shader = BodyShader
		body_mat.set_shader_parameter("skin_color", skin)
		body_mat.set_shader_parameter("lip_color", Color(look.get("lip_color", "#b46a6a")))
		body_mat.set_shader_parameter("marking", int(look.get("marking", 0)))
		body_mat.set_shader_parameter("marking_color", Color(look.get("marking_color", "#a3241e")))
		body_mat.set_shader_parameter("scales", 1.0 if look.get("race", "") == "draeki" else 0.0)
		body_mat.set_shader_parameter("scale_tint", Color(look.get("scale_color", "#6b4a2a")))
		if bone_map.has("head"):
			var hb := skel.get_bone_global_rest(bone_map.head).origin
			body_mat.set_shader_parameter("head_center", hb + Vector3(0, 0.095, -0.008) * unit)
		_apply_outfit_colors()
		for m in meshes:
			m.material_override = body_mat
	else:
		# Custom VRoid model: keep its textures, tint by VRoid material naming, make it PBR.
		for m in meshes:
			for si in range(m.mesh.get_surface_count()):
				var mat := m.get_active_material(si)
				if mat is BaseMaterial3D:
					var nm := (mat.resource_name as String).to_upper()
					var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					dup.roughness = maxf(dup.roughness, 0.55)
					dup.metallic = 0.0
					if "HAIR" in nm:
						dup.albedo_color = Color(look.get("hair_color", "#ffffff")).lightened(0.25)
					elif "SKIN" in nm or "FACE" in nm or "BODY" in nm:
						dup.albedo_color = skin.lightened(0.15)
					elif "IRIS" in nm or "EYE_IRIS" in nm:
						dup.albedo_color = Color(look.get("eye_color", "#ffffff")).lightened(0.3)
					if dup.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						dup.alpha_scissor_threshold = 0.5
					m.set_surface_override_material(si, dup)

func _apply_outfit_colors() -> void:
	if not body_mat:
		return
	var a: Dictionary = DB.armor.get(outfit, DB.armor.none)
	var cols: Dictionary = a.colors
	var arr := PackedVector4Array()
	for k in REGION_KEYS:
		var c: String = cols.get(k, "")
		if c == "":
			arr.append(Vector4(0, 0, 0, 0))
		else:
			var col := Color(c).srgb_to_linear()
			arr.append(Vector4(col.r, col.g, col.b, 1.0))
	body_mat.set_shader_parameter("region_colors", arr)
	body_mat.set_shader_parameter("cloth_rough", float(a.get("rough", 0.85)))
	body_mat.set_shader_parameter("cloth_metal", float(a.get("metal", 0.0)))

func set_bruised(v: float) -> void:
	if body_mat:
		body_mat.set_shader_parameter("bruise", v)

func set_outfit(id: String) -> void:
	if id == outfit:
		return
	outfit = id
	var custom_outfit := find_custom(["outfits/%s_%s_%s.vrm" % [look.get("race", ""), look.get("body", ""), id], "outfits/%s_%s.vrm" % [id, look.get("body", "")]])
	if not placeholder or custom_outfit != "":
		build(look, id, weapon_kind, weapon_tier)
		return
	_apply_outfit_colors()
	_build_armor_parts()

func _apply_morphs() -> void:
	for m in meshes:
		for pair in [["Bust", float(look.get("bust", 0.5))], ["Muscle", float(look.get("muscle", 0.3))], ["Weight", float(look.get("weight", 0.3))]]:
			var idx := m.find_blend_shape_by_name(pair[0])
			if idx >= 0:
				m.set_blend_shape_value(idx, pair[1])

# ------------------------------------------------------------------ sockets & parts
## A node that follows a humanoid bone. `offset` is in character space relative to the bone, T-pose.
func socket(h: String, offset := Transform3D()) -> Node3D:
	if not bone_map.has(h):
		return null
	var key := "%s_%s" % [h, str(offset)]
	if _sockets.has(key):
		return _sockets[key]
	var ba := BoneAttachment3D.new()
	ba.bone_name = skel.get_bone_name(bone_map[h])
	skel.add_child(ba)
	var holder := Node3D.new()
	ba.add_child(holder)
	var rest := Transform3D(skel_to_char.basis * skel.get_bone_global_rest(bone_map[h]).basis, Vector3.ZERO)
	holder.transform = rest.affine_inverse() * offset
	_sockets[key] = holder
	return holder

func _head_socket() -> Node3D:
	return socket("head", Transform3D(Basis().scaled(Vector3.ONE * unit), Vector3(0, 0.095, -0.008) * unit))

func _add_face() -> void:
	var hs := _head_socket()
	if hs == null:
		return
	var em := PartsBuilder.eye_meshes()
	var white := MeshKit.pbr(Color("f4f1ec"), 0.15)
	var dark := MeshKit.pbr(Color("0a0a0c"), 0.05)
	var size := lerpf(0.85, 1.2, float(look.get("eye_size", 0.5)))
	var shape := int(look.get("eye_shape", 0))
	var tilt: float = [0.0, 0.18, -0.05, 0.1][shape]
	var squash: float = [1.0, 0.85, 1.1, 0.7][shape]
	for sx in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(sx * 0.033, -0.004, -0.083)
		eye.rotation = Vector3(0, 0, -sx * tilt)
		eye.scale = Vector3(size, size * squash, size)
		hs.add_child(eye)
		var s := MeshInstance3D.new()
		s.mesh = em[0]
		s.material_override = white
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(s)
		var col: String = look.get("eye_color_r", look.eye_color) if (sx > 0 and look.get("heterochromia", false)) else look.get("eye_color", "#2f5f8f")
		var iris := MeshInstance3D.new()
		iris.mesh = em[1]
		iris.material_override = MeshKit.pbr(Color(col), 0.08, 0.0, Color(col), 0.15)
		iris.position = Vector3(0, 0, -0.0105)
		iris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(iris)
		var pupil := MeshInstance3D.new()
		pupil.mesh = em[2]
		pupil.material_override = dark
		pupil.position = Vector3(0, 0, -0.0128)
		pupil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(pupil)
		_eyes.append(eye)
		var brow := MeshInstance3D.new()
		brow.mesh = PartsBuilder.brow_mesh()
		brow.material_override = MeshKit.pbr(Color(look.get("hair_color", "#3b2a20")).darkened(0.2), 0.7)
		brow.position = Vector3(sx * 0.033, 0.024, -0.091)
		brow.rotation = Vector3(0, 0, sx * 0.12)
		brow.scale = Vector3(-sx, 1, 1) if sx < 0 else Vector3.ONE
		hs.add_child(brow)
	var ear_styles: Array = DB.races[look.race].ears
	if ear_styles.is_empty() or ear_styles[0] == "human":
		for sx in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			e.mesh = PartsBuilder.human_ear_mesh()
			e.material_override = body_mat
			e.position = Vector3(sx * 0.086, -0.01, 0.005)
			hs.add_child(e)

func _add_hair() -> void:
	var hs := _head_socket()
	if hs == null:
		return
	var custom := find_custom(["hair/%s.glb" % look.get("hair", ""), "hair/%s.vrm" % look.get("hair", "")])
	var mat := PartsBuilder.hair_material(Color(look.get("hair_color", "#3b2a20")), Color(look.get("highlight_color", "#b98a52")), bool(look.get("highlights", false)))
	if custom != "":
		var tpl := _load_template(custom)
		if tpl:
			var h := tpl.duplicate() as Node3D
			hs.add_child(h)
			return
	var hair := MeshInstance3D.new()
	hair.mesh = PartsBuilder.hair_mesh(look.get("hair", "crop"))
	hair.material_override = mat
	hs.add_child(hair)

func _add_race_parts() -> void:
	var r: Dictionary = DB.races.get(look.race, DB.races.hume)
	var hs := _head_socket()
	var hair_col := Color(look.get("hair_color", "#3b2a20"))
	var skin_col := RacesData.skin_color(look)
	var ear_list: Array = r.ears
	if hs and not ear_list.is_empty():
		var ears := PartsBuilder.race_ears(ear_list[clampi(int(look.get("ears", 0)), 0, ear_list.size() - 1)])
		if not ears.is_empty():
			var e := MeshInstance3D.new()
			e.mesh = ears[0]
			e.material_override = PartsBuilder.hair_material(hair_col, hair_col.lightened(0.3), false) if ears[1] else (body_mat if body_mat else MeshKit.pbr(skin_col, 0.5))
			hs.add_child(e)
	var horns: Array = r.horns
	if hs and not horns.is_empty():
		var h := MeshInstance3D.new()
		h.mesh = PartsBuilder.horn_mesh(horns[clampi(int(look.get("horns", 0)), 0, horns.size() - 1)])
		h.material_override = MeshKit.pbr(Color("2e2a2a").lerp(Color(look.get("scale_color", "#6b4a2a")), 0.3), 0.35)
		hs.add_child(h)
	var tails: Array = r.tail
	if not tails.is_empty():
		var ts := socket("hips", Transform3D(Basis().scaled(Vector3.ONE * unit), Vector3.ZERO))
		if ts:
			_tail = Node3D.new()
			ts.add_child(_tail)
			var style: String = tails[clampi(int(look.get("tail", 0)), 0, tails.size() - 1)]
			var tm := MeshInstance3D.new()
			tm.mesh = PartsBuilder.tail_mesh(style, float(look.get("tail_length", 0.5)))
			tm.material_override = MeshKit.pbr(Color(look.get("scale_color", "#6b4a2a")), 0.45) if style == "dragon" else PartsBuilder.hair_material(hair_col, hair_col.lightened(0.2), false)
			_tail.add_child(tm)

func _build_armor_parts() -> void:
	for n in _armor_nodes:
		n.queue_free()
	_armor_nodes.clear()
	if not placeholder:
		return
	var a: Dictionary = DB.armor.get(outfit, DB.armor.none)
	var parts: Array = a.get("parts", [])
	if parts.is_empty():
		return
	var cols: Dictionary = a.colors
	var main := MeshKit.pbr(Color(cols.get("torso", "#6b4a2e")).darkened(0.15), float(a.get("rough", 0.6)), float(a.get("metal", 0.0)))
	var leather := MeshKit.pbr(Color("3a2618"), 0.65)
	var u := Basis().scaled(Vector3.ONE * unit)
	for p in parts:
		match p:
			"belt", "sash":
				_part("hips", PartsBuilder.armor_piece(p), Transform3D(u, Vector3(0, 0.04, 0) * unit), leather if p == "belt" else MeshKit.pbr(Color(cols.get("pelvis", "#8c2f2f")), 0.7))
			"bracers":
				_part("leftLowerArm", PartsBuilder.armor_piece("bracer"), Transform3D(u.rotated(Vector3.UP, PI), Vector3(-0.08, 0, 0) * unit), leather)
				_part("rightLowerArm", PartsBuilder.armor_piece("bracer"), Transform3D(u, Vector3(0.08, 0, 0) * unit), leather)
			"pauldrons_light", "pauldrons_heavy":
				var kind := "pauldron_light" if p == "pauldrons_light" else "pauldron_heavy"
				_part("leftUpperArm", PartsBuilder.armor_piece(kind), Transform3D(u, Vector3(-0.01, 0.02, 0) * unit), main)
				_part("rightUpperArm", PartsBuilder.armor_piece(kind), Transform3D(u, Vector3(0.01, 0.02, 0) * unit), main)
			"mantle":
				_part("upperChest", PartsBuilder.armor_piece("mantle"), Transform3D(u, Vector3(0, 0.08, 0.0) * unit), main)
			"hood_cape":
				_part("upperChest", PartsBuilder.armor_piece("cape"), Transform3D(u, Vector3(0, 0.1, 0.0) * unit), main)
			"coat_tails":
				_part("hips", PartsBuilder.armor_piece("coat_tails"), Transform3D(u, Vector3(0, 0.02, 0) * unit), main)

func _part(h: String, mesh: Mesh, off: Transform3D, mat: Material) -> void:
	var s := socket(h)
	if s == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = off
	s.add_child(mi)
	_armor_nodes.append(mi)

func set_weapon(kind: String, tier: int) -> void:
	weapon_kind = kind
	weapon_tier = tier
	_build_weapon()

func set_sheathed(v: bool) -> void:
	if v != sheathed:
		sheathed = v
		_build_weapon()

func _build_weapon() -> void:
	for n in _weapon_nodes:
		n.queue_free()
	_weapon_nodes.clear()
	if weapon_kind == "" or skel == null:
		return
	var w := PartsBuilder.weapon(weapon_kind, weapon_tier)
	var u := Basis().scaled(Vector3.ONE * unit)
	if sheathed:
		var back := Transform3D(u * Basis(Vector3.BACK, 0.5) * Basis(Vector3.RIGHT, -PI / 2), Vector3(0, -0.02, 0.15) * unit)
		if weapon_kind in ["lance", "gun"]:
			back = Transform3D(u * Basis(Vector3.BACK, deg_to_rad(-60)), Vector3(0, 0.0, 0.15) * unit)
		match weapon_kind:
			"fists":
				pass  # gauntlets stay on the hands
			"daggers":
				_attach_weapon("hips", w.right, Transform3D(u * Basis(Vector3.RIGHT, -PI / 2), Vector3(0.15, 0, 0.06) * unit))
				_attach_weapon("hips", w.left, Transform3D(u * Basis(Vector3.RIGHT, -PI / 2), Vector3(-0.15, 0, 0.06) * unit))
				return
			"sword_shield":
				_attach_weapon("hips", w.right, Transform3D(u * Basis(Vector3.BACK, -0.25) * Basis(Vector3.RIGHT, -PI / 2), Vector3(-0.16, 0.02, 0.0) * unit))
				_attach_weapon("upperChest", w.left, Transform3D(u * Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.05, 0.2) * unit))
				return
			"bow":
				_attach_weapon("upperChest", w.left, back)
				return
			_:
				if w.right:
					_attach_weapon("upperChest", w.right, back)
				return
	if w.right:
		_attach_weapon("rightHand", w.right, Transform3D(u, Vector3(0.075, -0.005, 0) * unit))
	if w.left:
		var lo := Transform3D(u, Vector3(-0.075, -0.005, 0) * unit)
		if weapon_kind in ["fists"]:
			lo = Transform3D(u.rotated(Vector3.UP, PI), Vector3(-0.075, -0.005, 0) * unit)
		_attach_weapon("leftHand", w.left, lo)

func _attach_weapon(h: String, n: Node3D, off: Transform3D) -> void:
	var s := socket(h)
	if s == null:
		n.queue_free()
		return
	n.transform = off
	s.add_child(n)
	_weapon_nodes.append(n)

## World-space position of the main weapon tip (for trails / spell origins).
func hand_position(side := "right") -> Vector3:
	if bone_map.has(side + "Hand"):
		return skel.global_transform * skel.get_bone_global_pose(bone_map[side + "Hand"]).origin
	return global_position + Vector3.UP * height_m * 0.6

func head_position() -> Vector3:
	if bone_map.has("head"):
		return skel.global_transform * skel.get_bone_global_pose(bone_map.head).origin
	return global_position + Vector3.UP * height_m * 0.9

# ------------------------------------------------------------------ animation
## Apply a pose (from Poses). Extras: _lie, _roll, _pitch, _spin handled on the visual root.
func animate(delta: float, pose: Dictionary, sharpness := 12.0) -> void:
	if anim == null:
		return
	_t += delta
	anim.apply(pose, delta, sharpness)
	var w := 1.0 - exp(-sharpness * delta)
	for k in _extras:
		var target: float = pose.get(k, 0.0)
		if k == "_spin" or k == "_roll":
			_extras[k] = target
		else:
			_extras[k] = lerpf(_extras[k], target, w)
	var h := height_m * 0.55
	var xf := Transform3D()
	if _extras._lie > 0.001:
		xf = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0 * _extras._lie)), Vector3(0, 0.12 * _extras._lie, 0))
	if _extras._roll > 0.001 and _extras._roll < 0.999:
		var r := Basis(Vector3.RIGHT, -TAU * _extras._roll)
		xf = Transform3D(Basis(), Vector3(0, h * 0.6, 0)) * Transform3D(r, Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -h * 0.6, 0))
	if absf(_extras._pitch) > 0.1:
		var r := Basis(Vector3.RIGHT, deg_to_rad(_extras._pitch))
		xf = xf * Transform3D(Basis(), Vector3(0, h, 0)) * Transform3D(r, Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -h, 0))
	if _extras._spin > 0.001:
		xf = Transform3D(Basis(Vector3.UP, -TAU * _extras._spin), Vector3.ZERO) * xf
	visual.transform = Transform3D(xf.basis * Basis().scaled(Vector3.ONE * _vis_scale), xf.origin)
	if _tail:
		_tail.rotation = Vector3(sin(_t * 1.7) * 0.08, sin(_t * 2.1) * 0.25, 0)
	_blink -= delta
	if _blink < 0.0:
		var closing := _blink > -0.12
		for e in _eyes:
			e.scale.y = 0.1 if closing else e.scale.x
		if not closing:
			_blink = randf_range(2.5, 5.5)

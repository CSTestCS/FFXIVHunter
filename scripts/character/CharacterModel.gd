class_name CharacterModel
extends Node3D
## A humanoid character assembled at runtime from built-in VRM files (see ModelLibrary and
## docs/MODELS.md): a naked base body chosen by race / clan / body type / variant, plus gear and
## hair overlays whose skinned meshes are re-bound to the body skeleton by bone name.
## Without supplied models it falls back to the generated placeholder body, which is painted with
## the gear colours, and to procedural hair / race features / armor parts.

const BodyShader := preload("res://shaders/placeholder_body.gdshader")
const REGION_KEYS := ["head", "neck", "torso", "uarm", "larm", "hand", "pelvis", "thigh", "shin", "foot", "bust"]
const RacesData := preload("res://scripts/data/races.gd")
const ItemsData := preload("res://scripts/data/items.gd")

var look: Dictionary = {}
var gear: Dictionary = {}           # slot -> gear piece id ("" = empty)
var visual: Node3D
var model: Node3D
var skel: Skeleton3D
var anim: HumanoidAnimator
var bone_map := {}
var skel_to_char := Transform3D()
var placeholder := true
var race_parts_included := false
var body_path := ""
var meshes: Array[MeshInstance3D] = []
var body_mat: ShaderMaterial
var unit := 1.0              # model scale factor (head height / placeholder head height)
var height_m := 1.65
var weapon_kind := ""
var weapon_tier := 0
var sheathed := false
var _weapon_nodes: Array[Node3D] = []
var _gear_nodes: Array[Node] = []
var _hair_nodes: Array[Node] = []
var _overlaid := {}          # slot -> true when that slot is shown by a VRM overlay
var _sockets := {}
var _tail: Node3D
var _eyes: Array[Node3D] = []
var _t := 0.0
var _extras := {"_lie": 0.0, "_roll": 0.0, "_pitch": 0.0, "_spin": 0.0}
var _blink := 3.0
var _vis_scale := 1.0

## gear_or_set: a slot -> piece dictionary, or a gear set id (dresses every slot from that set).
func build(p_look: Dictionary, gear_or_set: Variant = {}, p_weapon := "", p_tier := 0) -> void:
	look = p_look
	gear = DB.set_gear(gear_or_set) if gear_or_set is String else (gear_or_set as Dictionary).duplicate()
	weapon_kind = p_weapon
	weapon_tier = p_tier
	for c in get_children():
		c.queue_free()
	_sockets.clear()
	_weapon_nodes.clear()
	_gear_nodes.clear()
	_hair_nodes.clear()
	_overlaid.clear()
	_eyes.clear()
	meshes.clear()
	_tail = null
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	body_path = _pick_body()
	var tpl := ModelLibrary.load_template(body_path)
	if tpl == null:
		body_path = ModelLibrary.placeholder(look.get("body", "feminine"))
		placeholder = true
		race_parts_included = false
		tpl = ModelLibrary.load_template(body_path)
	model = tpl.duplicate() as Node3D
	visual.add_child(model)
	var sk := model.find_children("*", "Skeleton3D", true, false)
	skel = sk[0] if sk.size() > 0 else null
	if skel == null:
		push_error("Model has no skeleton: " + body_path)
		return
	for m in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m)
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
	if bone_map.has("head") and not race_parts_included:
		var hs: float = DB.races.get(look.race, {}).get("head_scale", 1.0)
		skel.set_bone_pose_scale(bone_map.head, Vector3.ONE * hs)
	_apply_body_materials()
	_apply_morphs(meshes)
	if placeholder:
		_add_face()
	_add_hair()
	if not race_parts_included:
		_add_race_parts()
	_build_gear()
	_build_weapon()

func _pick_body() -> String:
	var race: String = look.get("race", "hume")
	var body: String = look.get("body", "feminine")
	var variants := ModelLibrary.body_variants(race, look.get("clan", ""), body)
	if variants.is_empty():
		placeholder = true
		race_parts_included = false
		return ModelLibrary.placeholder(body)
	placeholder = false
	var path: String = variants[clampi(int(look.get("model_variant", 0)), 0, variants.size() - 1)]
	race_parts_included = ModelLibrary.is_race_specific(path, race)
	return path

static func _relative_xform(node: Node3D, root: Node) -> Transform3D:
	var x := Transform3D()
	var n: Node = node
	while n and n != root:
		if n is Node3D:
			x = (n as Node3D).transform * x
		n = n.get_parent()
	return x

# ------------------------------------------------------------------ materials
func _apply_body_materials() -> void:
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
		for m in meshes:
			m.material_override = body_mat
	else:
		body_mat = null
		_convert_materials(meshes)

## Make VRoid/MToon fallback materials PBR, keep textures, tint by VRoid material naming.
func _convert_materials(list: Array, tint_all_hair := false) -> void:
	var skin := RacesData.skin_color(look)
	for m in list:
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(si)
			if not (mat is BaseMaterial3D):
				continue
			var nm := (mat.resource_name as String).to_upper()
			var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			dup.roughness = maxf(dup.roughness, 0.55)
			dup.metallic = minf(dup.metallic, 0.2)
			if tint_all_hair or "HAIR" in nm:
				dup.albedo_color = Color(look.get("hair_color", "#ffffff")).lightened(0.25)
			elif "SKIN" in nm or "FACE" in nm or "BODY" in nm:
				dup.albedo_color = skin.lightened(0.15)
			elif "IRIS" in nm:
				dup.albedo_color = Color(look.get("eye_color", "#ffffff")).lightened(0.3)
			if dup.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				dup.alpha_scissor_threshold = 0.5
			mi.set_surface_override_material(si, dup)

func set_bruised(v: float) -> void:
	if body_mat:
		body_mat.set_shader_parameter("bruise", v)

func _apply_morphs(list: Array) -> void:
	for m in list:
		var mi := m as MeshInstance3D
		for pair in [["Bust", float(look.get("bust", 0.5))], ["Muscle", float(look.get("muscle", 0.3))], ["Weight", float(look.get("weight", 0.3))]]:
			var idx := mi.find_blend_shape_by_name(pair[0])
			if idx >= 0:
				mi.set_blend_shape_value(idx, pair[1])

# ------------------------------------------------------------------ overlays (gear / hair VRMs)
## Instances a VRM/glTF and moves its meshes onto this body's skeleton. Skinned meshes are
## re-bound bone-by-bone using humanoid names (so VRoid J_Bip names or VRM humanoid maps both work).
func _attach_overlay(path: String, store: Array, hair := false) -> bool:
	var tpl := ModelLibrary.load_template(path)
	if tpl == null or skel == null:
		return false
	var inst := tpl.duplicate() as Node3D
	var src_map := {}
	var src_sk := inst.find_children("*", "Skeleton3D", true, false)
	var src_skel: Skeleton3D = src_sk[0] if src_sk.size() > 0 else null
	if src_skel:
		var hm := HumanoidAnimator.build_map(src_skel, tpl.get_meta("vrm_bones", {}))
		for h in hm:
			src_map[src_skel.get_bone_name(hm[h])] = h
	var added := []
	for mnode in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := mnode as MeshInstance3D
		var xf := _relative_xform(mi, src_skel) if src_skel else Transform3D()
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skel.add_child(mi)
		mi.transform = xf
		if mi.skin and src_skel:
			var ns := Skin.new()
			for i in range(mi.skin.get_bind_count()):
				var bname := String(mi.skin.get_bind_name(i))
				if bname == "":
					bname = src_skel.get_bone_name(mi.skin.get_bind_bone(i))
				if src_map.has(bname) and bone_map.has(src_map[bname]):
					bname = skel.get_bone_name(bone_map[src_map[bname]])
				ns.add_named_bind(bname, mi.skin.get_bind_pose(i))
			mi.skin = ns
			mi.skeleton = NodePath("..")
		elif not mi.skin:
			# rigid piece: follow the head (hair/hats) or hips
			skel.remove_child(mi)
			var s := socket("head" if hair else "hips")
			if s == null:
				mi.queue_free()
				continue
			s.add_child(mi)
			mi.transform = Transform3D(Basis().scaled(Vector3.ONE * (1.0 / maxf(_vis_scale, 0.001))), Vector3.ZERO) * xf
		added.append(mi)
		store.append(mi)
	inst.queue_free()
	_convert_materials(added, hair)
	_apply_morphs(added)
	return not added.is_empty()

# ------------------------------------------------------------------ gear
func set_gear(p_gear: Dictionary) -> void:
	if p_gear == gear:
		return
	gear = p_gear.duplicate()
	if skel:
		_build_gear()

func _build_gear() -> void:
	for n in _gear_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_gear_nodes.clear()
	_overlaid.clear()
	var race: String = look.get("race", "hume")
	var body: String = look.get("body", "feminine")
	for slot in ItemsData.GEAR_SLOTS:
		var pid: String = gear.get(slot, "")
		if pid == "":
			continue
		var path := ModelLibrary.gear_model(pid, race, body)
		if path != "" and _attach_overlay(path, _gear_nodes):
			_overlaid[slot] = true
	if placeholder:
		_paint_gear()
	_build_gear_parts()

func _set_of(slot: String) -> Dictionary:
	var pid: String = gear.get(slot, "")
	if pid == "" or not DB.gear.has(pid):
		return {}
	return DB.gear_sets[DB.gear[pid].set]

func _paint_gear() -> void:
	var cols := {}
	var rough := 0.85
	var metal := 0.0
	for slot in ItemsData.GEAR_SLOTS:
		var st := _set_of(slot)
		if st.is_empty() or _overlaid.has(slot):
			continue
		for r in ItemsData.SLOT_INFO[slot].regions:
			var c: String = st.colors.get(r, "")
			if c != "":
				cols[r] = c
		if slot in ["body", "legs"]:
			rough = float(st.get("rough", rough))
			metal = maxf(metal, float(st.get("metal", 0.0)))
	if _set_of("body").is_empty() and not cols.has("bust"):
		cols["bust"] = ItemsData.UNDERWEAR.bust
	if _set_of("legs").is_empty() and not cols.has("pelvis"):
		cols["pelvis"] = ItemsData.UNDERWEAR.pelvis
	var arr := PackedVector4Array()
	for k in REGION_KEYS:
		var c: String = cols.get(k, "")
		if c == "":
			arr.append(Vector4(0, 0, 0, 0))
		else:
			var col := Color(c).srgb_to_linear()
			arr.append(Vector4(col.r, col.g, col.b, 1.0))
	body_mat.set_shader_parameter("region_colors", arr)
	body_mat.set_shader_parameter("cloth_rough", rough)
	body_mat.set_shader_parameter("cloth_metal", metal)

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
	var hair_id: String = look.get("hair", "crop")
	var path := ModelLibrary.hair_model(hair_id, look.get("body", "feminine"))
	if path != "" and _attach_overlay(path, _hair_nodes, true):
		return
	if not placeholder:
		return  # supplied bodies without a matching hair file keep whatever hair they have
	var hs := _head_socket()
	if hs == null:
		return
	var hair := MeshInstance3D.new()
	hair.mesh = PartsBuilder.hair_mesh(hair_id)
	hair.material_override = PartsBuilder.hair_material(Color(look.get("hair_color", "#3b2a20")), Color(look.get("highlight_color", "#b98a52")), bool(look.get("highlights", false)))
	hs.add_child(hair)
	_hair_nodes.append(hair)

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

## Procedural extras for placeholder gear: belts, bracers, pauldrons, capes and headwear.
func _build_gear_parts() -> void:
	var u := Basis().scaled(Vector3.ONE * unit)
	var st := _set_of("body")
	if not st.is_empty() and not _overlaid.has("body"):
		var cols: Dictionary = st.colors
		var main := MeshKit.pbr(Color(cols.get("torso", "#6b4a2e")).darkened(0.15), float(st.get("rough", 0.6)), float(st.get("metal", 0.0)))
		var leather := MeshKit.pbr(Color("3a2618"), 0.65)
		for p in st.get("parts", []):
			match p:
				"belt", "sash":
					_part("hips", PartsBuilder.armor_piece(p), Transform3D(u, Vector3(0, 0.04, 0) * unit), leather if p == "belt" else MeshKit.pbr(Color(cols.get("pelvis", "#8c2f2f")), 0.7))
				"bracers":
					if not _overlaid.has("hands"):
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
	var hs := _set_of("head")
	if not hs.is_empty() and not _overlaid.has("head") and hs.get("head", "") != "":
		var hcol := Color(hs.colors.get("torso", "#6b4a2e"))
		var mat := MeshKit.pbr(hcol.darkened(0.1), float(hs.get("rough", 0.7)), float(hs.get("metal", 0.0)))
		var s := _head_socket()
		if s:
			var mi := MeshInstance3D.new()
			mi.mesh = PartsBuilder.headwear(hs.head)
			mi.material_override = mat
			s.add_child(mi)
			_gear_nodes.append(mi)

func _part(h: String, mesh: Mesh, off: Transform3D, mat: Material) -> void:
	var s := socket(h)
	if s == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = off
	s.add_child(mi)
	_gear_nodes.append(mi)

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

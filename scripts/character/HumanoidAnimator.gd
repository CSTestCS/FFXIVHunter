class_name HumanoidAnimator
extends RefCounted
## Drives any T-pose humanoid skeleton (VRoid/VRM 0.x and 1.0, or the placeholders) from
## character-space poses. For each bone: local = (Gp^-1 * q * Gp) * rest_local, where Gp is the
## parent's rest orientation in character space. This makes one pose library work for every model,
## whatever its bone axes or facing direction.

const HUMAN_BONES := ["hips", "spine", "chest", "upperChest", "neck", "head",
	"leftShoulder", "leftUpperArm", "leftLowerArm", "leftHand", "rightShoulder", "rightUpperArm", "rightLowerArm", "rightHand",
	"leftUpperLeg", "leftLowerLeg", "leftFoot", "leftToes", "rightUpperLeg", "rightLowerLeg", "rightFoot", "rightToes"]

var skel: Skeleton3D
var bones := {}          # humanoid -> {"i": idx, "rest": Quaternion, "gp": Quaternion, "gpi": Quaternion}
var cur := {}            # humanoid -> current Quaternion (character space delta)
var hips_rest := Vector3.ZERO
var char_to_skel := Basis()
var skel_scale := 1.0
var hips_offset := Vector3.ZERO

func setup(skeleton: Skeleton3D, map: Dictionary, skel_to_char: Transform3D) -> void:
	skel = skeleton
	var S := skel_to_char.basis.orthonormalized()
	char_to_skel = S.inverse()
	skel_scale = skel_to_char.basis.get_scale().x
	for h in HUMAN_BONES:
		if not map.has(h):
			continue
		var i: int = map[h]
		var parent := skel.get_bone_parent(i)
		var gp := Quaternion(S)
		if parent >= 0:
			gp = Quaternion(S * skel.get_bone_global_rest(parent).basis.orthonormalized())
		bones[h] = {"i": i, "rest": skel.get_bone_rest(i).basis.get_rotation_quaternion(), "gp": gp, "gpi": gp.inverse()}
		cur[h] = Quaternion.IDENTITY
	if map.has("hips"):
		hips_rest = skel.get_bone_rest(map.hips).origin

func has_bone(h: String) -> bool:
	return bones.has(h)

## Blend toward `pose` (humanoid -> Euler degrees). sharpness ~ 8 (smooth) .. 30 (snappy).
func apply(pose: Dictionary, delta: float, sharpness := 12.0) -> void:
	var w := 1.0 - exp(-sharpness * delta)
	for h in bones:
		var e: Vector3 = pose.get(h, Vector3.ZERO)
		var target := Quaternion.from_euler(e * (PI / 180.0))
		var q: Quaternion = cur[h].slerp(target, w)
		cur[h] = q
		var b: Dictionary = bones[h]
		skel.set_bone_pose_rotation(b.i, (b.gpi * q * b.gp) * b.rest)
	var off: Vector3 = pose.get("_hips", Vector3.ZERO)
	hips_offset = hips_offset.lerp(off, w)
	if bones.has("hips"):
		skel.set_bone_pose_position(bones.hips.i, hips_rest + char_to_skel * hips_offset / maxf(skel_scale, 0.001))

## Resolve humanoid bone indices for a skeleton: VRM metadata first, then common naming schemes.
static func build_map(skeleton: Skeleton3D, vrm_names: Dictionary) -> Dictionary:
	var map := {}
	for h in vrm_names:
		var idx := skeleton.find_bone(vrm_names[h])
		if idx >= 0:
			map[h] = idx
	var vroid := {"hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "upperChest": "J_Bip_C_UpperChest",
		"neck": "J_Bip_C_Neck", "head": "J_Bip_C_Head"}
	for side in [["left", "L"], ["right", "R"]]:
		for part in [["Shoulder", "Shoulder"], ["UpperArm", "UpperArm"], ["LowerArm", "LowerArm"], ["Hand", "Hand"],
				["UpperLeg", "UpperLeg"], ["LowerLeg", "LowerLeg"], ["Foot", "Foot"], ["Toes", "ToeBase"]]:
			vroid[side[0] + part[0]] = "J_Bip_%s_%s" % [side[1], part[1]]
	for h in vroid:
		if map.has(h):
			continue
		for candidate in [vroid[h], h, h.capitalize().replace(" ", ""), "mixamorig_" + h.capitalize().replace(" ", "")]:
			var idx := skeleton.find_bone(candidate)
			if idx >= 0:
				map[h] = idx
				break
	return map

class_name ModelLibrary
extends RefCounted
## Finds and loads the built-in VRM models. All paths are inside the game (res://models/...),
## so models you supply are packed into the .exe at build time. See docs/MODELS.md.
##
##   models/bodies/<race>/<clan>/<body>/*.vrm   naked base bodies, several per subrace & body type
##   models/bodies/<race>/<body>/*.vrm          (fallback: any clan of that race)
##   models/bodies/<body>/*.vrm                 (fallback: any race)
##   models/gear/<piece_id>[_<race>][_<body>].vrm   equippable gear overlays (e.g. plate_set_body)
##   models/hair/<hair_id>[_<body>].vrm         hairstyle overlays (extra files add new styles)
##   models/placeholder/body_<body>.vrm         generated placeholders (used when nothing else exists)

const ROOT := "res://models"

static var _templates := {}
static var _lists := {}

static func vrm_files(dir: String) -> Array:
	if _lists.has(dir):
		return _lists[dir]
	var out := []
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().to_lower() == "vrm":
				out.append(dir.path_join(f))
	out.sort()
	_lists[dir] = out
	return out

## All body models available for a race/clan/body type (most specific folder that has any).
static func body_variants(race: String, clan: String, body: String) -> Array:
	for dir in ["%s/bodies/%s/%s/%s" % [ROOT, race, clan, body], "%s/bodies/%s/%s" % [ROOT, race, body], "%s/bodies/%s" % [ROOT, body]]:
		var l := vrm_files(dir)
		if not l.is_empty():
			return l
	return []

## True when the body comes from a race-specific folder (it already has ears/tail/horns).
static func is_race_specific(path: String, race: String) -> bool:
	return path.begins_with("%s/bodies/%s/" % [ROOT, race])

static func placeholder(body: String) -> String:
	return "%s/placeholder/body_%s.vrm" % [ROOT, body]

static func first_existing(candidates: Array) -> String:
	for c in candidates:
		if FileAccess.file_exists(c):
			return c
	return ""

static func gear_model(piece_id: String, race: String, body: String) -> String:
	var d := ROOT + "/gear/"
	return first_existing([d + "%s_%s_%s.vrm" % [piece_id, race, body], d + "%s_%s.vrm" % [piece_id, body], d + piece_id + ".vrm"])

static func hair_model(hair_id: String, body: String) -> String:
	var d := ROOT + "/hair/"
	return first_existing([d + "%s_%s.vrm" % [hair_id, body], d + hair_id + ".vrm"])

## Hairstyles supplied as files that are not in the built-in list become extra styles.
static func extra_hairstyles(known: Array) -> Array:
	var out := []
	for p in vrm_files(ROOT + "/hair"):
		var id: String = (p as String).get_file().get_basename()
		for b in ["_feminine", "_masculine"]:
			id = id.trim_suffix(b)
		if not known.has(id) and not out.has(id):
			out.append(id)
	return out

## Loads (once) and returns a template scene for a VRM/glTF file, with VRM metadata attached.
static func load_template(path: String) -> Node3D:
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

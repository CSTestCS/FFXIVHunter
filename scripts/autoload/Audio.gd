extends Node
## Music, ambience, sound effects and UI sounds. All audio is pre-rendered by tools/make_audio.py.
## Buses: Master > Music, Ambience, SFX, UI (volumes in Settings). Music crossfades between two
## players; positional SFX use a small pool of 3D players (cheap, no per-sound nodes).

const MUSIC_DIR := "res://audio/music/"
const AMB_DIR := "res://audio/amb/"
const SFX_DIR := "res://audio/sfx/"
const BUSES := ["Music", "Ambience", "SFX", "UI"]

var _music: Array[AudioStreamPlayer] = []
var _music_i := 0
var _music_id := ""
var _amb: AudioStreamPlayer
var _amb_id := ""
var _jingle: AudioStreamPlayer
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool3d_i := 0
var _pool2d: Array[AudioStreamPlayer] = []
var _pool2d_i := 0
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_i := 0
var _cache := {}
var _duck := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	add_child(_amb)
	_jingle = AudioStreamPlayer.new()
	_jingle.bus = "Music"
	add_child(_jingle)
	for i in range(20):
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 70.0
		p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p)
		_pool3d.append(p)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_ui_pool.append(p)
	apply_volumes()
	Settings.changed.connect(apply_volumes)
	get_viewport().gui_focus_changed.connect(func(_c): ui("ui_move"))

func apply_volumes() -> void:
	var d: Dictionary = Settings.data
	_set_bus("Master", float(d.get("vol_master", 0.8)))
	_set_bus("Music", float(d.get("vol_music", 0.7)))
	_set_bus("Ambience", float(d.get("vol_ambience", 0.6)))
	_set_bus("SFX", float(d.get("vol_sfx", 0.8)))
	_set_bus("UI", float(d.get("vol_ui", 0.6)))

func _set_bus(name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)

func _load(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = loop
	_cache[path] = s
	return s

# ------------------------------------------------------------------ music & ambience
func play_music(id: String, fade := 1.5) -> void:
	if id == _music_id:
		return
	_music_id = id
	var old := _music[_music_i]
	_music_i = 1 - _music_i
	var nw := _music[_music_i]
	var tw := create_tween().set_parallel()
	tw.tween_property(old, "volume_db", -80.0, fade)
	if id == "":
		return
	var s := _load(MUSIC_DIR + id + ".ogg", true)
	if s == null:
		return
	nw.stream = s
	nw.volume_db = -40.0
	nw.play()
	tw.tween_property(nw, "volume_db", 0.0, fade)

func play_ambience(id: String) -> void:
	if id == _amb_id:
		return
	_amb_id = id
	if id == "":
		_amb.stop()
		return
	var s := _load(AMB_DIR + id + ".ogg", true)
	if s:
		_amb.stream = s
		_amb.volume_db = -30.0
		_amb.play()
		create_tween().tween_property(_amb, "volume_db", 0.0, 2.0)

## Short stinger over the music (quest complete, level up...). Music dips while it plays.
func jingle(id: String) -> void:
	var s := _load(MUSIC_DIR + id + ".ogg", false)
	if s == null:
		return
	_jingle.stream = s
	_jingle.play()
	var cur := _music[_music_i]
	var tw := create_tween()
	tw.tween_property(cur, "volume_db", -14.0, 0.2)
	tw.tween_interval(maxf(0.5, s.get_length() - 0.8))
	tw.tween_property(cur, "volume_db", 0.0, 1.0)

func current_music() -> String:
	return _music_id

# ------------------------------------------------------------------ effects
## Positional sound when `at` is given, otherwise 2D. pitch_var randomises pitch for variety.
func sfx(id: String, at: Variant = null, vol_db := 0.0, pitch_var := 0.08) -> void:
	var s := _load(SFX_DIR + id + ".wav", false)
	if s == null:
		return
	var pitch := 1.0 + randf_range(-pitch_var, pitch_var)
	if at is Vector3 and get_viewport().get_camera_3d():
		var p := _pool3d[_pool3d_i]
		_pool3d_i = (_pool3d_i + 1) % _pool3d.size()
		p.stream = s
		p.global_position = at
		p.volume_db = vol_db
		p.pitch_scale = pitch
		p.play()
	else:
		var p := _pool2d[_pool2d_i]
		_pool2d_i = (_pool2d_i + 1) % _pool2d.size()
		p.stream = s
		p.volume_db = vol_db
		p.pitch_scale = pitch
		p.play()

func ui(id: String) -> void:
	var s := _load(SFX_DIR + id + ".wav", false)
	if s == null:
		return
	var p := _ui_pool[_ui_i]
	_ui_i = (_ui_i + 1) % _ui_pool.size()
	p.stream = s
	p.volume_db = -4.0
	p.play()

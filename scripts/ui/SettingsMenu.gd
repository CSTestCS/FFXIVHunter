class_name SettingsMenu
extends VBoxContainer
## Graphics / controls settings (used from the title screen and the in-game menu).

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build()

func _build() -> void:
	UIKit.clear(self)
	var d: Dictionary = Settings.data
	add_child(UIKit.label("Graphics", 26, UIKit.GOLD))
	_option("Quality preset", Settings.QUALITY_NAMES, int(d.quality), func(i): _apply("quality", i))
	add_child(UIKit.label("    Low: no SSAO/grass, short shadows.  Medium: SSAO + grass.  High: SSR + longer shadows.  Ultra: SDFGI, SSIL, volumetric fog.", 16, UIKit.DIM, true))
	_slider("3D resolution scale (FSR below 100%)", 0.5, 1.0, 0.05, float(d.render_scale), func(v): _apply("render_scale", v))
	_check("Fullscreen", bool(d.fullscreen), func(v): _apply("fullscreen", v))
	_check("V-Sync", bool(d.vsync), func(v): _apply("vsync", v))
	_option("Frame rate cap", ["Unlimited", "30", "60", "120", "144"], [0, 30, 60, 120, 144].find(int(d.fps_cap)), func(i): _apply("fps_cap", [0, 30, 60, 120, 144][i]))
	_check("Damage numbers", bool(d.show_damage_numbers), func(v): _apply("show_damage_numbers", v))
	add_child(UIKit.label("Audio", 26, UIKit.GOLD))
	_slider("Master volume", 0.0, 1.0, 0.05, float(d.vol_master), func(v): _apply("vol_master", v))
	_slider("Music", 0.0, 1.0, 0.05, float(d.vol_music), func(v): _apply("vol_music", v))
	_slider("Ambience", 0.0, 1.0, 0.05, float(d.vol_ambience), func(v): _apply("vol_ambience", v))
	_slider("Sound effects", 0.0, 1.0, 0.05, float(d.vol_sfx), func(v): _apply("vol_sfx", v))
	_slider("Interface sounds", 0.0, 1.0, 0.05, float(d.vol_ui), func(v): _apply("vol_ui", v))
	add_child(UIKit.label("Controls", 26, UIKit.GOLD))
	_slider("Mouse sensitivity", 0.05, 1.0, 0.01, float(d.mouse_sens), func(v): _apply("mouse_sens", v))
	_slider("Gamepad camera speed", 0.8, 5.0, 0.1, float(d.pad_sens), func(v): _apply("pad_sens", v))
	_slider("Camera distance", 2.5, 8.0, 0.1, float(d.cam_distance), func(v): _apply("cam_distance", v))
	_check("Invert camera Y", bool(d.invert_y), func(v): _apply("invert_y", v))
	var help := UIKit.label(
		"Keyboard & mouse: WASD move · Mouse look · LMB light attack · RMB heavy (hold to charge) · Q weapon art · Ctrl guard · Space dodge (hold: sprint) · F jump / swim up · C dive · E interact · R use item · 1/3 cycle items · Tab or MMB lock-on · Esc menu · M map\n" +
		"Gamepad: L-stick move · R-stick camera · RB light · RT heavy · LT weapon art · LB guard · B dodge (hold: sprint) · Y jump / swim up · L3 dive · A interact · X use item · D-pad ◀▶ items · R3 lock-on (flick R-stick to switch) · Start menu · Back map",
		16, UIKit.DIM, true)
	help.custom_minimum_size = Vector2(880, 0)
	add_child(help)

func _apply(k: String, v) -> void:
	Settings.data[k] = v
	Settings.save_settings()
	Settings.apply_window()

func _row(label: String) -> HBoxContainer:
	var h := UIKit.hbox(12)
	var l := UIKit.label(label, 20)
	l.custom_minimum_size = Vector2(380, 0)
	h.add_child(l)
	add_child(h)
	return h

func _option(label: String, items: Array, sel: int, cb: Callable) -> void:
	var h := _row(label)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(maxi(0, sel))
	o.custom_minimum_size = Vector2(260, 40)
	o.item_selected.connect(cb)
	h.add_child(o)

func _check(label: String, v: bool, cb: Callable) -> void:
	var h := _row(label)
	var c := CheckButton.new()
	c.button_pressed = v
	c.toggled.connect(cb)
	h.add_child(c)

func _slider(label: String, lo: float, hi: float, step: float, v: float, cb: Callable) -> void:
	var h := _row(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.custom_minimum_size = Vector2(300, 32)
	var val := UIKit.label("%.2f" % v, 18, UIKit.DIM)
	s.value_changed.connect(func(x):
		val.text = "%.2f" % x
		cb.call(x))
	h.add_child(s)
	h.add_child(val)

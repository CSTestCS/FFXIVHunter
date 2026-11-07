class_name UIKit
extends RefCounted
## Shared UI theme and small widget helpers. All menus are built in code with these.

const GOLD := Color("e8d38a")
const TEXT := Color("eef2f8")
const DIM := Color("9aa6b8")
const BAD := Color("e2695c")
const GOOD := Color("7fd48a")
const PANEL := Color(0.06, 0.08, 0.13, 0.88)
const ACCENT := Color("7fd4ff")

static var _theme: Theme

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	var panel := _box(PANEL, Color(GOLD, 0.55), 1, 6)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var btn := _box(Color(0.12, 0.16, 0.25, 0.92), Color(GOLD, 0.35), 1, 4)
	var btn_h := _box(Color(0.18, 0.24, 0.36, 0.95), Color(GOLD, 0.8), 1, 4)
	var btn_f := _box(Color(0.22, 0.3, 0.46, 0.98), GOLD, 2, 4)
	var btn_p := _box(Color(0.3, 0.38, 0.55, 1.0), GOLD, 2, 4)
	var btn_d := _box(Color(0.1, 0.1, 0.12, 0.7), Color(0.4, 0.4, 0.4, 0.4), 1, 4)
	for c in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", c, btn)
		t.set_stylebox("hover", c, btn_h)
		t.set_stylebox("focus", c, btn_f)
		t.set_stylebox("pressed", c, btn_p)
		t.set_stylebox("disabled", c, btn_d)
		t.set_color("font_color", c, TEXT)
		t.set_color("font_hover_color", c, Color.WHITE)
		t.set_color("font_focus_color", c, GOLD)
		t.set_color("font_disabled_color", c, DIM)
	t.set_stylebox("normal", "LineEdit", _box(Color(0.04, 0.05, 0.08, 0.95), Color(GOLD, 0.4), 1, 4))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.04, 0.05, 0.08, 0.95), GOLD, 2, 4))
	t.set_color("font_color", "Label", TEXT)
	var slider := _box(Color(0.1, 0.12, 0.18), Color(GOLD, 0.3), 1, 3)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", _box(Color(ACCENT, 0.6), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(GOLD, 0.8), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("focus", "HSlider", _box(Color(0, 0, 0, 0), GOLD, 2, 3))
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_stylebox("tab_selected", "TabBar", _box(Color(0.22, 0.3, 0.46, 0.98), GOLD, 1, 4))
	t.set_stylebox("tab_unselected", "TabBar", _box(Color(0.1, 0.13, 0.2, 0.9), Color(GOLD, 0.25), 1, 4))
	t.set_stylebox("tab_hovered", "TabBar", btn_h)
	t.set_stylebox("tab_focus", "TabBar", _box(Color(0, 0, 0, 0), GOLD, 2, 4))
	t.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.8), 1, 3))
	t.set_stylebox("fill", "ProgressBar", _box(GOOD, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("panel", "ItemList", _box(Color(0.04, 0.05, 0.08, 0.8), Color(GOLD, 0.3), 1, 4))
	t.set_stylebox("focus", "ItemList", _box(Color(0, 0, 0, 0), GOLD, 2, 4))
	t.set_stylebox("selected", "ItemList", _box(Color(0.22, 0.3, 0.46, 0.98), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("selected_focus", "ItemList", _box(Color(0.3, 0.4, 0.6, 1.0), GOLD, 1, 2))
	t.set_stylebox("cursor", "ItemList", _box(Color(0, 0, 0, 0), GOLD, 1, 2))
	t.set_stylebox("cursor_unfocused", "ItemList", _box(Color(0, 0, 0, 0), Color(GOLD, 0.4), 1, 2))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", GOLD)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	_theme = t
	return t

static func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func label(text: String, size := 22, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(cb)
	return b

static func panel(margin := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var s: StyleBoxFlat = theme().get_stylebox("panel", "PanelContainer").duplicate()
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	p.add_theme_stylebox_override("panel", s)
	return p

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func bar(color: Color, w := 300, h := 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var fill := _box(color, Color(0, 0, 0, 0), 0, 3)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	b.add_theme_stylebox_override("fill", fill)
	return b

static func focus_first(root: Node) -> void:
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.focus_mode == Control.FOCUS_ALL and ctl.is_visible_in_tree() and not (ctl is Button and (ctl as Button).disabled):
			ctl.grab_focus()
			return

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

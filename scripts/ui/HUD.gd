class_name HUD
extends CanvasLayer

## Heads-up display: per-side health and meter bars (depleting toward the centre), a
## round timer, round-win pips, fighter names, and a centre banner for announcements.
## Built entirely from Control nodes in code and updated via signals from the fighters
## and the RoundManager.

const BASE_W := 1280.0
const HP_W := 540.0
const HP_H := 30.0
const MP_W := 360.0
const MP_H := 12.0
const DR_W := 270.0
const DR_H := 6.0
const MOVE_LIST_W := 560.0
const MOVE_LIST_H := 430.0

var _hp_fill := [null, null]
var _mp_fill := [null, null]
var _dr_fill := [null, null]
var _pips := [[], []]
var _root: Control
var _banner: Label
var _timer_label: Label
var _counter_label: Label
var _move_list_panel: Panel
var _move_list_labels := [null, null]
var _counter_timer: int = 0

func build(p1: CharacterData, p2: CharacterData) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_side(_root, 0, p1, 40.0)
	_build_side(_root, 1, p2, BASE_W - 40.0 - HP_W)

	_timer_label = _label(_root, Vector2(BASE_W * 0.5 - 60.0, 18.0), Vector2(120.0, 50.0), 40)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.text = str(GameConst.ROUND_TIME_SECONDS)

	_banner = _label(_root, Vector2(BASE_W * 0.5 - 400.0, 190.0), Vector2(800.0, 90.0), 64)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", Color(1, 0.92, 0.5))
	_banner.text = ""

	# Counter / Punish Counter call-out, shown briefly on a counter hit. Its own label and
	# timer so it never clobbers (or is clobbered by) round announcements.
	_counter_label = _label(_root, Vector2(BASE_W * 0.5 - 350.0, 300.0), Vector2(700.0, 70.0), 52)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.text = ""

	_build_move_list(p1, p2)

func _build_side(root: Control, side: int, ch: CharacterData, x: float) -> void:
	# Health bar.
	_panel(root, Vector2(x - 3, 25), Vector2(HP_W + 6, HP_H + 6), Color(0, 0, 0, 0.6))
	_panel(root, Vector2(x, 28), Vector2(HP_W, HP_H), Color(0.2, 0.05, 0.05))
	var hp := _panel(root, Vector2(x, 28), Vector2(HP_W, HP_H), ch.color)
	_hp_fill[side] = {"rect": hp, "x": x}

	# Meter bar.
	var mx := x if side == 0 else x + HP_W - MP_W
	_panel(root, Vector2(mx, 66), Vector2(MP_W, MP_H), Color(0.1, 0.1, 0.12))
	var mp := _panel(root, Vector2(mx, 66), Vector2(MP_W, MP_H), ch.accent)
	_mp_fill[side] = {"rect": mp, "x": mx}
	mp.size.x = 0

	# Drive gauge (separate from the Super meter), six bars, between the HP and meter bars.
	var dx := x if side == 0 else x + HP_W - DR_W
	_panel(root, Vector2(dx, 60), Vector2(DR_W, DR_H), Color(0.06, 0.12, 0.08))
	var dr := _panel(root, Vector2(dx, 60), Vector2(DR_W, DR_H), Color(0.3, 0.9, 0.5))
	_dr_fill[side] = {"rect": dr, "x": dx}
	for i in range(1, 6):
		_panel(root, Vector2(dx + DR_W * i / 6.0 - 1, 60), Vector2(2, DR_H), Color(0, 0, 0, 0.7))

	# Name.
	var name_pos := Vector2(x, 84) if side == 0 else Vector2(x + HP_W - 220, 84)
	var nm := _label(root, name_pos, Vector2(220, 28), 20)
	nm.text = ch.display_name
	if side == 1:
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Round pips, near the inner edge.
	for i in range(GameConst.ROUNDS_TO_WIN):
		var px := (x + HP_W - 18 - i * 22) if side == 0 else (x + 4 + i * 22)
		var pip := _panel(root, Vector2(px, 64), Vector2(16, 16), Color(0.25, 0.25, 0.3))
		_pips[side].append(pip)

# --- updates ---------------------------------------------------------------

func set_health(side: int, current: int, maximum: int) -> void:
	var frac := clampf(float(current) / float(max(1, maximum)), 0.0, 1.0)
	var info = _hp_fill[side]
	var rect: ColorRect = info["rect"]
	rect.size.x = HP_W * frac
	if side == 1:
		rect.position.x = info["x"] + HP_W * (1.0 - frac)

func set_meter(side: int, current: int, maximum: int) -> void:
	var frac := clampf(float(current) / float(max(1, maximum)), 0.0, 1.0)
	var info = _mp_fill[side]
	var rect: ColorRect = info["rect"]
	rect.size.x = MP_W * frac
	if side == 1:
		rect.position.x = info["x"] + MP_W * (1.0 - frac)

func set_drive(side: int, current: int, maximum: int) -> void:
	var frac := clampf(float(current) / float(max(1, maximum)), 0.0, 1.0)
	var info = _dr_fill[side]
	var rect: ColorRect = info["rect"]
	rect.size.x = DR_W * frac
	if side == 1:
		rect.position.x = info["x"] + DR_W * (1.0 - frac)

func set_timer(seconds: int) -> void:
	_timer_label.text = str(max(0, seconds))

func set_rounds(p1_wins: int, p2_wins: int) -> void:
	_fill_pips(0, p1_wins)
	_fill_pips(1, p2_wins)

func _fill_pips(side: int, wins: int) -> void:
	for i in range(_pips[side].size()):
		var pip: ColorRect = _pips[side][i]
		pip.color = Color(1.0, 0.8, 0.2) if i < wins else Color(0.25, 0.25, 0.3)

func show_banner(text: String) -> void:
	_banner.text = text

func clear_banner() -> void:
	_banner.text = ""

## Flash a COUNTER / PUNISH COUNTER call-out. Auto-clears after a short time; drive the
## countdown from the match's fixed tick via tick_counter().
const COUNTER_TICKS := 55

func show_counter(kind: int) -> void:
	if kind == GameConst.Counter.PUNISH:
		_counter_label.text = "PUNISH COUNTER"
		_counter_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.15))
	else:
		_counter_label.text = "COUNTER"
		_counter_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_counter_timer = COUNTER_TICKS

func tick_counter() -> void:
	if _counter_timer > 0:
		_counter_timer -= 1
		if _counter_timer == 0:
			_counter_label.text = ""

func toggle_move_list() -> void:
	if _move_list_panel:
		_move_list_panel.visible = not _move_list_panel.visible

func is_move_list_visible() -> bool:
	return _move_list_panel != null and _move_list_panel.visible

func _build_move_list(p1: CharacterData, p2: CharacterData) -> void:
	_move_list_panel = Panel.new()
	_move_list_panel.position = Vector2(BASE_W * 0.5 - MOVE_LIST_W * 0.5, 150.0)
	_move_list_panel.size = Vector2(MOVE_LIST_W, MOVE_LIST_H)
	_move_list_panel.visible = false
	_root.add_child(_move_list_panel)

	var title := _label(_move_list_panel, Vector2(24, 18), Vector2(MOVE_LIST_W - 48.0, 34), 28)
	title.text = "MOVE LIST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.4))

	var hint := _label(_move_list_panel, Vector2(24, 52), Vector2(MOVE_LIST_W - 48.0, 24), 16)
	hint.text = "TAB: close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var left := _label(_move_list_panel, Vector2(26, 94), Vector2(240, MOVE_LIST_H - 118.0), 18)
	left.text = _move_list_text(p1)
	var right := _label(_move_list_panel, Vector2(MOVE_LIST_W - 266.0, 94), Vector2(240, MOVE_LIST_H - 118.0), 18)
	right.text = _move_list_text(p2)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_move_list_labels[0] = left
	_move_list_labels[1] = right

func _move_list_text(ch: CharacterData) -> String:
	var lines := [ch.display_name.to_upper(), ""]
	for m in ch.specials:
		lines.append("%s" % m.display_name)
		lines.append("%s" % _input_text(m))
		lines.append("")
	for m in ch.supers:
		lines.append("%s" % m.display_name)
		lines.append("%s" % _input_text(m))
		lines.append("")
	return "\n".join(lines).strip_edges()

func _input_text(m: MoveData) -> String:
	var parts := []
	if not m.motion.is_empty():
		parts.append(_motion_text(m.motion))
	parts.append(_button_text(m.button))
	if m.meter_cost > 0:
		parts.append("(%d meter)" % m.meter_cost)
	return " + ".join(parts)

func _motion_text(seq: Array[int]) -> String:
	var digits := ""
	for d in seq:
		digits += str(d)
	return digits

func _button_text(button: int) -> String:
	match button:
		GameConst.Btn.LP:
			return "LP"
		GameConst.Btn.MP:
			return "MP"
		GameConst.Btn.HP:
			return "HP"
		GameConst.Btn.LK:
			return "LK"
		GameConst.Btn.MK:
			return "MK"
		GameConst.Btn.HK:
			return "HK"
	return "BTN"

# --- factory ---------------------------------------------------------------

func _panel(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _label(parent: Control, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

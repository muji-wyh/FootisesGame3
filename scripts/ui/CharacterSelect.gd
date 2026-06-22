extends Control

## Character select. Each side cycles through the roster; press Fight to start. In Vs CPU
## mode the right side is labelled (CPU) but still selectable.

var _ids: Array[String] = CharacterLibrary.ids()
var _sel := [0, mini(1, _ids.size() - 1)]   # clamp P2's pick to the roster (1 char -> mirror)
var _name_labels := [null, null]
var _blurb_labels := [null, null]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.08, 0.12)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := Label.new()
	title.text = "CHOOSE TRAINING PARTNERS" if Game.mode == GameConst.Mode.TRAINING else "CHOOSE YOUR FIGHTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 80)
	root.add_child(columns)

	columns.add_child(_make_column(0))
	columns.add_child(_make_column(1))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	root.add_child(actions)

	var fight := _button("FIGHT!", 30)
	fight.pressed.connect(_on_fight)
	actions.add_child(fight)

	var back := _button("BACK", 22)
	back.pressed.connect(func(): Game.goto_scene("res://scenes/ui/MainMenu.tscn"))
	actions.add_child(back)

	fight.call_deferred("grab_focus")

func _make_column(side: int) -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(360, 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	if side == 0:
		header.text = "PLAYER 1"
	else:
		if Game.mode == GameConst.Mode.TRAINING:
			header.text = "TRAINING DUMMY"
		else:
			header.text = "PLAYER 2 (CPU)" if Game.mode == GameConst.Mode.VS_CPU else "PLAYER 2"
	vb.add_child(header)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 40)
	vb.add_child(name_label)
	_name_labels[side] = name_label

	var blurb := Label.new()
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(340, 70)
	blurb.add_theme_font_size_override("font_size", 16)
	blurb.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	vb.add_child(blurb)
	_blurb_labels[side] = blurb

	# Only offer a CHANGE button when there is more than one fighter to pick.
	if _ids.size() > 1:
		var change := _button("CHANGE", 20)
		change.pressed.connect(func(): _cycle(side))
		vb.add_child(change)

	_refresh(side)
	return vb

func _cycle(side: int) -> void:
	_sel[side] = (_sel[side] + 1) % _ids.size()
	_refresh(side)

func _refresh(side: int) -> void:
	var ch := CharacterLibrary.create(_ids[_sel[side]])
	_name_labels[side].text = ch.display_name
	_name_labels[side].add_theme_color_override("font_color", ch.color)
	_blurb_labels[side].text = ch.blurb

func _on_fight() -> void:
	Game.p1_char_id = _ids[_sel[0]]
	Game.p2_char_id = _ids[_sel[1]]
	Game.goto_scene(_target_scene())

func _target_scene() -> String:
	return "res://scenes/match/Training.tscn" if Game.mode == GameConst.Mode.TRAINING else "res://scenes/match/Match.tscn"

func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 48)
	b.add_theme_font_size_override("font_size", font_size)
	return b

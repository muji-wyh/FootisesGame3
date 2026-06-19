extends Control

## Results screen shown after a match. Announces the winner and offers a rematch (same
## characters/mode) or a return to the main menu.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.08, 0.12)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	var winner := Label.new()
	winner.text = "%s WINS" % Game.last_winner_name.to_upper()
	winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner.add_theme_font_size_override("font_size", 72)
	winner.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	vb.add_child(winner)

	vb.add_child(_spacer(20))

	var rematch := _button("REMATCH")
	rematch.pressed.connect(func(): Game.goto_scene("res://scenes/match/Match.tscn"))
	vb.add_child(rematch)

	var menu := _button("MAIN MENU")
	menu.pressed.connect(func(): Game.goto_scene("res://scenes/ui/MainMenu.tscn"))
	vb.add_child(menu)

	rematch.call_deferred("grab_focus")

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 54)
	b.add_theme_font_size_override("font_size", 28)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

extends Control

## Main menu: choose Local 2P or Vs CPU, then go to character select. Keyboard/gamepad
## navigable (buttons are focusable; ui_up/ui_down move between them).

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
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "BRAWL ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "An original 2.5D fighter"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	vb.add_child(subtitle)

	vb.add_child(_spacer(20))

	var b1 := _button("LOCAL 2-PLAYER")
	b1.pressed.connect(func(): _start(GameConst.Mode.LOCAL_2P))
	vb.add_child(b1)

	var b2 := _button("VS CPU")
	b2.pressed.connect(func(): _start(GameConst.Mode.VS_CPU))
	vb.add_child(b2)

	var b_gallery := _button("ANIMATION GALLERY")
	b_gallery.pressed.connect(func(): Game.goto_scene("res://scenes/ui/AnimationGallery.tscn"))
	vb.add_child(b_gallery)

	var b3 := _button("QUIT")
	b3.pressed.connect(func(): get_tree().quit())
	vb.add_child(b3)

	vb.add_child(_spacer(20))

	var help := Label.new()
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	help.text = "P1: WASD move - F/G/H punch - V/B/N kick      P2: Arrows - J/K/L punch - M/,/. kick\nDouble-tap forward/back = dash   -   crouch & jump have their own attacks   -   ESC to menu"
	vb.add_child(help)

	b1.call_deferred("grab_focus")

func _start(mode: int) -> void:
	Game.mode = mode
	Game.goto_scene("res://scenes/ui/CharacterSelect.tscn")

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 28)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

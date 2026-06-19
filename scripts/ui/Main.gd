extends Node

## Entry point. Boots straight into the main menu.

func _ready() -> void:
	if OS.has_feature("headless"):
		print("Headless boot OK")
	call_deferred("_goto_menu")

func _goto_menu() -> void:
	Game.goto_scene("res://scenes/ui/MainMenu.tscn")

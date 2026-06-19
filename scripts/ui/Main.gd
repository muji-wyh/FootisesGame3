extends Node

## Entry point. For now it just confirms the project boots; it will load the main
## menu once that scene exists (Phase 4).

func _ready() -> void:
	print("Brawl Arena booting. Mode=", Game.mode, " chars=", Game.p1_char_id, "/", Game.p2_char_id)
	if OS.has_feature("headless"):
		print("Headless boot OK")

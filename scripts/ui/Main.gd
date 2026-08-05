extends Node

## Entry point. Boots straight into the main menu, unless the page URL carries a deep
## link (see `apply_boot_link`).

## Any URL containing this marker -- e.g. http://localhost:8090/testblaze -- skips the
## menus and drops straight into a Blaze vs Blaze training session. `tools/serve.py`
## rewrites extensionless paths to index.html so the bare "/testblaze" link resolves.
const TESTBLAZE_LINK := "testblaze"
const FIGHTING_ANIMSET_PRO_LINK := "testfightinganimsetpro"

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const TRAINING_SCENE := "res://scenes/match/Training.tscn"
const FIGHTING_ANIMSET_PRO_SCENE := "res://scenes/ui/GALLERY-FightingAnimsetPro.tscn"

func _ready() -> void:
	if OS.has_feature("headless"):
		print("Headless boot OK")
	call_deferred("_boot")

func _boot() -> void:
	Game.goto_scene(apply_boot_link(_page_url()))

## Configure `Game` from any deep link in `url` and return the scene to boot into.
## The URL is a parameter (not read inside) so the headless suite can drive this
## without a browser.
func apply_boot_link(url: String) -> String:
	if url.contains(FIGHTING_ANIMSET_PRO_LINK):
		return FIGHTING_ANIMSET_PRO_SCENE
	if not url.contains(TESTBLAZE_LINK):
		return MENU_SCENE
	Game.mode = GameConst.Mode.TRAINING
	Game.p1_char_id = "blaze"
	Game.p2_char_id = "blaze"
	return TRAINING_SCENE

## The browser address bar, or "" anywhere else (editor, desktop, headless tests).
func _page_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var href: Variant = JavaScriptBridge.eval("window.location.href", true)
	return str(href) if href is String else ""

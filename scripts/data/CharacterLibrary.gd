class_name CharacterLibrary
extends RefCounted

## The playable roster, as a registry of self-contained character modules. Each character lives
## in `characters/<id>/<id>.gd` and exposes `static func build() -> CharacterData` plus `ID` /
## `DISPLAY_NAME` consts. Adding a character = drop in its directory + one line here.

const REGISTRY := {
	"blaze": preload("res://characters/blaze/blaze.gd"),
}

static func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(REGISTRY.keys())
	return out

static func display_name(id: String) -> String:
	if REGISTRY.has(id):
		return REGISTRY[id].DISPLAY_NAME
	return id

static func create(id: String) -> CharacterData:
	var module = REGISTRY.get(id, REGISTRY["blaze"])
	return module.build()

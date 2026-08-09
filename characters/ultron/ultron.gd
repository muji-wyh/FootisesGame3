extends RefCounted

const ID := "ultron"
const DISPLAY_NAME := "Ultron"
const MODEL := "res://characters/ultron/assets/ultron.fbx"
const BLAZE := preload("res://characters/blaze/blaze.gd")

static func build() -> CharacterData:
	var character := BLAZE.build()
	character.id = ID
	character.display_name = DISPLAY_NAME
	character.model_path = MODEL
	character.rig.preserve_materials = true
	return character

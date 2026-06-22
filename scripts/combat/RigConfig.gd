class_name RigConfig
extends Resource

## Per-character visual/rig configuration read by the (generic) AnimatedFighterRig: the imported
## animation source files, the maps that drive clips/materials/grounding, and the directional
## hit-reaction clip templates. Moving these out of the rig makes the rig character-agnostic, so a
## new character is a new RigConfig (+ its assets), not an engine edit.
##
## The model itself (model_path / orientation / scale) stays on CharacterData; this holds
## everything the rig needs ON TOP of the model.

## Animation source FBX/glTF whose clips are grafted onto the model, and graft bookkeeping.
@export var anim_files: Array[String] = []
@export var lib_name: String = "kb"
@export var skip_clips: Array[String] = ["BindPose", "tpose", "Take 001"]
@export var root_bones: Array[String] = ["Hips", "Root"]   # horizontal root motion stripped (in place)
@export var grounded_clips: Array[String] = []              # clips whose root vertical motion is stripped too
@export var foot_bones: Array[String] = ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]

## State -> default clip name. Per-move clips come from MoveData.anim_clip.
@export var state_clips: Dictionary = {}
@export var looped_clips: Array[String] = []
@export var default_move_clip: String = ""
@export var drive_rush_clips: Array[String] = []   # fallback chain for the DRIVE_RUSH state

## Materials: a mesh-surface-name substring -> texture base name, loaded from tex_dir/<name>.png.
@export var surface_textures: Dictionary = {}
@export var tex_dir: String = ""
@export var material_roughness: float = 0.7
@export var lod_keep: String = "LOD1"   # substring of the LOD mesh to keep visible

## Directional hit-reaction clip resolution. Templates are printf-style: the rig fills the height
## token (High/Mid/Low) and direction token (Front/Back/Left/Right). Knockdown / get-up are
## prioritised candidate lists; the first clip that was actually grafted wins.
@export var hit_fallback: String = ""
@export var crouch_hit_template: String = ""          # one %s (direction), e.g. "KB_crouch_Hit_p_Mid%s_Weak"
@export var hit_templates_heavy: Array[String] = []   # tier 2, each with two %s (height, direction)
@export var hit_templates_medium: Array[String] = []  # tier 1
@export var hit_templates_light: Array[String] = []   # tier 0
@export var ko_upper: Array[String] = []
@export var ko_low: Array[String] = []
@export var ko_air: Array[String] = []
@export var ko_heavy: Array[String] = []
@export var ko_default: String = ""
@export var getup_front: Array[String] = []   # rise after being struck from the front (face-up)
@export var getup_back: Array[String] = []    # rise after being struck from behind (face-down)

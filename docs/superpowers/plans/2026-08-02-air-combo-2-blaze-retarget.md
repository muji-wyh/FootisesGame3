# Air Combo 2 Blaze Retarget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retarget `Air_Combo-2.fbx` to Blaze's Maskman skeleton and use it for a new `214+LK` light launcher named Ember Lift.

**Architecture:** Blender bakes one derived, in-place animation onto the existing Maskman armature; the licensed source FBX remains unchanged. Blaze loads the derived FBX through its existing `RigConfig`, so no runtime retargeting or shared animation abstraction is added.

**Tech Stack:** Blender 5.2 MCP, Godot 4.7, typed GDScript, existing headless test harness.

## Global Constraints

- Keep `assets/third_party/fighter_animation_pack/anims/Air_Combo-2.fbx` unchanged.
- Export `characters/blaze/assets/anims/retargeted/Air_Combo-2_Blaze.fbx`.
- Name the exported action `Air_Combo_2_Blaze`.
- Remove horizontal root travel while retaining vertical body motion.
- Keep the derived licensed FBX and its `.import` file gitignored.
- Do not add runtime retargeting or batch-convert the remaining animation pack.

---

### Task 1: Specify Ember Lift and the Retargeted Clip

**Files:**
- Modify: `tools/run_tests.gd:104-165`
- Modify: `tools/run_tests.gd:864-882`
- Modify: `tools/run_tests.gd:1367-1376`
- Modify: `tools/run_tests.gd:2677-2685`

**Interfaces:**
- Consumes: `CharacterLibrary.create("blaze")`, `MotionParser.QCB`, `AnimatedFighterRig.build_library(RigConfig)`.
- Produces: regression checks for move ID `ember_lift` and clip name `Air_Combo_2_Blaze`.

- [ ] **Step 1: Register a focused test in `_initialize()`**

Add `_test_ember_lift()` beside the other Blaze tests:

```gdscript
	_test_blaze_roster()
	_test_ember_lift()
```

- [ ] **Step 2: Extend Blaze roster and animation assertions**

In `_test_blaze_roster()`, include `ember_lift` in the authored special list:

```gdscript
	for added in ["flame_step_l", "flame_step_m", "flame_step_h",
			"cinder_lash", "ember_wheel", "ember_lift"]:
		_check("combo move exists: " + added, b.get_move(added) != null)
```

In `_test_kb_library()`, check the derived clip only when the licensed output exists:

```gdscript
	var derived := "res://characters/blaze/assets/anims/retargeted/Air_Combo-2_Blaze.fbx"
	if ResourceLoader.exists(derived):
		_check("kb library exposes retargeted Air Combo 2",
			lib.has_animation("Air_Combo_2_Blaze"))
```

- [ ] **Step 3: Add the failing move-data and input test**

Add:

```gdscript
func _test_ember_lift() -> void:
	print("[ember lift]")
	var blaze := CharacterLibrary.create("blaze")
	var move := blaze.get_move("ember_lift")
	var wheel := blaze.get_move("ember_wheel")
	_check("Ember Lift is 214 + LK",
		move != null and move.motion == MotionParser.QCB and move.button == GameConst.Btn.LK)
	_check("Ember Lift is a grounded light launcher",
		move != null and move.launch and not move.rises and move.hits == 2)
	_check("Ember Lift stays lighter than Ember Wheel",
		move != null and wheel != null
		and move.damage < wheel.damage
		and move.launch_velocity < wheel.launch_velocity
		and move.recovery < wheel.recovery)
	_check("Ember Lift owns the retargeted clip",
		move != null and move.anim_clip == "Air_Combo_2_Blaze")

	var ctx := _build()
	var fighter: Fighter = ctx["f1"]
	_step(ctx, _mk(0, -1), _neutral(), 2)
	_step(ctx, _mk(-1, -1), _neutral(), 2)
	_step(ctx, _mk(-1, 0, GameConst.Btn.LK), _neutral(), 1)
	_check("214 + LK starts Ember Lift",
		fighter.current_move != null and fighter.current_move.id == "ember_lift")
	ctx["arena"].queue_free()

	var heavy := _build()
	var heavy_fighter: Fighter = heavy["f1"]
	_step(heavy, _mk(0, -1), _neutral(), 2)
	_step(heavy, _mk(-1, -1), _neutral(), 2)
	_step(heavy, _mk(-1, 0, GameConst.Btn.HK), _neutral(), 1)
	_check("214 + HK still starts Ember Wheel",
		heavy_fighter.current_move != null and heavy_fighter.current_move.id == "ember_wheel")
	heavy["arena"].queue_free()
```

- [ ] **Step 4: Preserve the no-rising-special contract**

Extend `_test_uppercut_rise()`:

```gdscript
	var ember_lift := b.get_move("ember_lift")
	_check("Ember Lift launches only the victim",
		ember_lift != null and ember_lift.launch and not ember_lift.rises)
```

- [ ] **Step 5: Run the harness and verify the new test fails**

Run:

```powershell
godot4.7 --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd
```

Expected: failures report that `ember_lift` is missing; existing tests remain passing.

---

### Task 2: Retarget Air Combo 2 in Blender

**Files:**
- Source, unchanged: `assets/third_party/fighter_animation_pack/anims/Air_Combo-2.fbx`
- Local generated output: `characters/blaze/assets/anims/retargeted/Air_Combo-2_Blaze.fbx`
- Local generated import: `characters/blaze/assets/anims/retargeted/Air_Combo-2_Blaze.fbx.import`

**Interfaces:**
- Consumes: Unreal source bones and the armature from `characters/blaze/assets/maskman.fbx`.
- Produces: one FBX containing action `Air_Combo_2_Blaze` on Maskman bone names.

- [ ] **Step 1: Import both FBX files into a clean Blender scene**

Use Blender MCP `execute_blender_code`:

```python
import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(
    filepath=r"C:\uworks\FootisesGame3\assets\third_party\fighter_animation_pack\anims\Air_Combo-2.fbx",
    use_anim=True,
)
source = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
source.name = "AirComboSource"

before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(
    filepath=r"C:\uworks\FootisesGame3\characters\blaze\assets\maskman.fbx",
    use_anim=False,
)
target = next(o for o in bpy.data.objects if o not in before and o.type == "ARMATURE")
target.name = "BlazeArmature"
```

- [ ] **Step 2: Define the explicit humanoid bone map**

Run:

```python
bone_map = {
    "pelvis": "Hips",
    "spine_01": "Spine",
    "spine_03": "Spine1",
    "neck_01": "Neck",
    "head": "Head",
    "clavicle_l": "LeftShoulder",
    "upperarm_l": "LeftArm",
    "upperarm_twist_01_l": "LeftArmRoll",
    "lowerarm_l": "LeftForeArm",
    "lowerarm_twist_01_l": "LeftForeArmRoll",
    "hand_l": "LeftHand",
    "clavicle_r": "RightShoulder",
    "upperarm_r": "RightArm",
    "upperarm_twist_01_r": "RightArmRoll",
    "lowerarm_r": "RightForeArm",
    "lowerarm_twist_01_r": "RightForeArmRoll",
    "hand_r": "RightHand",
    "thigh_l": "LeftUpLeg",
    "thigh_twist_01_l": "LeftUpLegRoll",
    "calf_l": "LeftLeg",
    "calf_twist_01_l": "LeftLegRoll",
    "foot_l": "LeftFoot",
    "ball_l": "LeftToeBase",
    "thigh_r": "RightUpLeg",
    "thigh_twist_01_r": "RightUpLegRoll",
    "calf_r": "RightLeg",
    "calf_twist_01_r": "RightLegRoll",
    "foot_r": "RightFoot",
    "ball_r": "RightToeBase",
}

for side, suffix in (("l", "Left"), ("r", "Right")):
    for source_finger, target_finger in (
        ("index", "Index"),
        ("middle", "Middle"),
        ("ring", "Ring"),
        ("pinky", "Pinky"),
        ("thumb", "Thumb"),
    ):
        for joint in range(1, 4):
            bone_map[f"{source_finger}_0{joint}_{side}"] = (
                f"{suffix}Hand{target_finger}{joint}"
            )
```

IK bones and Maskman-only face/tip bones intentionally remain unmapped.

- [ ] **Step 3: Bake source world-space rotation deltas onto Maskman proportions**

Run:

```python
from mathutils import Matrix, Vector

scene = bpy.context.scene
scene.render.fps = 30
source_action = source.animation_data.action
start = int(source_action.frame_range[0])
end = int(source_action.frame_range[1] + 0.999)

target.animation_data_create()
target.animation_data.action = bpy.data.actions.new("Air_Combo_2_Blaze")

def depth(name):
    bone = target.data.bones[name]
    value = 0
    while bone.parent:
        value += 1
        bone = bone.parent
    return value

ordered = sorted(
    ((source_name, target_name) for source_name, target_name in bone_map.items()
     if source.data.bones.get(source_name) and target.data.bones.get(target_name)),
    key=lambda pair: depth(pair[1]),
)

source_rest_world = {
    name: source.matrix_world @ source.data.bones[name].matrix_local
    for name, _target_name in ordered
}
target_rest_world = {
    name: target.matrix_world @ target.data.bones[name].matrix_local
    for _source_name, name in ordered
}

for frame in range(start, end + 1):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    for pose_bone in target.pose.bones:
        pose_bone.matrix_basis.identity()
    bpy.context.view_layer.update()

    for source_name, target_name in ordered:
        source_pose_world = source.matrix_world @ source.pose.bones[source_name].matrix
        source_rest = source_rest_world[source_name]
        target_rest = target_rest_world[target_name]
        rotation_delta = (
            source_pose_world.to_quaternion()
            @ source_rest.to_quaternion().inverted()
        )
        desired_rotation = rotation_delta @ target_rest.to_quaternion()

        target_bone = target.pose.bones[target_name]
        if target_bone.parent:
            parent_world = target.matrix_world @ target_bone.parent.matrix
            rest_local = (
                target_bone.bone.parent.matrix_local.inverted()
                @ target_bone.bone.matrix_local
            )
            desired_location = (
                parent_world @ Matrix.Translation(rest_local.translation)
            ).translation
        else:
            desired_location = target_rest.translation

        desired_world = Matrix.LocRotScale(
            desired_location,
            desired_rotation,
            Vector((1.0, 1.0, 1.0)),
        )
        target_bone.matrix = target.matrix_world.inverted() @ desired_world
        target_bone.keyframe_insert("rotation_quaternion", frame=frame)
        target_bone.keyframe_insert("location", frame=frame)

target.animation_data.action.name = "Air_Combo_2_Blaze"
scene.frame_start = start
scene.frame_end = end
```

This preserves target limb lengths, ignores source armature-object travel, and therefore
keeps the baked clip in place.

- [ ] **Step 4: Push action to NLA and export only the Blaze armature and animation**

**Important:** Exporting with `bake_anim_use_nla_strips=False` causes Blender to label the
AnimStack `"Scene"` instead of `"BlazeArmature|Air_Combo_2_Blaze"`, so Godot reads the wrong
action name. You must push the action to an NLA strip first and set
`bake_anim_use_nla_strips=True` to get the correct AnimStack name in the exported FBX.

Run:

```python
import os

output = r"C:\uworks\FootisesGame3\characters\blaze\assets\anims\retargeted\Air_Combo-2_Blaze.fbx"
os.makedirs(os.path.dirname(output), exist_ok=True)

bpy.ops.object.select_all(action="DESELECT")
target.select_set(True)
bpy.context.view_layer.objects.active = target

# Push the baked action to an NLA strip so the FBX AnimStack gets the correct name.
# Without this push (or with bake_anim_use_nla_strips=False), Blender names the
# AnimStack "Scene" and Godot cannot find "Air_Combo_2_Blaze" at runtime.
action = target.animation_data.action
nla_tracks = target.animation_data.nla_tracks
for track in list(nla_tracks):
    nla_tracks.remove(track)
track = nla_tracks.new()
track.name = "Air_Combo_2_Blaze"
strip = track.strips.new("Air_Combo_2_Blaze", int(action.frame_range[0]), action)
strip.name = "Air_Combo_2_Blaze"
target.animation_data.action = None  # unlink so NLA is active

bpy.ops.export_scene.fbx(
    filepath=output,
    use_selection=True,
    object_types={"ARMATURE"},
    add_leaf_bones=False,
    bake_anim=True,
    bake_anim_use_all_actions=False,
    bake_anim_use_nla_strips=True,   # required: exports NLA strip name as AnimStack
    bake_anim_simplify_factor=0.0,
    path_mode="AUTO",
)
print(output)
```

- [ ] **Step 5: Import the generated FBX with Godot**

Run:

```powershell
godot4.7 --headless --path C:\uworks\FootisesGame3 --import
```

Expected: Godot creates the ignored `.fbx.import` file without import errors.

- [ ] **Step 6: Verify the generated action and skeleton**

Use a temporary Godot script outside the repository to load the FBX and assert:

```gdscript
var scene := load("res://characters/blaze/assets/anims/retargeted/Air_Combo-2_Blaze.fbx") as PackedScene
var instance := scene.instantiate()
var player := _find(instance, "AnimationPlayer") as AnimationPlayer
assert(player.has_animation("Air_Combo_2_Blaze"))
var animation := player.get_animation("Air_Combo_2_Blaze")
assert(animation.length > 0.5 and animation.length < 0.8)
```

Expected: assertions pass and the clip length remains approximately `0.7` seconds.

---

### Task 3: Wire Ember Lift Into Blaze

**Files:**
- Modify: `characters/blaze/blaze.gd:124-136`
- Modify: `characters/blaze/blaze.gd:177-188`

**Interfaces:**
- Consumes: generated clip `Air_Combo_2_Blaze` and `MotionParser.QCB`.
- Produces: `CharacterData.get_move("ember_lift") -> MoveData`.

- [ ] **Step 1: Add Ember Lift beside Ember Wheel**

Add before Ember Wheel:

```gdscript
	# Ember Lift: close light launcher. Blaze stays grounded; only the victim is popped up.
	c.add_move(CharacterKit.make_move({"id": "ember_lift", "display_name": "Ember Lift",
		"kind": GameConst.MoveKind.SPECIAL, "button": GameConst.Btn.LK,
		"motion": MotionParser.QCB, "startup": 6, "active": 10, "recovery": 18,
		"damage": 24, "hits": 2, "hit_gap": 4, "hitstun": 18, "blockstun": 10,
		"hitstop": 9, "guard": GameConst.Guard.MID, "knockback": 2.8,
		"advance": 2.2, "launch": true, "launch_velocity": 4.8,
		"meter_gain": 8, "hit_fx": HIT_FX + "Effect06.png", "sfx": "lk",
		"anim_limb": "leg_r", "anim_extend": 0.8,
		"anim_clip": "Air_Combo_2_Blaze",
		"hit_offset": Vector3(0.60, 0.78, 0.0),
		"hit_size": Vector3(0.54, 0.52, 0.66)}))
```

- [ ] **Step 2: Add the derived FBX to Blaze's animation sources**

Append to `r.anim_files`:

```gdscript
		ASSETS + "anims/retargeted/Air_Combo-2_Blaze.fbx",
```

- [ ] **Step 3: Run the full harness**

Run:

```powershell
godot4.7 --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd
```

Expected: all tests pass, including `[ember lift]` and the optional derived-clip check.

- [ ] **Step 4: Commit the gameplay integration**

```powershell
git add characters\blaze\blaze.gd tools\run_tests.gd
git commit -m "Add Blaze Ember Lift" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Document Local Asset Restoration

**Files:**
- Modify: `characters/blaze/assets/README.md:43-58`

**Interfaces:**
- Consumes: final derived FBX location and action name.
- Produces: restoration instructions for machines where licensed assets are installed.

- [ ] **Step 1: Add the retargeted output to the expected layout**

Extend the existing layout:

```text
characters/blaze/assets/anims/retargeted/Air_Combo-2_Blaze.fbx
    # Blender-baked Maskman clip; action name: Air_Combo_2_Blaze
```

State that the output is derived from the licensed Fighter Animation Pack, remains
gitignored, and must be regenerated or copied from a private legal backup on another machine.

- [ ] **Step 2: Check the documentation diff**

Run:

```powershell
git --no-pager diff --check
```

Expected: no output.

- [ ] **Step 3: Commit the documentation**

```powershell
git add characters\blaze\assets\README.md
git commit -m "Document Blaze retargeted animation" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 4: Confirm repository state**

Run:

```powershell
git --no-pager status --short
```

Expected: no tracked changes; the generated FBX and `.import` remain ignored.

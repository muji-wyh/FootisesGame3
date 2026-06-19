# 3D model import (FBX from Unity, glTF, etc.)

Godot 4.7 imports **`.fbx` natively** via the built-in [ufbx](https://github.com/ufbx/ufbx)
library — no FBX2glTF or the proprietary FBX SDK required. (glTF `.glb`/`.gltf` is the
officially recommended format and is the most robust; FBX works well too.)

## How to import
1. Copy your `character.fbx` **and its textures** into this folder (`assets/models/`).
2. Focus the Godot editor — it auto-imports the file as a scene
   (`MeshInstance3D` + `Skeleton3D` + an `AnimationPlayer` holding your clips).
3. Double-click the imported file → **Advanced Import Settings** to fix, if needed:
   - **Scale** (Unity/FBX is often in centimetres; set the import scale so the fighter is
     ~1.8 m tall).
   - **Materials** — reassign textures / tweak to `StandardMaterial3D` if they look wrong.
   - **Retarget** tab — map bones to `SkeletonProfileHumanoid` if you want to share
     animations across characters or use external (e.g. Mixamo) clips.

## What transfers vs. what doesn't
FBX carries **geometry, UVs, skeleton/rig, skinned animations, blend shapes, and basic
embedded materials/textures**. It does **not** carry Unity-specific data: `.prefab`,
C#/MonoBehaviour scripts, Unity `.mat`/Shader Graph materials, the Humanoid **Animator
controller/avatar**, colliders, or `.meta` files. You re-create behaviour in Godot (which
this project already provides) and re-wire materials/animation state machines.

## Wiring a model into a fighter (this project)
The combat is model-agnostic — the rig only *reads* `Fighter` state, it never drives
gameplay. To use an imported model instead of the procedural blockout:

1. In `scripts/fighter/FighterRig.gd`, change `build()` to instance the imported scene and
   grab its `AnimationPlayer` (or build an `AnimationTree`).
2. Change `pose(fighter)` to play/blend the right clip based on `fighter.state` and
   `fighter.current_move` (idle, walk_f/walk_b, crouch, jump, each attack, hitstun,
   knockdown, win) instead of rotating primitive limbs.
3. Nothing else changes — frame data, hitboxes, AI, HUD and rounds are unaffected.

> Tip: tell me your model's **bone names** and **animation clip names** (or just drop the
> `.fbx` here) and I can build the model-backed rig and verify it imports and renders.

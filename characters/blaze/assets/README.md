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

## What's wired in this project

`AnimatedFighterRig` (scripts/fighter/) loads a model, **grafts** animation clips onto its
skeleton, strips horizontal root motion (in-place), tints it with the character colour, and
plays clips from `Fighter` state. A character opts in via `CharacterData.model_path`; if the
(gitignored) model is missing, `MatchScene` falls back to the procedural blockout.

Currently **Blaze** (orange) uses `maskman.fbx` + the Kubold mocap clips
(`anims/KB_*.fbx`). These share one skeleton family (Mixamo/Biped naming), so the clips graft
directly with **no retargeting**. Per-move clips are set via `MoveData.anim_clip`
(e.g. `KB_p_Jab_R_1`, `KB_p_Uppercut_R`, `KB_Projectile_1`, `KB_Superpunch`).

Expected drop-in layout (all gitignored):
```
assets/models/maskman.fbx                 # Kubold "Maskman" model
assets/models/anims/KB_*.fbx              # Kubold Fighting Animset Pro clips
```

## Using the Fighters Pack characters (needs retargeting)

The Fighters Pack meshes use an **Unreal** skeleton (`pelvis, spine_01, upperarm_l,
thigh_l, calf_l`), while the Kubold clips use a **Mixamo/Biped** skeleton
(`Hips, Spine, LeftArm, LeftUpLeg, LeftLeg`). They are NOT directly compatible, so the clips
must be **retargeted**. The robust path is Godot's editor retargeter:

1. Select `Fighter_NN_Mesh.FBX` in the FileSystem dock → **Import** tab → **Advanced…**.
2. Under the skeleton node, open **Retarget → Bone Map**, choose **SkeletonProfileHumanoid**,
   and use **auto-map** (fix any unmapped bones by hand). Reimport.
3. Do the same for each `KB_*.fbx` (map its skeleton to the same humanoid profile and enable
   **Rest Fixer**). Reimport.
4. Both are now on the humanoid profile, so the retargeted clips play on the Fighter mesh.
   Point that character's `CharacterData.model_path` at the Fighter FBX.

> This is an editor (GUI) workflow; it can't be done blind/headless reliably. Until it's set
> up, those characters use the Maskman reskin so the build still ships.

## Texture note (web)
The packs ship **4K–8K TGA** textures (3–5 GB total) — impractical for a web build. This
project uses solid tinted materials instead, keeping the export small. To use real textures,
import them with **Process → Size Limit ≤ 1024** + VRAM compression and pick a small subset.

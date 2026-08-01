# Air Combo 2 Blaze Retarget Design

## Goal

Retarget `assets/third_party/fighter_animation_pack/anims/Air_Combo-2.fbx`
from its Unreal skeleton to Blaze's Maskman skeleton and use it for a new
`214+LK` light air-launcher special.

## Asset Flow

- Keep the licensed source FBX unchanged.
- Retarget and bake only this clip in Blender.
- Export the derived clip to
  `characters/blaze/assets/anims/retargeted/Air_Combo-2_Blaze.fbx`.
- Name the exported action `Air_Combo_2_Blaze`.
- Remove horizontal root travel while preserving useful vertical body motion.
- Keep the derived licensed binary gitignored like Blaze's other FBX assets.

The bone map covers the humanoid chains from `pelvis` to `Hips`, Unreal limb
names to Maskman limb names, and matching finger chains. Unreal IK-only bones
are ignored; Maskman facial and extra terminal bones remain in their rest pose.

## Gameplay Integration

Add one Blaze special using `MotionParser.QCB` and `GameConst.Btn.LK`. It is a
close-range, two-hit light launcher with less damage, reach, launch height, and
recovery than Ember Wheel. Its `anim_clip` is `Air_Combo_2_Blaze`, and the
retargeted FBX is added to Blaze's `RigConfig.anim_files`.

No runtime retargeter, shared abstraction, or batch conversion is added.

## Failure Handling

If the derived FBX is absent on a clean clone, Blaze remains loadable and the
existing animation fallback is used. The source pack and Gallery remain
unchanged.

## Verification

- Godot imports the derived FBX and exposes `Air_Combo_2_Blaze`.
- Its animation tracks target Blaze bone names.
- Blaze's animation library contains the clip when the asset is installed.
- `214+LK` selects the new move and preserves existing `214+HK`.
- The headless combat suite passes.

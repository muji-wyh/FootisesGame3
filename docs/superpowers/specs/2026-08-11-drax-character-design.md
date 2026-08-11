# Drax Character Design

## Goal

Add Drax as a playable Blaze gameplay clone using
`C:\uworks\editing_assets\robot2\bak4\Drax.fbx`, and make
`GALLERY-AIGeneratedAnimations` display Drax.

## Source Findings

- The source contains one 24,968-vertex character mesh plus an unrelated cube.
- It uses a 78-bone `mixamorig:*` armature with extra end bones, not the exact Blaze armature.
- It includes animation actions, cameras, and lights that must not ship.
- Its character material references one 4096px texture.

## Chosen Approach

Convert the Drax mesh once onto the immutable armature from Blaze's canonical model. Preserve
the character material, remove unrelated objects and source animations, limit skin weights to
four normalized influences, and export only the Drax mesh plus exact Blaze armature as
`characters/drax/assets/drax.fbx`.

Directly using the Mixamo source is rejected because its bone count, hierarchy, rest pose, and
animation data violate the Blaze model contract. Runtime retargeting is rejected because one
offline conversion is smaller and more reliable.

## Runtime Wiring

- Add `characters/drax/drax.gd`, following the existing Ultron module.
- Build Blaze data, then replace only `id`, `display_name`, and `model_path`.
- Preserve the FBX's embedded material.
- Register `drax` in `CharacterLibrary.REGISTRY`.
- Change `GALLERY-AIGeneratedAnimations` to
  `res://characters/drax/assets/drax.fbx`.

No new gameplay data, gallery implementation, or runtime retargeting layer is added.

## Validation

1. Run the bundled Blaze FBX validator on the converted model.
2. Add roster checks proving Drax is registered, copies Blaze gameplay, uses its own model, and
   preserves materials.
3. Update AI gallery checks to require Drax and keep the existing 48-clip playback, grounding,
   material, and bone-binding coverage.
4. Run the full headless suite and Web export.
5. Verify Drax deforms correctly in a match and in `/testaigeneratedanimations`, with no browser
   console or network errors.

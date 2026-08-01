# Gallery Assets Directory Design

## Goal

Move shared licensed gallery packs out of `characters/`, which is reserved for playable
fighter modules, without changing gallery behavior or combat presentation.

## Directory Layout

```text
assets/
  third_party/
    hit_reaction_animation/
      anims/
      model.fbx
      tex/
      README.md
    fighter_animation_pack/
      anims/
      model.fbx
      tex/
      README.md
    vfx_impact_and_hit/
      effects/
      models/
      textures/
      README.md

characters/
  blaze/
    assets/
```

`characters/blaze/assets/` remains unchanged because its model, animations, and textures are
owned by Blaze's `CharacterData` and `RigConfig`.

## Code and Scene Placement

Gallery scenes stay under `scenes/ui/`, and gallery scripts stay under `scripts/ui/`. They are
UI development tools, so moving them would add churn without improving ownership.

Update resource paths in:

- `scripts/ui/AnimationGallery2.gd`
- `scripts/ui/VFXGallery.gd`
- `scenes/ui/GALLERY-FighterAnimationPack.tscn`
- `scripts/match/MatchScene.gd`
- `tools/run_tests.gd`

All `.tscn` resources inside the VFX pack must update their texture and model references to the
new root.

## Git and Installation

The licensed binaries remain ignored. Replace the character-specific ignore rules for these
packs with `assets/third_party/**` binary/import rules while keeping each pack's `README.md`
tracked. Update the README paths so a clean clone clearly shows where locally licensed assets
must be copied.

## Runtime Behavior

No runtime behavior changes:

- Gallery scenes enumerate and display the same files.
- Match hit effects load the same VFX scenes.
- Missing VFX scenes continue to fall back to the existing character hit texture.
- Missing gallery packs continue to show their existing installation notice.

## Validation

Run the existing headless test suite. It must confirm the four gallery scenes exist, gallery
file discovery still works, and match VFX paths resolve when the local licensed pack is present.
Godot import must complete after the file moves so generated imports reference the new paths.

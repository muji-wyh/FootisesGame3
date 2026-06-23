# Characters

Each playable fighter is a **self-contained module** in its own directory, so adding or tuning a
character never touches the shared engine. The combat simulation (`scripts/`) is
character-agnostic; a character only supplies *data*.

> **Tune to the design contract.** This is a footsies-first game: grounded normals are defined
> by *role* (close check / mid-range ruler / mid-range variation / read-punish), not only by
> damage. Before changing Blaze's normals, read [`../docs/footsies-design.md`](../docs/footsies-design.md)
> and keep `_test_blaze_button_roles()` (in `tools/run_tests.gd`) green.

```
characters/
  blaze/
    blaze.gd            # static build() -> CharacterData : stats, moves, frame data,
                        #   per-normal clip map, and the RigConfig (visuals)
    assets/             # gitignored licensed model/anim/texture (README.md is tracked)
      maskman.fbx
      anims/KB_*.fbx
      tex/*.png
      README.md
```

## Anatomy of a character module (`<id>/<id>.gd`)

- `const ID` / `const DISPLAY_NAME` — registry metadata.
- `static func build() -> CharacterData` — builds the fighter:
  - vitals/colours (`max_health`, `walk_speed`, `color`, …),
  - `model_path` + `rig` (a `RigConfig`, see below) for the model-backed rig,
  - normals via `CharacterKit.add_standard_normals(c, dmg_scale, cancels, clip_map)` — shared
    "system normal" frame data with this character's clip names,
  - optional specials/supers via `CharacterKit.make_move({...})` when that character uses them.
- `RigConfig` (`scripts/combat/RigConfig.gd`) — everything the generic `AnimatedFighterRig`
  needs: animation source files, `state -> clip` map, looped/default/drive-rush clips, foot/root
  bones, the material surface→texture map + `tex_dir`, and the directional hit-reaction / KO /
  get-up clip templates. A character with a different skeleton/clip set just provides a different
  `RigConfig`.

## Adding a new character

1. Create `characters/<id>/<id>.gd` (copy `blaze/blaze.gd` as a template) and tune its data.
2. Drop its (gitignored) model/anim/texture into `characters/<id>/assets/` and re-import in the
   Godot editor (or `godot --headless --import`).
3. Register it in `scripts/data/CharacterLibrary.gd`:
   ```gdscript
   const REGISTRY := {
       "blaze": preload("res://characters/blaze/blaze.gd"),
       "<id>":  preload("res://characters/<id>/<id>.gd"),
   }
   ```
That's it — character select, the match, and the roster pick it up automatically. A character
without a model (no `rig`/`model_path`) still works via the procedural blockout rig.

> Headless tests: `godot --headless --script res://tools/run_tests.gd`. After adding a new
> `class_name` script, run `godot --headless --import` once so the class registers.

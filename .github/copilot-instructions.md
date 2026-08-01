# Copilot instructions for Brawl Arena

## Commands

Use the Godot 4.7 CLI on this machine:

```powershell
# Run in the editor / desktop
godot4.7 --path C:\uworks\FootisesGame3

# Refresh Godot's global class cache after adding class_name scripts or importing assets
godot4.7 --headless --path C:\uworks\FootisesGame3 --import

# Run the full headless combat / round / AI suite
godot4.7 --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd

# Export the Web build
godot4.7 --headless --path C:\uworks\FootisesGame3 --export-release "Web" C:\uworks\FootisesGame3\web-build\index.html

# Serve the exported build with the required WASM MIME type and headers
python tools\serve.py 8090
```

The current test harness has no CLI test filter. To run one test, temporarily limit `tools\run_tests.gd::_initialize()` to the target `_test_*()` call plus `_finish()`, run the same headless command, then revert the local harness edit.

## Validation workflow

For gameplay or presentation changes, use the smallest check that covers the change:

1. Run the headless harness command above for simulation/camera/HUD regressions.
2. Export Web again with the command above.
3. Serve `web-build\` on the requested port, for example:
   ```powershell
   python tools\serve.py 8000
   ```
4. Use Chrome DevTools MCP to open `http://localhost:8000/`.
5. Godot renders UI inside a canvas, so DOM selectors are not useful. Use canvas focus plus keyboard/clicks:
   - Main menu: choose `TRAINING`.
   - Character select: choose `FIGHT!`.
   - In Training, click/focus the canvas, then use `WASD` and `U/I/O/J/K/L` to reproduce the change.
6. Check DevTools console/network for errors and capture screenshots or canvas samples when validating visual effects.

## Architecture

This is a Godot 4.7 typed-GDScript 2.5D fighting game targeting HTML5/WASM. `project.godot` starts at `scenes\Main.tscn` and autoloads `scripts\autoload\Game.gd`; `Game` owns match configuration across scene changes and registers the InputMap in code.

The runtime path is: UI scenes choose mode/characters -> `scripts\match\MatchScene.gd` builds the stage, fighters, controllers, rigs, arena, HUD, audio, camera, and `RoundManager` -> `_physics_process()` advances `RoundManager.tick()` on the fixed 60 Hz simulation.

`scripts\match\Arena.gd` is the deterministic simulation core and has no HUD/camera dependencies, so tests can drive it headlessly. Its per-tick order is input polling, fighter advance, projectile spawn/update, pushboxes/bounds, `HitResolver.resolve()`, facing, visual pose, KO check. `HitResolver` snapshots contacts before applying them so trades work.

`scripts\fighter\Fighter.gd` is the fighter state machine: movement, attacks, hitstop, blocking, knockdown, Drive/Green Rush, combo bookkeeping, hit/hurt boxes, and queued projectiles. Move tuning lives in `scripts\combat\MoveData.gd` resources, not in match/UI code.

Characters are self-contained modules under `characters\<id>\<id>.gd` and are registered in `scripts\data\CharacterLibrary.gd`. Shared normal/move construction lives in `scripts\combat\CharacterKit.gd`; character-specific stats, frame data overrides, cancel routes, animation clips, and `RigConfig` stay in the character module.

Presentation reads simulation state only. `AnimatedFighterRig` uses a character's `RigConfig` and licensed gitignored assets when present; `MatchScene` falls back to the procedural `FighterRig` when model assets are missing.

## Conventions

Before balance, system, or training-mode changes, read `docs\footsies-design.md`. Blaze is tuned around a footsies-first contract: `st.MK` is the mid-range ruler, `st.MP` / `cr.MK` are variations, heavies are committal read/punish buttons, and Green Rush / DRC should amplify spacing wins rather than replace neutral. Keep `_test_blaze_button_roles()`, `_test_footsies_scenarios()`, and `_test_system_amplifies_neutral()` aligned with intentional tuning changes.

All gameplay timing is in fixed 60 Hz ticks (`GameConst.TICK_RATE`), not seconds. Keep gameplay logic in the simulation path (`Arena`, `Fighter`, `HitResolver`, `MoveData`, controllers); UI, audio, camera, and rigs should observe via signals/state and not affect combat results.

Controllers produce `InputFrame`s. The CPU is just another `InputController`, so combat code should not special-case player vs CPU.

When adding or tuning a character, prefer data changes in `characters\<id>\<id>.gd` and register the module in `CharacterLibrary.REGISTRY`; character select, matches, and roster tests pick it up from there.

For typed array properties such as `MoveData.cancel_into` and `MoveData.motion`, use `.assign(...)` rather than `Object.set(...)` with an untyped Array; `CharacterKit.make_move()` already handles this.

Avoid naming enums or `class_name`s after Godot native classes; `GameConst.Btn` is named that way because `Button` shadows a native class.

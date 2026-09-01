# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Brawl Arena is a Godot 4.7 typed-GDScript 2.5D fighting game (3D models on a 2D plane) exported to HTML5/WASM with the `gl_compatibility` renderer.

## Commands

There is no build system, package manager, or CI. The toolchain is the Godot 4.7 CLI (`godot4.7`, on PATH), two stdlib-only Python scripts, and Blender for the FBX model validator only. Run everything from the repository root.

**The agent shell here is Git Bash: use forward slashes.** A backslash path is eaten as an escape and silently mangled, not rejected — `python tools\serve.py` opens `toolsserve.py`, and `--export-release "Web" web-build\index.html` writes a file literally named `web-buildindex.html` in the repo root.

```bash
# Rebuild .godot/ (import cache + global class_name cache). REQUIRED on a fresh clone, after
# adding a class_name script, after adding ANY new .gd (this is what generates its .uid), and
# after dropping in new assets. It is a prerequisite for --script, not an optimization.
godot4.7 --headless --path . --import

# Play in the editor / on desktop (main scene: scenes/Main.tscn)
godot4.7 --path .

# Full headless suite (seconds, not minutes)
godot4.7 --headless --path . --script res://tools/run_tests.gd

# Prove the harness's failure path still exits non-zero (extra args go after a bare --)
godot4.7 --headless --path . --script res://tools/run_tests.gd -- --force-fail

# Export the Web/WASM build into web-build/ (the preset name is exactly "Web")
godot4.7 --headless --export-release "Web" web-build/index.html --path .

# Serve web-build/ on http://localhost:8090 -- this blocks, so run it backgrounded
python tools/serve.py
```

Deployment is manual to Azure Static Web Apps — see `README.md`. The export must be paired with a hand-written `web-build/staticwebapp.config.json` (navigation-fallback rewrite to `/index.html`, `.wasm`/`.pck`/`.js` MIME types, COOP/COEP headers); it is the hosted equivalent of `serve.py` and the export does not produce it.

### Running a single test

`tools/run_tests.gd` has no filter flag, and `_initialize()` (run_tests.gd:140) is a hand-maintained flat list of `_test_*()` calls. Subclass the harness rather than editing it — this leaves the tracked file untouched:

```bash
printf 'extends "res://tools/run_tests.gd"\n\nfunc _initialize() -> void:\n\t_test_dash()\n\t_finish()\n' > tools/_one.gd
godot4.7 --headless --path . --script res://tools/_one.gd
rm -f tools/_one.gd tools/_one.gd.uid
```

The subclass inherits `_build`/`_step`/`_check`/`_finish` and replaces only the registry.

### Interpreting results

`_finish()` prints `=== Results: N passed, M failed ===` and calls `quit(1 if _failed > 0 else 0)`. **Exit code and `0 failed` are the only stable signals.** The passing count is not a regression metric: tests needing licensed assets probe for them, print `SKIP: … (clean clone)` and return early, so `N passed` differs per machine. Every run also ends with `WARNING: … ObjectDB instances were leaked at exit` and `ERROR: … resources still in use at exit` — expected noise, not failure.

### Probes and asset validation

```bash
# Measure where each attack clip's strike lands, as a fraction of clip length.
# Output pastes straight into RigConfig.clip_impacts. Never hand-tune those numbers.
godot4.7 --headless --path . --script res://tools/probe_impact.gd -- blaze

# Cross-check every move's authored hitbox against where the animation actually strikes.
# MISS rows mean the box is drawn where the limb is not. Trust the Y column; X is tuned
# for footsies spacing.
godot4.7 --headless --path . --script res://tools/probe_hitheight.gd -- blaze

# Validate a candidate character FBX against the canonical Maskman armature.
# blender is NOT on PATH; --python-exit-code 1 is required or assertion failures exit 0.
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python-exit-code 1 \
  --python ".github/skills/creating-blaze-compatible-models/scripts/validate_blaze_fbx.py" \
  -- --candidate "<output.fbx>"
```

The armature in `characters/blaze/assets/maskman.fbx` is the immutable compatibility authority for the Kubold clips (see `.github/skills/creating-blaze-compatible-models/SKILL.md`) — matching bone names, auto-rigs and Mixamo rigs never substitute, and never write a replacement validator.

Unlike the runtime and the test suite, the probe scripts have **no clean-clone guard**: `probe_impact.gd:18` does `(load(ch.model_path) as PackedScene).instantiate()` with no `ResourceLoader.exists` check and immediately dereferences it, so both probes null-crash rather than SKIP on a clone without the licensed FBX.

Do **not** run `python tools/gen_audio.py` casually: it overwrites committed, licensed-pack WAVs in `assets/audio/` with lo-fi synthesized placeholders.

### Browser validation loop

Export → `python tools/serve.py` (backgrounded) → Chrome DevTools MCP at `http://localhost:8090/testblaze`, which deep-links past the menus into a Blaze-vs-Blaze training session. `serve.py` rewrites any extensionless path to `/index.html`, which is what makes `/testblaze` resolve. Godot renders everything into one `<canvas>`, so DOM selectors are useless — focus the canvas and drive it with `WASD` + `U/I/O` (LP/MP/HP) + `J/K/L` (LK/MK/HK), then validate via screenshots plus the console/network panes. Use `http://localhost:8090/` when the menu or character-select flow is what changed.

## Architecture

Most subsystem facts live in each file's `##` header — read those. What follows is only the cross-file contracts and traps that are invisible from any single file.

### Simulation / presentation split

`Arena.step()` (Arena.gd:38) is a fixed order — poll both inputs, advance both fighters, spawn queued projectiles, advance/cull projectiles, pushboxes, stage bounds, `HitResolver.resolve()`, facing, `update_visual()`, KO check — with both fighters completing each stage before either enters the next, which is what makes same-tick trades symmetric. Treat that function as the spec.

`HitResolver.resolve()` (HitResolver.gd:9) snapshots melee contacts then projectile contacts into one `pending` list before applying any, then applies at most one hit per victim per tick. **Melee entries are appended first, so melee wins a same-tick tie.** It stashes the hitbox∩hurtbox centre on the victim as `last_hit_point` for presentation.

The sim/presentation boundary has exactly one enforcement mechanism: `Fighter.rig` is optional (`var rig: Node = null`, Fighter.gd:161, invoked via `has_method("pose")`) and `update_visual()` (Fighter.gd:356) early-returns when it is null. That single guard is why `tools/run_tests.gd` can build Fighters with no rigs and no `MatchScene` and step the arena directly, with no test-only branching in the sim. Presentation may only read: the hitstop "crunch" writes the rig node's local `position.x` (`Fighter._impact_shake_x`), never `Fighter.position`. The one concession the other way is `Arena._resolve_visible_spacing()` (Arena.gd:148), which clamps separation to keep both fighters framed.

There are exactly two `_physics_process` functions in `scripts/` — `MatchScene` (MatchScene.gd:272) and `TrainingScene` (TrainingScene.gd:84); every other per-frame function is a presentation `_process`. Keep that invariant; it is what makes the tick contract checkable.

### Tick and round flow

All gameplay *timers* are integer tick counts (startup/active/recovery, hitstun, `INTRO_TICKS`, `time_left_ticks`, burnout…), while *positions* are delta-integrated. `GameConst.TICK_RATE = 60` (scripts/core/Constants.gd:8) mirrors Godot's default, which `project.godot` never overrides; the harness hardcodes `DELTA := 1.0/60.0`. `project.godot` also sets `physics/3d/default_gravity=0.0` on purpose — `Fighter` integrates gravity from `CharacterData`.

`RoundManager.tick(delta)` (RoundManager.gd:48) is the only *per-frame* entry point `MatchScene` calls (setup aside: `_ready` calls `round_manager.start()` at MatchScene.gd:109), and it decides whether the arena simulates: `INTRO → FIGHT → ROUND_OVER → MATCH_OVER`. `FIGHT` calls `arena.step()`; `ROUND_OVER` and `MATCH_OVER` call `arena.step_inactive()`, a reduced pipeline (poll, advance, `update_visual` only) that lets an airborne winner fall to the floor while nothing can hit, clamp, or be resolved; **`INTRO` does not advance the arena at all** — it only counts down and flips `arena.set_active(true)`.

Consequently rigs are posed twice per frame during FIGHT/ROUND_OVER (once at the end of the arena step, once after `round_manager.tick()`) and once per frame during INTRO — which is what keeps them posing through intro and round-over instead of holding the previous round's pose.

`RoundManager` also owns the `Fighter.active` flag, gating both input polling and Drive regen. `arena.ko` is emitted synchronously from the end of `arena.step()`, so `_end_round()` runs mid-tick; a KO landing during a SUPER defers the winner pose until the super **move** finishes (`_is_finishing_super()` checks frame data, not the animation — RoundManager.gd:138) or until `ROUND_OVER_TICKS` expires, whichever comes first. Round reset is split — `Arena.reset_positions()` plus `Fighter.reset_for_round()`; neither alone is complete.

### Data-driven moves

A move is never code. `characters/<id>/<id>.gd` builds a plain dictionary → `CharacterKit.make_move()` → a `MoveData` Resource → `CharacterData.add_move()` buckets it into `normals`/`specials`/`supers` → `Fighter._select_move_for()` (Fighter.gd:615) scans them on a button press → `_step_attack()` (Fighter.gd:715) executes it by comparing `state_frame` against `startup`/`active`/`recovery`. No move has its own node, script, or animation-driven timing; animation is fitted to frame data, never the reverse.

Selection priority: EX/Overdrive specials (≥2 bits of the move's own `multi_button` mask + motion + Drive), then supers, then the non-EX special whose motion completed most recently (`MotionParser.completion_age()`), then normals by button+stance with a same-button different-stance fallback. The overdrive path is still checked first but **no character defines one** — `blaze.gd` has zero `drive_cost`/`multi_button` occurrences, so `_select_overdrive()` (Fighter.gd:653) always returns null. Overdrives were removed so the two-punch chord could mean Green Rush/DRC; `_test_overdrive()` asserts they stay gone.

Normal lookup returns the **first** matching entry in `character.normals`, populated in the order of `CharacterKit.add_standard_normals`' `defs` array — that ordering is a contract.

Frame data is the only clock: `state_frame` 0 is the press tick, hitboxes go live at `state_frame >= startup`. Hitstop returns early from `advance()` **after** capturing the cancel buffer but **before** incrementing `state_frame`, so freezes never consume move frames and buffered follow-ups survive them. `FrameMeter` defines a frozen tick as exactly that.

One record — `_cancel_btn`/`_cancel_frame`/`_cancel_age` — serves three windows (`INPUT_BUFFER=4` neutral buffering, `CANCEL_BUFFER=6` cancel eligibility, `MOVE_END_BUFFER=20` re-arm on move end). It is captured every tick including hitstop but **ages only on advancing ticks where nothing was pressed**, so "age" is not wall-clock ticks.

Boxes are computed on demand, not nodes: `hurtboxes()` (Fighter.gd:1130) returns one AABB and expresses invulnerability by returning an **empty array**; `active_hitbox()` (Fighter.gd:1143) builds one AABB from `hit_offset`/`hit_size` mirrored by facing (air moves re-aim at the opponent's real side so cross-ups hit). Multi-hit gating suppresses the hitbox rather than filtering in the resolver.

Counter / Punish Counter / meaty are classified from the **victim's** state at impact and must be read before `current_move` is cleared. Combo state also lives on the victim (`combo_count`/`combo_damage` count hits *taken*) — which is why `MatchScene` wires `f1.combo_changed → hud.set_combo(1, …)` and vice versa.

Projectiles are never spawned by the Fighter: a move appends to `Fighter.pending_projectiles` and `Arena` drains that queue, so a Fighter adds no nodes to the tree.

### Drive systems

Drive is stored in fine units — 1000 per bar, `max_drive = 6000`. Three mechanics share one input predicate, `_is_live_two_punch_chord()` (Fighter.gd:287), which requires a rising edge on a punch **and** ≥2 punches held, so a sequential LP→MP string stays a normal combo:

1. **Green Rush mode** — 1 bar, from neutral, a 180-tick *mode* rather than a state. `_step_neutral` redirects into `_step_green_rush_mode` while the timer is live, so walking or crouching keeps it alive. Checking `state == State.GREEN_RUSH` is therefore wrong; use `green_rush_active()` (and `drive_rush_fx_active()` for presentation).
2. **GREEN_RUSH_DASH** — forward-forward while in that mode.
3. **DRIVE_RUSH (DRC)** — 3 bars, only from a *connected* non-super move, buffering a chord up to 30 real ticks through hitstop.

The cost inversion is intentional: the cheap-feeling rush is the expensive one, gated behind already winning a contact. The two advantages are paid once each and in different places — `_start_drive_rush()` (Fighter.gd:519) immediately extends the opponent's stun, while `_start_move()` arms `drive_rush_pending`/`green_rush_pending` (Fighter.gd:696) on the first normal out of the rush, which `HitResolver` drains via `drive_rush_hit_bonus()` on melee hits (so the bonus also applies on block).

### Input and controllers

`InputController.poll(self, opponent) → InputFrame` is the entire contract, and nothing in `Fighter`/`Arena`/`HitResolver` inspects the controller type. `CpuController` synthesises `InputFrame`s and rolls motions out digit-by-digit at 2 ticks each, subject to the same `MotionParser` leniency a human gets; the training dummy uses the bare base class; the harness uses a `Manual` subclass whose frame is set per tick. `CpuController` is the only RNG in the simulation path (global `randf()`/`randi()`), so AI-involved assertions need `seed()` first — the suite uses `seed(20260619)`.

`InputFrame.numpad(facing)` converts world-space direction into facing-relative digits; `MotionParser` matches motions as a lenient *subsequence* over that history. `Fighter.poll_input()` always pushes a frame so buffer index N means N ticks ago — but it pushes an **empty** frame while locked out, which wipes motion history during hitstun/blockstun/knockdown. `WAKEUP` is the exception (guard direction polls, attacks do not).

### Character data layer

A character is a pure static namespace at `characters/<id>/<id>.gd` (`extends RefCounted`, never instantiated). `characters/README.md:39` has the full three-Resource split and the add-a-character procedure. What it does not say:

- `scripts/data/CharacterLibrary.gd:8` (`REGISTRY`) is the **only** shared file that knows a character exists; everything else in `scripts/` is character-agnostic.
- There is no caching — every `create()` rebuilds the whole move table.
- An unregistered id silently falls back to `blaze`, which masks a missing registry line.
- `CharacterData.rig == null` opts the whole model pipeline out.

`CharacterKit.add_standard_normals()` supplies the *structure* of the 18 system normals (6 buttons × 3 stances) and contains **zero clip names**; the character module supplies all clip names, hitbox geometry and final frame data. This is machine-enforced: `_test_animation_ownership()` (run_tests.gd:1274) reads `CharacterKit.gd` as text and asserts it contains no `KB_` substring, then builds a scratch character with an empty clip map and asserts every normal comes out with `anim_clip == ""`.

`cancel_into` holds plain move-id **strings** resolved at runtime, so declaration order is irrelevant — but a typo is a silent dead route with no error, caught only by explicit assertions.

### Rigs and presentation

Two rigs sit behind one duck-typed `build(CharacterData)` + `pose(Fighter)` contract; `MatchScene._attach_rig()` (MatchScene.gd:111) picks between them. The gotchas:

- A model that loads but whose clip graft failed degrades **exactly like a missing model**, silently, to the procedural `FighterRig` blockout — `arig.ok` is just `_player.has_animation(lib_name + "/" + idle_clip)` (AnimatedFighterRig.gd:54). If a character renders as primitives, check the graft and the idle clip name before assuming the FBX is gone.
- Clip "retargeting" is node-path coincidence, not a system: clips carry `Skeleton3D:<bone>` track paths and the player's `root_node` is `".."`, so a new model must share the Kubold bone names **and** keep `Skeleton3D` a direct child of the AnimationPlayer's parent.
- `RigConfig.clip_impacts` is **measured by `probe_impact.gd`, never hand-tuned**. A clip missing from it still plays — by cramming the whole mocap clip into the move, 2–4× too fast. Re-run the probe whenever an attack clip changes.
- An **empty** `surface_textures` is a meaningful mode, not an unconfigured one: `apply_materials` returns immediately and the imported FBX materials survive.
- Hit reactions are template-driven, never enumerated: `_first_existing` (AnimatedFighterRig.gd:262) returns the first grafted candidate and degrades to `hit_fallback`, which is what lets a partial clip set work with no engine change.

`HUD` **state** changes arrive by signal (health/meter/drive, combo, banners, timer, rounds, seeded in `_wire_hud`, MatchScene.gd:131); its per-frame animation (`tick_counter`/`tick_visuals`) and the Drive-Rush tint/burnout flags are pushed directly from `MatchScene._physics_process` / `_update_drive_rush` (MatchScene.gd:249).

`MatchScene`'s slow-mo dips scale `Engine.time_scale` only — fighters cover less ground per tick while frame counters run normally. A frame-accurate slowdown needs **both** halves: `TrainingScene.toggle_slow_speed()` (TrainingScene.gd:231), which lowers `Engine.physics_ticks_per_second`, and the `Engine.time_scale = minf(_slowmo.scale, _speed_scale)` line in `TrainingScene._physics_process` (TrainingScene.gd:101). Together they keep `delta` at 1/60; the function alone gives 18 ticks/s at full time scale. Both scenes restore those globals plus `HitSpark.clear_fx_pool()` in `_exit_tree` — the particle pool lives *outside* the tree, so any new exit path must preserve that cleanup.

### Scenes, boot, and deep links

Every `.tscn` is a script-built stub (root node + script reference; all UI, 3D content, cameras and lights built imperatively in `_ready()`), so **never edit UI in the editor's scene dock** — nodes added there sit alongside what the script builds. The one exception is `scenes/ui/GALLERY-FighterAnimationPack.tscn`, which configures `AnimationGallery2.gd` purely through exported properties; that is the intended pattern for new animation-pack galleries.

`TrainingScene extends MatchScene` but overrides `_ready()` without calling super, and deliberately has no `RoundManager`, so training never times out. **That is why the impact-VFX shader warm-up lives in `MatchScene._enter_tree()` (MatchScene.gd:45)** — moving it to `_ready()` would silently stop warming training and reintroduce an ~850 ms first-hit stall on Web. Training hotkeys: TrainingScene.gd:215 (`Tab` toggles the move list globally).

Navigation is a flat, stateless chain of `Game.goto_scene()` → `change_scene_to_file()` with no scene stack. The `Game` autoload (scripts/autoload/Game.gd) is the entire cross-scene state and registers the **whole InputMap in code** at `_ready` (P1: keyboard WASD/UIO/JKL **and** gamepad device 0; P2: gamepad device 1 only — no P2 keyboard layout). Add new actions in `Game._register_inputs`.

Boot goes `scenes/Main.tscn` → `Main.apply_boot_link(url)` (Main.gd:31), which takes the URL as a *parameter* so the headless suite can test routing without a browser; four substring-matched markers are declared there, so `/marker`, `/#marker` and `/?marker` are equivalent. Only `testblaze` mutates `Game`; the three gallery markers must leave match config untouched. **A new gallery or route touches four places, not one:** `Main.gd` (marker + scene const), `MainMenu.gd` (menu button), a stub `scenes/ui/GALLERY-*.tscn`, and `run_tests.gd` (`_test_boot_deep_link`, run_tests.gd:1140, asserts all three URL forms).

`MatchScene` reaches the autoload via `get_tree().root.get_node("Game")` and duck-typed `.get()`/`.set()`/`.call()` (MatchScene.gd:311), and `TrainingScene._build_training(game_override)` accepts a substitute node — both purely so the headless suite can drive real scenes with injected config. Preserve that indirection.

Five gallery scenes are backed by four scripts: `AnimationGallery.gd` is both the shared base (orbit camera, UI, environment, notices) **and** the FightingAnimsetPro gallery itself; `AnimationGallery2.gd` (two scenes, differentiated by exports), `VFXGallery.gd` and `CartoonFXGallery.gd` extend it **by path** (`extends "res://scripts/ui/AnimationGallery.gd"`) and override `_ready` entirely, configuring the base by writing its underscore vars. `_paths_from_files` is not a base-class hook: the implementations differ in signature (`VFXGallery`'s takes a directory argument because it recurses) and in `.import`/`.remap` handling (`.fbx.import` / `.png.import`+`.png.remap` / `.tscn.remap`). Any new directory scanner needs its own dual handling: in an exported PCK `DirAccess` lists only `foo.fbx.import` / `foo.png.remap`, never the original, so a scanner that works in the editor returns nothing in the web build.

### Audio

`AudioManager` lives under `scripts/autoload/` but is **not** an autoload — `project.godot` registers only `Game`. `MatchScene` and `TrainingScene` each construct their own (`AudioManager.new()`), so calling it as a singleton fails. `MoveData.sfx` is not free-form: it must name one of the 17 entries in `AudioManager.SFX` (AudioManager.gd:8), each loaded from `res://assets/audio/<name>.wav`. An unlisted name silently plays nothing.

### Missing-asset degradation

All licensed FBX/TGA/PNG/TSCN under `characters/**/assets/` and `assets/third_party/` are gitignored along with their `.import` siblings (.gitignore:32); only the per-directory READMEs are tracked. The runtime and the test suite are written so a clean clone still runs and still passes — rig falls back to the blockout, galleries show an "assets not installed" notice, `HitSpark` degrades from particle scene → texture quad → bare core+ring, tests probe-and-`SKIP`. Never `git add -f` those paths. Conversely, `assets/cartoon_fx_pack/`, `assets/audio/` and `assets/bgm/` **are** tracked, so do not assume everything under `assets/` is local-only.

## Conventions and contracts

**Tests come first and are not optional.** Every behavioural commit in this repo also modifies `tools/run_tests.gd` — extend an existing `_test_*` or add one and register it in `_initialize()`, before the implementation. Plans under `docs/superpowers/plans/` open Task 1 with "Write failing … tests" and carry a `REQUIRED SUB-SKILL: superpowers:subagent-driven-development (recommended) or superpowers:executing-plans` preamble. A green suite on an untested change is not a pass.

Defining a `_test_*` function is not enough — you must also append the call to `_initialize()`; `_test_rise_interruption_lands()` (run_tests.gd:3800) is fully written and has never run. `_test_vfx_gallery()` is the only awaited test and is called last, immediately before `_finish()`; any future test needing a frame must also be awaited and placed in that tail block, or `quit()` will beat it.

**The footsies balance contract is executable.** `docs/footsies-design.md` assigns each of Blaze's grounded normals a role, and three tests encode it — `_test_blaze_button_roles()` (run_tests.gd:374), `_test_footsies_scenarios()`, `_test_system_amplifies_neutral()` — using two distinct metrics, `_reach()` (tip reach) and `_max_active_reach()` (which adds travel from `advance`). Read the doc before any balance, system, or training change; move the doc, the data and the tests together; never silence a failing role test.

**Typed arrays must use `.assign()`.** `MoveData.cancel_into` (`Array[String]`) and `MoveData.motion` (`Array[int]`) are filled through reflective `Object.set()` over a dictionary, which silently drops an untyped Array and leaves the property **empty** — no error. `CharacterKit.make_move()` (CharacterKit.gd:9) special-cases exactly these two keys, and any character module writing `set()` directly must do the same. Related: `Object.set()` also silently no-ops on a misspelled property name, so a typo in a tuning table produces no warning and no effect.

**Never name an enum or `class_name` after a Godot native class.** `GameConst.Btn` is spelled that way because `Button` is built-in, and `Constants.gd` declares `class_name GameConst` for the same reason.

**Never put a clip name in shared code** — no `KB_*` string may appear in `scripts/combat/CharacterKit.gd` (asserted by reading the file's source text).

`run_tests.gd` drives UI scenes through their own methods, including leading-underscore ones (`_paths_from_files`, `_animation_paths`, `_effect_paths`, `_spawn_texture`) as well as the public `apply_boot_link`, so renaming a "private" UI method breaks tests.

`.gitattributes` forces LF for `*.gd`, `*.tscn`, `*.tres`, `*.godot`, `*.import`, `*.uid`, `*.cfg`, `*.svg` — do not introduce CRLF. Every `.gd` has a committed sibling `.uid`, and Godot generates it: after creating any new script run `godot4.7 --headless --path . --import`, then commit the `.gd` and the generated `.uid` together. Never hand-write a `.uid`.

Feature work follows a spec → plan → implement pipeline recorded in `docs/superpowers/specs/YYYY-MM-DD-<slug>-design.md` and `docs/superpowers/plans/YYYY-MM-DD-<slug>.md`, visible in the git history as `Design X` → `Plan X` → implementation commits. `.superpowers/` (the local task journal), `.worktrees/`, `.godot/` and `/web-build/` are gitignored and are never a shared source of truth.

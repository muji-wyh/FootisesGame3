# Brawl Arena

An original **2.5D fighting game** (3D models on a 2D plane, *Street Fighter 6*–style)
that runs in **Chrome** via Godot 4's HTML5/WebAssembly export.

> **Legal:** This project contains **no** Street Fighter assets, characters, or names.
> All content is original or royalty-free: fighters are placeholder blockout models and
> all audio is self-synthesised (CC0, see `tools/gen_audio.py`).

## Tech stack

| | |
|---|---|
| Engine | Godot 4.7 (standard / GDScript build) |
| Language | Typed GDScript |
| Rendering | `gl_compatibility` (WebGL2-friendly) |
| Target | HTML5 / WASM, no-threads (runs from any static host) |
| Simulation | Deterministic fixed **60 Hz** tick; frame-based timing; data-driven moves |

## Controls

Six-button layout (LP MP HP / LK MK HK), with standing, crouching, and air versions of
every normal.

| Action | Keys |
|---|---|
| Move / crouch / jump | `W A S D` |
| Light / Medium / Heavy punch | `U` / `I` / `O` |
| Light / Medium / Heavy kick | `J` / `K` / `L` |
| Dash | double-tap forward / back |

Gamepad: device 0 (D-pad; face buttons + shoulders for the 6 attacks). A second player
can use a gamepad on device 1 in Local 2P; there is no keyboard layout for P2.
`Esc` returns to the menu. Attacks differ by stance: hold **down** for crouching normals
(lows), or attack while **jumping** for air normals (overheads). `Tab` shows the move list.

## Drive system (SF6-style)

A six-bar **Drive gauge** (separate from the Super meter) powers the modern mechanics:

| Mechanic | Input | Cost |
|---|---|---|
| **Drive Rush** (绿冲) | double-tap forward (with Drive) | 1 bar |
| **Drive Rush Cancel** (DRC) | double-tap forward during a *connected* normal | 3 bars |
| **Overdrive (EX) special** | special motion + **two punches** or **two kicks** | 2 bars |

A Drive Rush trails a cyan **afterimage** streak and lets the first normal out of it slide
in and link (a built-in advantage). Empty the gauge and you enter brief **Burnout** (the
gauge flashes red and stops regenerating). Combos are tracked by an on-screen **hit
counter** and use **damage scaling** so long routes taper instead of deleting the bar.
There's also a small **input buffer**, so a slightly-early attack still comes out. The HUD
shows a recoverable-health trail and a glow when the Super meter is full.

## Run it

Godot 4.7 is installed at `C:\uworks\tools\Godot_v4.7-stable_win64.exe` on this machine.

```powershell
# Play in the editor / desktop
& C:\uworks\tools\Godot_v4.7-stable_win64.exe --path C:\uworks\FootisesGame3

# Run the headless combat/round/AI test suite (27 assertions)
& C:\uworks\tools\Godot_v4.7-stable_win64_console.exe --headless --path C:\uworks\FootisesGame3 --script res://tools/run_tests.gd
```

## Build & play in Chrome

```powershell
# 1. Export the web build (templates already installed)
& C:\uworks\tools\Godot_v4.7-stable_win64_console.exe --headless --path C:\uworks\FootisesGame3 `
    --export-release "Web" C:\uworks\FootisesGame3\web-build\index.html

# 2. Serve it (sets application/wasm + isolation headers)
python tools/serve.py 8090

# 3. Open http://localhost:8090/ in Chrome
```

The build is verified to boot and play in Chromium (Edge) — see `tools/shotter/shot.js`,
which drives the build headlessly and screenshots the menu and a live match.

## Architecture

Everything runs on a deterministic fixed tick; presentation only ever *reads* simulation
state. The CPU is "just another controller", so combat code never special-cases it.

```
scripts/
  core/        Constants, InputBuffer, MotionParser (special-move detection)
  input/       InputFrame, InputController, PlayerController
  ai/          CpuController                      (range-based AI, emits inputs)
  combat/      MoveData, CharacterData, RigConfig, CharacterKit, HitResolver, Projectile
  data/        CharacterLibrary                   (registry: id -> character module)
  fighter/     Fighter (state machine + combat), FighterRig (procedural model)
  stage/       Stage                              (floor/walls/lights, built in code)
  match/       Arena (the step loop), FightCamera, RoundManager, MatchScene
  ui/          Main, MainMenu, CharacterSelect, ResultsScreen, HUD
  autoload/    Game (singleton: input map, match config), AudioManager

characters/    one self-contained module per fighter (see characters/README.md)
  blaze/       blaze.gd (stats/moves/frame data + RigConfig) + assets/ (gitignored)
```

**Per-tick order** (`Arena.step`): poll inputs → advance both fighters → spawn/move
projectiles → resolve pushboxes/stage bounds → `HitResolver` (snapshot then apply, so
trades work) → update facing → pose rigs → KO check.

**Tuning:** each fighter is a self-contained module under `characters/<id>/`; all balance
lives in that module's `build()` as `MoveData` (startup/active/recovery, damage, hitstun/
blockstun, guard level, knockback, meter, hitbox geometry, cancel routes) plus its `RigConfig`
visuals. The engine is character-agnostic — no engine changes needed to rebalance or add a
character. See `characters/README.md`.

## Real 3D characters (FBX / Mixamo / Kubold)

The blockout fighters are swappable — the rig only *reads* `Fighter` state, it never
affects gameplay. **`AnimatedFighterRig` is already implemented** and generic: a character that
provides a `RigConfig` + `model_path` gets an imported model whose animation clips are grafted
on and driven from `Fighter.state` / `current_move` (per-move clip via `MoveData.anim_clip`). If
the model is missing, `MatchScene` falls back to the procedural blockout, so a clean clone
still runs.

Dropping the licensed **Fighters Pack** + **Kubold Fighting Animset Pro** FBX into
`characters/blaze/assets/` (gitignored) reskins Blaze with the animated Maskman model + mocap
clips. See `characters/blaze/assets/README.md` for the import details and the per-pack skeleton
notes, and the editor **retargeting** workflow needed to animate the Unreal-rigged Fighters Pack
characters with the Kubold (Mixamo/Biped) clips.

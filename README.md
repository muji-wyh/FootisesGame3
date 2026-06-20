# Brawl Arena

An original **2.5D fighting game** (3D models on a 2D plane, *Street Fighter 6*–style)
that runs in **Chrome** via Godot 4's HTML5/WebAssembly export. Built as a vertical
slice: three characters, one stage, local 2-player and vs-CPU, with a full fighting-game
combat loop.

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
(lows), or attack while **jumping** for air normals (overheads).

**Specials** (motion + button, facing the opponent):
- Fireball — *down, down-forward, forward* + punch
- Rising uppercut — *forward, down, down-forward* + punch (anti-air launcher)
- Hurricane kick — *down, down-back, back* + kick (Blaze; advancing multi-hit)
- Super — *qcf, qcf* + button (requires a full meter; multi-hit on Blaze)

**Roster:** **Blaze** — a fiery rushdown shoto with a fireball, an anti-air uppercut, a
multi-hit hurricane kick, and a multi-hit super. Each special has its own synthesized
sound effect.

**Animation Gallery** (main-menu item): a big scene showing one character per Kubold mocap
clip (~235), each looping its animation with a name label. Pan with WASD, raise/lower with
Q/E, `Esc` to return. (Requires the licensed model/anim FBX in `assets/models/`.)

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
  combat/      MoveData, CharacterData, HitResolver, Projectile
  data/        CharacterLibrary                   (the roster + frame data, as code)
  fighter/     Fighter (state machine + combat), FighterRig (procedural model)
  stage/       Stage                              (floor/walls/lights, built in code)
  match/       Arena (the step loop), FightCamera, RoundManager, MatchScene
  ui/          Main, MainMenu, CharacterSelect, ResultsScreen, HUD
  autoload/    Game (singleton: input map, match config), AudioManager
```

**Per-tick order** (`Arena.step`): poll inputs → advance both fighters → spawn/move
projectiles → resolve pushboxes/stage bounds → `HitResolver` (snapshot then apply, so
trades work) → update facing → pose rigs → KO check.

**Tuning:** all balance lives in `CharacterLibrary.gd` as `MoveData` — startup/active/
recovery, damage, hitstun/blockstun, guard level, knockback, meter, hitbox geometry,
cancel routes. No engine changes needed to rebalance.

## Real 3D characters (FBX / Mixamo / Kubold)

The blockout fighters are swappable — the rig only *reads* `Fighter` state, it never
affects gameplay. **`AnimatedFighterRig` is already implemented**: a character that sets
`CharacterData.model_path` gets an imported model whose animation clips are grafted on and
driven from `Fighter.state` / `current_move` (per-move clip via `MoveData.anim_clip`). If
the model is missing, `MatchScene` falls back to the procedural blockout, so a clean clone
still runs.

Dropping the licensed **Fighters Pack** + **Kubold Fighting Animset Pro** FBX into
`assets/models/` (gitignored) reskins Blaze with the animated Maskman model + mocap
clips. See `assets/models/README.md` for the import details, the per-pack skeleton notes,
and the editor **retargeting** workflow needed to animate the Unreal-rigged Fighters Pack
characters with the Kubold (Mixamo/Biped) clips.

## Scope

In: 3 characters, 1 stage, local 2P + vs CPU, normals/specials/supers (incl. multi-hit),
blocking, hitstun/knockdown, combos, projectiles, best-of-3 rounds, menus, audio.
Out (future): online/rollback netcode, larger roster, training/arcade modes.

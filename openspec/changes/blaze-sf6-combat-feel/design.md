## Context

Brawl Arena runs a deterministic 60 Hz simulation where presentation only reads state. Blaze already has a full normal/special/super move set with a `MoveData.cancel_into` lattice, an `InputBuffer` with a `pressed_within(button, window)` helper, double-tap dash detection (`_update_dash_taps` → `_dash_req`), and a single `meter` resource used for supers. The combat cannot produce combos because the cancel path in `Fighter._step_attack` calls `_select_cancel → _select_move`, which requires `inp.pressed` (a rising edge on the exact tick) and only runs during `is_recovering(state_frame)`. Buffered or mashed inputs are therefore ignored, and the existing `pressed_within` buffer is unused on the attack path. The headless harness (`tools/run_tests.gd`) has no cancel/combo test, so this regressed silently.

The goal is SF6-Ken game feel: reliable target-combo cancels, a Drive Rush Cancel off `→→`, and a separate regenerating Drive Gauge — all on Blaze only for now, all data/tuning where possible per the repo convention that "all balance lives in `CharacterLibrary` as `MoveData`."

## Goals / Non-Goals

**Goals:**
- Make every existing `cancel_into` route reachable by buffering the cancel input and opening the window at first contact.
- Tune Blaze's normals/frame data so confirmed bread-and-butter strings are *true* combos (victim stays in hitstun throughout).
- Add a separate, regenerating Drive Gauge decoupled from the Super meter, with a HUD signal.
- Implement Drive Rush Cancel from a connected normal (`→→`) and raw Drive Rush from neutral, both spending Drive, with the first follow-up normal gaining frame advantage to extend combos.
- Wire a Drive Rush run clip on the animated rig with graceful fallback.
- Cover all of the above with headless tests.

**Non-Goals:**
- Drive Impact, Drive Parry, Overdrive (EX) specials, Drive Reversal, and Burnout (the gauge is designed to support these later).
- Throws/throw-tech and combo damage scaling.
- Characters other than Blaze; netcode; new stages.

## Decisions

### D1 — Fix combos by buffering the cancel, not by adding per-move window data
`_select_cancel` will consult `input_buffer.pressed_within(button, CANCEL_BUFFER)` (a small window, ~4 ticks) instead of the current-tick rising edge, and the cancel gate in `_step_attack` will open as soon as `move_hits_done > 0` (first contact) through end of recovery — dropping the `is_recovering(...)`-only restriction. Motion-based cancels (specials/supers) continue to validate via `MotionParser` over the buffer.
- *Alternatives considered:* per-move `cancel_window_start/end` fields (more data, more authoring burden, not needed to fix the root cause); a global "chain on any press" (too loose, eats neutral). Buffering is the minimal root-cause fix and reuses an existing helper.

### D2 — Drive Gauge as new state on `Fighter` + config on `CharacterData`, in fine internal units
Add `drive`/`max_drive` to `Fighter` and a `max_drive` (≈6 bars) plus regen rate to `CharacterData`. Store the gauge in fine internal units (e.g., 1000/bar) for smooth per-tick regen; expose bars to the HUD via a new `drive_changed(current, maximum)` signal. Regenerate a fixed amount per tick in `advance()` when below max and not mid-spend, clamped to `[0, max]`. Reset to full in `reset_for_round()`.
- *Alternatives considered:* reuse the existing `meter` (rejected by the user — conflates Super and Drive, blocks future DI/Parry/EX/Burnout). A separate gauge matches SF6 and is forward-compatible.

### D3 — Dedicated `DRIVE_RUSH` state rather than a flag on `DASH_F`
Add a `State.DRIVE_RUSH` that advances forward at a tuned speed for a tuned duration and is itself cancellable into a grounded normal. Ordinary `DASH_F` is unchanged for movement. A `drive_rush_pending` flag is set when a normal is performed out of the Drive Rush so its hit applies a one-time advantage bonus.
- *Alternatives considered:* boolean on `DASH_F` (muddier posing and cancel rules). A distinct state keeps posing (run clip), cancel rules, and advantage bookkeeping clean.

### D4 — Model frame advantage as one-time bonus hitstun on the first post-rush normal
The first normal out of a Drive Rush adds a fixed bonus to the victim's hitstun on contact (mirrors SF6's ≈+4 on the defender), making otherwise-impossible links true. The bonus is consumed after one hit.
- *Alternatives considered:* reducing the follow-up's startup (changes whiff/hurtbox behavior and spacing). Bonus hitstun is the simplest deterministic lever and is already how Counter/Punish add stun.

### D5 — Reuse existing double-tap detection; `→→` is RDR in neutral, DRC off a connected normal
`_update_dash_taps` already produces `_dash_req` each tick. The same `→→` input drives both forms: `_step_attack` reads `_dash_req > 0` (within the open cancel window, on a connected cancellable normal) to trigger a **Drive Rush Cancel (DRC)**; `_step_neutral` converts a neutral `_dash_req > 0` into a **Raw Drive Rush (RDR)** when Drive is affordable, falling back to the existing ordinary forward dash only when Drive is unavailable. RDR therefore replaces the neutral movement dash whenever Drive can be spent — this is intentional (see Open Questions, resolved). Both forms enter the shared `DRIVE_RUSH` state; they differ only in Drive cost (RDR lower, DRC higher) and entry point.
- *Alternatives considered:* a dedicated button or a parry-prefixed RDR input à la SF6 (not what the user wants — they want plain `→→` to be RDR).

### D6 — All Blaze balance stays in `CharacterLibrary` data; engine only gains generic mechanics
Frame-data nudges for true combos, Drive Rush move parameters, and `cancel_into` routes live in `CharacterLibrary.gd`/`MoveData`. The engine gains only generic, character-agnostic mechanics (buffering, gauge, Drive Rush state). New `MoveData` fields (e.g., `drive_rush_cancellable`) are optional with safe defaults.

### D7 — Animation wiring via `STATE_CLIP` + a `DRIVE_RUSH` branch in `_state_clip`
Map Drive Rush to a forward run/skip Kubold clip (e.g., `KB_Run`/`KB_SkipFwd_1`) using the rig's existing `_first_existing` fallback chain, so a missing clip degrades to an available one and the procedural rig is unaffected.

### D8 — Verify with the headless harness
Add `_test_combo` (buffered cancel produces a chain; victim stays in `HITSTUN` across a true-combo route), `_test_drive_gauge` (full at round start, spend gated by affordability, regen over ticks, independent of Super meter), and `_test_drive_rush` (DRC from a connected normal spends Drive and extends a combo; raw DR falls back to ordinary dash without Drive).

### D9 — Rising uppercut as a scripted positional arc, not a fully airborne state
Make the uppercut leap via a new `MoveData.rises: bool` + `rise_height: float`. In `_step_attack`, for a rising move, drive `position.y` along a tick-based arc (peaks partway through, returns to 0 by move end) while `on_ground` stays `true`, so `_apply_physics` does not fight the curve (its `velocity.y` stays 0; the ground clamp does not fire until the arc returns to 0, raising no spurious landing). The hitbox/hurtbox are already `position`-relative, so they follow the leap for free. Also swap the signature clips in data: fireball → `KB_Projectile_4`, uppercut → `KB_crouch_m_Uppercut_R_2`.
- *Alternatives considered:* a true airborne DP (`on_ground = false`, gravity arc, vulnerable landing recovery, optional startup invincibility). Rejected for this change because it touches landing/blocking/air-hit classification and overlaps the unscoped "DP invuln + reversals" thread; the scripted arc delivers the requested visual leap (人物跳起来) with minimal, deterministic engine change. The true DP remains a clean future upgrade (flip `rises` semantics to airborne).
- *Out of scope (this change):* `cr.HK` Sweep clip de-duplication and other normal-clip beautification, and hit-reaction (受击) clip changes — parked per user selection.

## Risks / Trade-offs

- **Frame-data tuning could unbalance neutral or make lights too plus.** → Keep all tuning in Blaze's data, gate behavior behind tests asserting true-combo windows, and leave other balance untouched.
- **Raw Drive Rush replacing the neutral movement dash could waste Drive or feel bad.** → Only convert to Drive Rush when affordable; preserve ordinary dash as the fallback; consider gating raw DR behind a deliberate variant (see Open Questions). Revisit after playtest.
- **Opening the cancel window during active/hitstop could allow unintended early cancels.** → Still require `move_hits_done > 0` (contact happened) and membership in `cancel_into`; whiffs remain non-cancellable for specials.
- **Determinism regressions.** → All new timing is tick-based in `advance()`/`InputBuffer`; no `_process` gameplay, no wall-clock; CPU uses the same path.
- **HUD real estate for a second gauge.** → Add a compact Drive bar beneath the Super meter; presentation-only.

## Open Questions

- Exact costs and regen: start from SF6-like values (DRC ≈3 bars, RDR ≈1 bar, full regen in a few seconds) and tune in playtest.
- **Resolved (per user direction):** `→→` from neutral is Raw Drive Rush (RDR) directly — no separate deliberate input — and `→→` off a connected normal is the Drive Rush Cancel (DRC). RDR replaces the neutral movement dash whenever Drive is affordable; an ordinary dash occurs only when Drive is unavailable.
- Should Drive Rush Cancel be allowed on block (SF6 yes, for pressure)? Current plan: yes, since cancels are enabled on block — confirm this is desired for Blaze.

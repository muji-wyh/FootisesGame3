## Why

Blaze's combat does not feel like *Street Fighter 6*: normals cannot be reliably chained into combos, and the forward dash is a plain reposition rather than a Drive Rush. The root cause is a real bug — the cancel path in `Fighter._step_attack` only accepts a frame-fresh button press during a move's recovery window, with no input buffering, so the natural human behaviors (buffering the next attack, or mashing) both fail. The `MoveData.cancel_into` lattice already exists but is effectively unreachable. Fixing the buffer and layering an SF6-style Drive system on top turns the existing data into the intended "Ken" game feel.

## What Changes

- **Universal input buffering for cancels and actions.** A short rolling buffer (a few ticks) lets a buffered or mashed button satisfy a cancel, and opens the cancel window at first contact (active/hitstop) instead of only during recovery. This single fix makes every existing `cancel_into` route fire.
- **Ken-style cancel / target-combo lattice for Blaze.** Tune the gatling routes (lights → mediums → heavies, mediums/`cr.MK` → specials) and frame data so confirmed strings are *true* combos (the victim stays in hitstun across the string).
- **Drive Gauge resource.** Add a separate, regenerating SF6-style Drive Gauge (distinct from the existing Super meter): bars that deplete on Drive actions and regenerate over time, exposed to the HUD.
- **Raw Drive Rush (RDR) and Drive Rush Cancel (DRC), both off `→→`.** From neutral, `→→` performs a **Raw Drive Rush** — a forward-advancing rush that spends Drive (falling back to an ordinary dash only when Drive is unavailable). When `→→` is input off a connected, cancellable normal (i.e. after hitting/blocking the enemy), it instead performs a **Drive Rush Cancel** that leaves Blaze plus, enabling combo extensions and tightened pressure. Both enter the same forward Drive Rush that can be cancelled into a normal with frame advantage.
- **Animation wiring for new motions.** Map the Drive Rush to an appropriate Kubold run/skip clip via `MoveData.anim_clip` / rig state so the model reads correctly; falls back gracefully (procedural rig / default clip) when the model is absent.
- **Blaze move animation polish.** Refresh standing-normal clips (`st.MP` → `KB_m_Uppercut_L`, `st.HP` → `KB_m_Overhand_R`, `st.LK` → `KB_p_LowKick_R_1`, `st.MK` → `KB_m_MidKick_R`, `st.HK` → `KB_m_HighKickRound_R_1`) and signature specials (fireball → `KB_Projectile_4`, rising uppercut → `KB_crouch_m_Uppercut_R_2`), and make the uppercut visibly leap: Blaze rises in a scripted vertical arc during the move (new `MoveData.rises` / `rise_height`), landing by move end, with his hit/hurtboxes following him up. (Visual leap within the existing move frames; not a fully airborne DP.)
- **Tests.** Add headless assertions covering buffered cancels, a true-combo string, Drive Gauge spend/regen, and Drive Rush Cancel.

Non-goals (this change): Drive Impact, Drive Parry, Overdrive (EX) specials, Burnout, throws, and damage scaling — the Drive Gauge is designed so these can be added later without rework.

## Capabilities

### New Capabilities
- `input-buffer`: Buffered, leniency-aware input consumption for attacks, cancels, and actionable transitions, so combos and specials register without frame-perfect timing.
- `combo-cancels`: The cancel / target-combo lattice — which moves cancel into which, when the window opens, and the frame-data guarantees that confirmed strings are true combos.
- `drive-gauge`: A separate regenerating Drive resource (bars, regeneration, spend API, HUD signal) decoupled from the Super meter.
- `drive-rush`: Raw Drive Rush (RDR) from neutral and Drive Rush Cancel (DRC) off a connected cancellable normal, both triggered by `→→`, that spend Drive, advance, and grant frame advantage for combo extension.
- `blaze-move-animation`: Blaze's move presentation — refreshed standing-normal clips, updated fireball/uppercut clips, and a scripted rising-uppercut arc where the attacker leaps and lands within the move.

### Modified Capabilities
<!-- None: openspec/specs/ is currently empty; all behavior here is newly specified. -->

## Impact

- **Simulation:** `scripts/fighter/Fighter.gd` (cancel logic, buffered selection, new Drive Rush state, Drive Gauge fields/regen, scripted rising-attack arc in `_step_attack`), `scripts/core/InputBuffer.gd` (buffer query helpers), `scripts/combat/MoveData.gd` (drive-rush-cancellable flag, optional cancel-tier metadata, `rises`/`rise_height` fields).
- **Data / tuning:** `scripts/data/CharacterLibrary.gd` (Blaze's Ken-style lattice, frame-data nudges, Drive Rush move/clip, fireball clip → `KB_Projectile_4`, uppercut clip → `KB_crouch_m_Uppercut_R_2` + `rises`), `scripts/core/Constants.gd` (new state and/or enums if required).
- **Presentation:** `scripts/fighter/AnimatedFighterRig.gd` (`STATE_CLIP` / clip for Drive Rush), HUD (`scripts/ui/`) (Drive Gauge bar).
- **Tests:** `tools/run_tests.gd` (new buffered-cancel, true-combo, Drive Gauge, and Drive Rush assertions).
- **Determinism:** all new timing stays on the fixed 60 Hz tick; no `_process` gameplay. The CPU controller is unaffected (it remains "just another controller").

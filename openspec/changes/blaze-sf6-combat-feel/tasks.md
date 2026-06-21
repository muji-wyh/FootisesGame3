## 1. Input buffer + cancel fix (keystone)

- [x] 1.1 Add a `CANCEL_BUFFER` tick constant to `Fighter` and change `_select_cancel` to accept a follow-up whose button is found via `input_buffer.pressed_within(button, CANCEL_BUFFER)` instead of requiring `inp.pressed` on the exact tick.
- [x] 1.2 In `_step_attack`, open the cancel gate at first contact: trigger the cancel check once `move_hits_done > 0` (drop the `is_recovering(state_frame)`-only restriction) through end of recovery, including active/post-hitstop frames.
- [x] 1.3 Keep motion-based (special/super) cancels validating through `MotionParser` over the buffer; ensure normals still prefer stance-correct variants via the existing `_select_move` fallback.
- [x] 1.4 Add `_test_combo` in `tools/run_tests.gd`: a buffered `st.LP → st.MP → st.HP` produces three sequential connects, and assert the victim is in `HITSTUN` at each subsequent hit (true-combo guarantee). Include a case where the follow-up is **pre-pressed before/through the impact hitstop** to prove the buffer is not consumed by the freeze. Run the headless suite and confirm new + existing assertions pass.

## 2. Ken-style cancel lattice + frame-data tuning

- [x] 2.1 Review/adjust Blaze's `cancel_into` routes in `CharacterLibrary._add_standard_normals` and `_blaze` for a Ken-flavored gatling (lights→mediums→heavies, self-chaining lights, `cr.MK` and mediums → specials/super).
- [x] 2.2 Nudge light/medium `hitstun`/`recovery` (data only) so the designated bread-and-butter routes are true combos; verify against the `_test_combo` hitstun assertions and add one low-confirm route (e.g., `cr.LK/cr.LP → cr.MK xx fireball`).
- [x] 2.3 Confirm cancels fire on block as well as hit (block-strings) and that a fully whiffed normal does not special-cancel; add assertions covering both.

## 3. Drive Gauge (separate resource)

- [x] 3.1 Add `max_drive` (≈6 bars, fine internal units) and a per-tick regen rate to `CharacterData`; default-initialize Blaze.
- [x] 3.2 Add `drive`/`max_drive` runtime fields and a `drive_changed(current, maximum)` signal to `Fighter`; regenerate in `advance()` when below max, clamped to `[0, max]`; reset to full in `reset_for_round()` (also clear `drive_rush_pending` and any rise bookkeeping there).
- [x] 3.3 Add a deterministic spend API (`spend_drive(cost) -> bool`) that deducts only when affordable; keep it fully independent of the Super `meter`.
- [x] 3.4 Add `_test_drive_gauge`: full at round start, spend fails when insufficient / succeeds when affordable, regenerates over ticks, and spending Drive leaves the Super meter unchanged.

## 4. Drive Rush Cancel off →→

- [x] 4.1 Add `State.DRIVE_RUSH` to `Fighter`'s `State` enum; implement a `_step_drive_rush` that advances forward at a tuned speed for a tuned duration and is cancellable into a grounded normal. Wire the state into the `advance()` dispatch and keep it OUT of `_is_locked_out`/`_can_block`/`_is_actionable`; treat it as locked in `update_facing`.
- [x] 4.2 Drive Rush Cancel (DRC): in `_step_attack`, detect `_dash_req > 0` within the open cancel window on a connected cancellable normal → spend the DRC cost (gate on affordability) and enter `DRIVE_RUSH`.
- [x] 4.3 Raw Drive Rush (RDR): in `_step_neutral`, convert a neutral `_dash_req > 0` into RDR by default when affordable (lower cost); fall back to the existing ordinary forward dash only when Drive is unavailable (no Drive spent).
- [x] 4.4 Add a one-time `drive_rush_pending` advantage: the first normal performed out of a Drive Rush applies bonus hitstun on contact (consumed after one hit) so links become true combos.
- [x] 4.5 Add `_test_drive_rush`: DRC from a connected normal spends Drive and extends a combo (victim still in `HITSTUN` when the post-rush normal connects); DRC also triggers off a **blocked** normal (pressure); RDR from neutral spends the lower cost and enters `DRIVE_RUSH`; raw `→→` with no Drive falls back to `DASH_F` and spends nothing.

## 5. Animation wiring (model-backed rig)

- [x] 5.1 Add a Drive Rush entry to `AnimatedFighterRig.STATE_CLIP` (forward run/skip clip, e.g. `KB_Run`/`KB_SkipFwd_1`) and a `DRIVE_RUSH` branch in `_state_clip`, using `_first_existing` for graceful fallback.
- [x] 5.2 Verify (via the animated-rig test path) that Drive Rush poses without error when the model is present and that the simulation still runs when it is absent.

## 6. Blaze move-animation polish

- [x] 6.1 Update Blaze's clip data in `CharacterLibrary.gd`: standing normals (`st.MP` → `KB_m_Uppercut_L`, `st.HP` → `KB_m_Overhand_R`, `st.LK` → `KB_p_LowKick_R_1`, `st.MK` → `KB_m_MidKick_R`, `st.HK` → `KB_m_HighKickRound_R_1`), fireball → `KB_Projectile_4`, uppercut → `KB_crouch_m_Uppercut_R_2`. Use exact (case-sensitive) clip names.
- [x] 6.2 Add `rises: bool` and `rise_height: float` to `MoveData` (safe defaults) and set them on Blaze's uppercut.
- [x] 6.3 In `Fighter._step_attack`, drive `position.y` along a tick-based arc for a `rises` move (peak partway, back to 0 by move end) while keeping `on_ground = true`; confirm `_apply_physics` raises no spurious landing and the (position-relative) hit/hurtboxes follow the leap.
- [x] 6.4 Verify on the animated rig that the new clips play and the uppercut visibly leaps and lands, with graceful fallback when a clip/model is absent.
- [x] 6.5 Add a headless `_test_uppercut_rise`: assert the attacker's `position.y` rises above 0 partway through the move and returns to 0 by move end (no spurious `_on_landed` / lingering airborne state), and that the uppercut still connects on a **grounded** dummy (guards against the elevated-hitbox whiff).

## 7. HUD

- [x] 7.1 Render a Drive Gauge bar in the HUD (`scripts/ui/`) distinct from the Super meter, wired to the new `drive_changed` signal; show bar segments.

## 8. Verification & polish

- [x] 8.1 Run the full headless suite (`tools/run_tests.gd`) and confirm all assertions pass (existing + new combo/drive/drive-rush tests).
- [ ] 8.2 Manual playtest in the editor: confirm Blaze's bread-and-butter combos connect with buffered input, DRC off `→→` extends combos and drains Drive, the Drive Gauge regenerates, and the uppercut leaps with the updated clips; tune costs/regen and frame data to taste.
- [x] 8.3 Run `openspec validate blaze-sf6-combat-feel --strict` and resolve any issues.

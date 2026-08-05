# Blaze Complex Combo Relay Design

## Goal

Give Blaze genuinely longer, execution-heavy conversions without adding a new combo system.
The longest route should combine an existing normal chain, Drive Rush Cancel, two new
animation-backed multi-hit specials, and Inferno Rush.

## Scope

- Add two specials from the FightingAnimsetPro gallery:
  - `Ember Barrage` (`236 + LP`) uses `KB_p_OneTwoThree`.
  - `Cinder Rise` (`623 + MP`) uses `KB_m_Backelbow_Uppercut_R`.
- Reuse `MoveData.cancel_into`, the existing motion parser, multi-hit handling, DRC, and super.
- Add the verified routes to training shortcut `4`.
- Do not add a combo manager, rekka state, chain-only move type, or custom per-hit timeline.
- Defer `KB_m_MidKick_LL_2_combo`; its uneven strike intervals do not fit the current uniform
  `hit_gap` model cleanly.

## Move Roles

### Ember Barrage

`Ember Barrage` is a short-range three-punch bridge. Its three hits follow the measured
`KB_p_OneTwoThree` hand peaks at roughly `0.08s`, `0.28s`, and `0.52s`, which fit the existing
uniform multi-hit cadence closely enough without engine changes.

`st.LP`, `st.LK`, `cr.LP`, and `st.HP` may cancel into it. The existing
`cr.MP > st.MP > st.HP` punish chain therefore finishes into the relay without giving
`cr.LK`, `cr.MK`, or `st.MK` another reward path. Damage per hit stays low; its reward comes
from confirming into the next stage. It is committal and punishable when used raw or
completed on block.

### Cinder Rise

`Cinder Rise` is a two-hit back-elbow-to-uppercut launcher using the measured right-hand peaks
around `0.28s` and `0.57s`. It has long recovery and uses a compact shared hitbox measured from
both impact poses. The elbow starts the launch and the uppercut juggles before the super cancel.
Its `623 + MP` input adds execution without adding a new move-selection rule.

`Ember Barrage` cancels into `Cinder Rise`; `Cinder Rise` cancels into Inferno Rush.

## Cancel Graph and Routes

The new branch is:

```text
close check or punish chain
    -> Ember Barrage
        -> Cinder Rise
            -> Inferno Rush
```

Full-hit routes require delaying the next button until the current multi-hit animation reaches
its final strike. Early input may cancel after an earlier hit and intentionally produces a
shorter conversion; no new last-hit-only cancel rule is added.

Training lists these routes after deterministic verification:

- `Quick Relay`: `st.LP > 236 + LP > 623 + MP` — 6 hits, meterless.
- `Heavy Relay`: `cr.MP > st.MP > st.HP > 236 + LP > 623 + MP` — 8 hits, meterless.
- `Inferno Relay`: `cr.MP > st.MP > st.HP > 236 + LP > 623 + MP > 236236 + HP` — 13 hits.
- `Max Heat`: `st.MP > DRC > cr.MP > st.MP > st.HP > 236 + LP > 623 + MP > 236236 + HP`
  — 14 hits and three Drive bars.

## Footsies Constraints

- `st.MK` remains the cancel-free mid-range ruler.
- `cr.MK` gains no new cancel target.
- The long meterless route starts from close buttons or the existing committed heavy chain,
  not from Blaze's default poke.
- Raw Barrage has short reach. Raw Rise has long recovery and no invulnerability.
- The relay is all mid strikes and ends punishable on block; it adds conversion depth, not a
  low/overhead pressure tree.
- DRC remains the only way to prepend the extra normal sequence, so the longest route cashes
  out a confirmed contact rather than bypassing neutral.

## Presentation and Hit Rhythm

Each special keeps normal first-hit hit-stop and shorter follow-up stops, preserving the
existing rhythmic multi-hit behavior. Add measured first-impact fractions to Blaze's
`RigConfig.clip_impacts`; tune startup and `hit_gap` so the simulation contacts follow the
visible punch, elbow, and uppercut beats.

The implementation measures both candidate clips' striking bones before finalizing hitboxes.
Use the smallest fixed box that covers their authored impact poses; do not add per-hit hitbox
data unless measurement proves a shared box cannot stay accurate.

## Validation

Headless checks cover:

- move inputs, clips, hit counts, cadence, cancel targets, and recovery bounds;
- all hits of Barrage and Rise connecting at close range;
- early versus delayed cancel behavior;
- the 8-hit meterless relay;
- the 13-hit super relay and 14-hit DRC route;
- launcher-to-super continuity, exact meter/Drive spend, and damage below a full-health KO;
- unchanged `st.MK`, `cr.MK`, heavy-button, and system-amplifies-neutral contracts;
- shortcut `4` containing all new authored routes.

After the headless suite, export Web and validate `/testblaze` for visible impact alignment,
smooth hit-stop rhythm, stable spacing, and no fighter crossover during the relay.

# Footsies-first design contract

This is the shared design direction for the game. It exists so that tuning, UX, systems,
and training work all reinforce the same target instead of drifting toward "every medium is
a good poke" or toward system-led offense that overrides the ground game.

Treat this document as the reference contributors point at when proposing balance, system,
or training changes. Source of truth for the formal requirements is
`openspec/changes/refine-footsies-neutral-identity/specs/footsies-neutral/spec.md`.

## 1. Grounded neutral comes first

The game should primarily reward:

- walking into your own button range,
- walking out of the opponent's button range,
- whiff punishing overextended buttons,
- using low / stand / heavy variations to test defensive habits.

The game should **not** primarily reward:

- bypassing mid-range with universal system movement,
- autopilot pressure strings with low positional commitment,
- all-purpose medium buttons that solve every interaction.

## 2. Buttons have explicit jobs (Blaze)

Grounded normals separate into four buckets. Every grounded normal should be describable by
*why you press it*, not only by its damage number.

| Bucket | Buttons | Role |
|---|---|---|
| Close checks | `st.LP`, `st.LK`, `cr.LK` | interrupt, check movement, low-risk stop signs |
| Mid-range control | `st.MK` | primary neutral poke / spacing ruler |
| Mid-range variation | `st.MP`, `cr.MK` | forward-pressure variation and low-threat variation |
| Read / punish | `st.HP`, `st.HK`, `cr.HK` | higher-commitment callouts and stronger whiff punishes |

### Blaze's mid-range spine

The spine below orders buttons by **engagement role** (check → measure → commit), not by raw
hitbox reach. `st.MK` is intentionally the longest *medium* poke; the heavy punches reach
less far than the kicks but sit deeper on the commitment axis.

```text
check / measure                                        commit / read

st.MP ------- st.MK ------- cr.MK ------- st.HP ------- st.HK
  │             │             │             │             │
 pressure     default       low threat    read punch    read kick
 variation    ruler         variation     punish        longest callout
```

### Intent of each key button

- `st.MK` — the default neutral button. Stable, reliable, repeatedly usable. It is the
  longest-reaching medium and other grounded buttons are tuned *around* it.
- `st.MP` — a step-in variation. Closer than `st.MK` (shorter reach, walks forward via
  `advance`); it asserts space and feeds the combo/pressure routes rather than measuring range.
- `cr.MK` — the low variation. It must matter (it threatens crouch-blockers and cancels into
  specials) but it must **not** out-range `st.MK`, or it becomes the universal best poke.
- `st.HP` — a straighter heavy read with meaningful commitment (slow recovery, big reward).
- `st.HK` — the farthest heavy callout, strongest whiff-punish identity, most committal.

### Current button-role checkpoints (Blaze)

These relationships are locked in by `_test_blaze_button_roles()` in `tools/run_tests.gd`.
If a tuning pass changes any of them, update both the data and that test deliberately.

- `st.MK` out-reaches every other *medium* grounded normal (`st.MP`, `cr.MK`).
- `st.MP` reaches less far than `st.MK` and walks forward (`advance > 0`) — a closer variation.
- `cr.MK` is a low (`Guard.LOW`) and reaches less far than `st.MK` — a variation, not a ruler.
- `st.HP` / `st.HK` / `cr.HK` deal more damage **and** have longer recovery than the medium
  pokes — higher reward bought with more commitment / whiff-punish risk.

## 3. Systems amplify reads; they do not replace reads

Green Rush / Drive Rush Cancel (DRC) stay in the game, but their job is to **cash out after a
spacing win** — to amplify a successful poke or contact, not to be the default way to open
neutral.

Guardrails currently in the data/engine (`scripts/fighter/Fighter.gd`):

- **Raw Green Rush** (two punches from neutral) costs `RAW_DRIVE_RUSH_COST` (1 Drive bar),
  has a visible startup wind-up (`DRIVE_RUSH_STARTUP_TICKS`) and accelerates instead of
  snapping to full speed, so it can be checked or whiff-punished — it is not a free teleport.
- **DRC** (two punches during a *connected* normal or special) costs `DRC_COST` (3 bars) — three times the
  raw cost — so the cheap, repeatable rush only exists *after* you have already won a contact.
- Drive empties into **Burnout**, which removes access to the rush entirely until it refills.

The intent: the cheapest, most rewarding rush (DRC) is gated behind landing/connecting an
attack first, so spending resources feels strongest after a spacing win, contact, or read.
These guardrails are validated by `_test_system_amplifies_neutral()` in `tools/run_tests.gd`.

## 4. Training-mode follow-up

### Minimum footsies affordances

Training mode should evolve toward repeatable spacing and whiff-punish practice, not only the
current freeform sandbox. The minimum affordances footsies practice needs are:

1. **Fixed-distance poke testing** — place both fighters at a chosen, repeatable spacing so a
   player can learn exactly which button reaches at that range.
2. **Whiff-punish rehearsal** — a dummy that throws a scripted, recovering normal on a timer so
   the player can practice stepping in and punishing the recovery.
3. **Defensive-habit drills** — a dummy that can be set to stand-block, crouch-block, or
   alternate, so the player can test stand/low/overhead mix and confirm hit vs. block.

### Proposed next change: `add-training-spacing-drills`

A concrete, ready-to-promote follow-up (use the `openspec-propose` skill to turn this into a
full change):

- **Why** — the current training scene (`scripts/match/TrainingScene.gd`) is an idle dummy with
  refilled resources; it cannot yet rehearse the spacing and whiff-punish loops this contract
  cares about.
- **What changes**
  - Add a dummy **action script** so the dummy can: stand idle, hold a guard (stand/crouch/
    alternate), or throw a chosen recovering normal on a fixed interval.
  - Add **distance presets** (e.g. `st.MK` tip range, `st.HK` tip range, point-blank) that
    snap both fighters to a fixed separation on reset.
  - Add a lightweight **range/whiff readout** to the training overlay (hit vs. whiff vs. block
    of the player's last poke) so spacing feedback is explicit.
- **Capability** — modifies `training-mode` (the dummy is no longer only idle; the scene gains
  repeatable spacing markers and a punish-rehearsal loop).
- **Non-goals** — input recording/playback and frame-data overlays are out of scope; this
  change is only the spacing + whiff-punish loop.

## 5. Targeted playtest checklist

Some of the design intent is locked in by headless tests (`tools/run_tests.gd`:
`_test_blaze_button_roles`, `_test_footsies_scenarios`, `_test_system_amplifies_neutral`),
but the *feel* of footsies still needs a human pass in the editor / Chrome build after any
tuning change that touches button identity or the Drive systems. Run these passes:

1. **`st.MK`-led neutral** — at mid-range, `st.MK` should be the button you reach for to
   contest space; it should win or trade against pokes thrown at its tip and recover fast
   enough to keep throwing it. Red flag: another medium feels like a strictly better default.
2. **`cr.MK` low-threat balance** — `cr.MK` should feel worth pressing as a low mix-up and
   combo starter, but it should *not* replace `st.MK` at range. Red flag: you stop using
   `st.MK` because `cr.MK` does everything.
3. **Heavy-button whiff punishability** — whiffing `st.HP` / `st.HK` / `cr.HK` from the wrong
   range should be punishable on reaction; they should read as deliberate commits. Red flag:
   you can fish with heavies at no risk.

Automated proxies for 1–3 live in `_test_footsies_scenarios`; the checklist above is the
subjective pass those tests cannot cover.

## Glossary (use these terms in proposals)

Future feature proposals and design discussion should use this shared vocabulary so tuning
intent reads consistently:

- **Footsies** — the grounded mid-range game of advancing/retreating to make the opponent
  whiff a button you can then punish, while landing your own pokes at their tip.
- **Neutral** — the state where neither player has an advantage (not in hitstun/blockstun/
  knockdown/pressure); the spacing battle before offense begins.
- **Poke** — a grounded normal used at range to control space and contest movement, valued for
  reach and recovery rather than combo damage. `st.MK` is Blaze's default poke.
- **Whiff punish** — striking the opponent during the recovery of a move they threw out of
  range (a "whiff"). The reward for winning a spacing read.
- **Variation** — a secondary button that *alters* the mid-range threat (closer, lower, or
  more committal) without replacing the default poke's job. `st.MP` and `cr.MK` are variations
  of `st.MK`.
- **Ruler** — the default measuring-stick poke other buttons are tuned around (`st.MK`).
- **Commit / read button** — a slower, higher-reward, higher-recovery normal thrown as a
  deliberate read or whiff punish (`st.HP`, `st.HK`, `cr.HK`).

## Tuning heuristics (apply to every balance change)

Evaluate any change against these questions. A "yes" to any of them likely moves the game
away from the intended footsies identity:

1. Does this make `st.MK` less clearly the default mid-range button?
2. Does this make `cr.MK` too universal?
3. Does this make `st.HP` / `st.HK` too safe to throw out?
4. Does this blur the distinction between `st.MP` and `st.MK`?
5. Does this make Green Rush / DRC the easiest first answer in neutral?

# 214+LK Upper-KO Design

## Goal

Make Blaze's `Ember Lift` (`214+LK`) read as one violent kick that sends the victim flying:

- exactly one hit,
- victim reaction `KB_UpperKO_Flip`,
- much stronger impact pause and launch,
- existing startup, recovery, range, and Super cancel route remain intact.

Ultron inherits the same behavior because it reuses `Blaze.build()`.

## Design

Use the existing `MoveData` fields only. Change `ember_lift` to:

| Field | Value | Reason |
|---|---:|---|
| `hits` | `1` | One impact and one combo-counter hit |
| `damage` | `48` | Preserve the old two-hit move's total damage |
| `meter_gain` | `16` | Preserve the old two-hit move's total meter gain |
| `hitstop` | `14` | Give the single impact a heavy pause |
| `knockback` | `11.0` | Produce the violent horizontal kick-away |
| `launch_velocity` | `7.5` | Keep the flip readable instead of sending it off-screen |
| `hit_reaction_clip` | `KB_UpperKO_Flip` | Play the requested victim animation while airborne |

Remove the now-unused `hit_gap`. Do not add a move-specific animation system or alter the
global upper-knockdown list: `AnimatedFighterRig` already resolves authored hit reactions
during airborne `HITSTUN`, and global changes would affect unrelated launchers.

`KB_UpperKO_Flip` starts on impact and runs until landing transitions the fighter into the
existing knockdown/get-up flow.

## Verification

Update the existing Ember Lift checks to require:

- `hits == 1`,
- the requested reaction clip,
- the stronger hitstop, knockback, and launch thresholds,
- one direct `214+LK` connection produces exactly one hit,
- the victim records `KB_UpperKO_Flip`,
- the existing `cr.LP > 214+LK > Super` route still connects.

Run the full headless suite, then Web-export and visually confirm the kick reads as a violent
launch. If the authored flip is visibly cut off before landing, add flight-time animation
fitting later; do not add that engine behavior pre-emptively.

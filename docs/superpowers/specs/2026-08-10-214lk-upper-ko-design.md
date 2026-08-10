# 214+LK Upper-KO Design

## Goal

Make Blaze's `Ember Lift` (`214+LK`) read as one violent kick that sends the victim flying:

- exactly one hit,
- victim reaction `KB_UpperKO_Flip`,
- much stronger impact pause and launch,
- the hitbox ends with the upward kick instead of lingering through the leg retraction,
- existing startup, total 34-frame commitment, and Super cancel route remain intact.

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
| `startup` | `6` | Preserve the existing startup and animation-impact alignment |
| `active` | `1` | Keep the box only on the authored upward-kick impact frame |
| `recovery` | `27` | Absorb the removed nine active frames so the move still totals 34 frames |
| `hit_offset` | `(0.44, 1.45, 0.0)` | Keep the corrected vertical kick column |
| `hit_size` | `(0.56, 1.14, 0.66)` | Include the impact pose at `x=0.16`, `y=2.02` without restoring the old low box |

Remove the now-unused `hit_gap`. Do not add a move-specific animation system or alter the
global upper-knockdown list: `AnimatedFighterRig` already resolves authored hit reactions
during airborne `HITSTUN`, and global changes would affect unrelated launchers.

`AnimatedFighterRig.attack_timing()` aligns the clip's measured strike to the first active
simulation frame. The old 10-frame active window therefore kept the static box enabled for
nine frames after the kick reached its apex. A one-frame active window removes that trailing
box; moving those frames into recovery preserves the move's overall commitment and lets the
animation continue through its return to guard.

The simulation intentionally uses `knockback` for both hit movement and half-strength guard
pushback. Guarded Ember Lift therefore creates a larger spacing reset as part of this tuning;
its blockstun and total move duration remain unchanged.

`KB_UpperKO_Flip` starts on impact and runs until landing transitions the fighter into the
existing knockdown/get-up flow.

## Verification

Update the existing Ember Lift checks to require:

- `hits == 1`,
- the requested reaction clip,
- `startup == 6`, `active == 1`, `recovery == 27`, and `total_frames() == 34`,
- a whiffed Ember Lift exposes its hitbox for exactly one simulation tick,
- exact preserved movement speed plus the measured hitbox, knockback, and launch values,
- one direct `214+LK` connection produces exactly one hit,
- the victim records `KB_UpperKO_Flip`,
- a guarded `214+LK` produces the intentional spacing reset without damage or launch,
- the existing `cr.LP > 214+LK > Super` route still connects.

Run the full headless suite, then Web-export and visually confirm the kick reads as a violent
launch. If the authored flip is visibly cut off before landing, add flight-time animation
fitting later; do not add that engine behavior pre-emptively.

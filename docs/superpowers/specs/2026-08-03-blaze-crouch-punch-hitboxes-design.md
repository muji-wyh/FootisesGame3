# Blaze Crouch Punch Hitboxes

## Goal

Tighten Blaze's crouch MP and crouch HP hitboxes around their animated punches without changing frame data, damage, cancels, or grounded combo roles.

## Design

- `cr_mp`: set `hit_offset` to `Vector3(0.67, 1.08, 0.0)` and `hit_size` to `Vector3(0.42, 0.32, 0.60)`.
  - The resulting box spans `x=0.46..0.88`, `y=0.92..1.24`, covering the measured jab hand at `x=0.81..0.82`, `y=1.11..1.13`.
- `cr_hp`: set `hit_offset` to `Vector3(0.34, 1.48, 0.0)` and `hit_size` to `Vector3(0.44, 0.90, 0.64)`.
  - The resulting box is a close vertical uppercut spanning `x=0.12..0.56`, `y=1.03..1.93`, covering the measured fist at `y=1.77..1.88`.
  - Its lower edge remains below the crouching hurtbox top (`1.15`), preserving close-range grounded contact instead of turning the move into a high-only anti-air.
- Keep the change in `characters\blaze\blaze.gd`; shared normal defaults remain unchanged.

## Validation

- Add focused assertions to `_test_blaze_mp_hp_range()` for compact dimensions, intended reach, animation-height coverage, and crouching-hurtbox overlap.
- Run `tools\probe_hitheight.gd` and confirm both moves remain vertically aligned with their striking limbs.
- Run the full headless combat suite.
- Use the training hitbox viewer to confirm both boxes visually follow their active punch poses.

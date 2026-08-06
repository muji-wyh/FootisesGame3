# VFX Impact and Hit Gallery Deep Link Design

## Goal

Open `GALLERY-VFXImpactAndHit.tscn` directly from `/testvfximpactandhit`.

## Design

Reuse `Main.apply_boot_link()`, matching the existing FightingAnimsetPro deep link:

- Recognize the `testvfximpactandhit` marker before the training fallback.
- Return `res://scenes/ui/GALLERY-VFXImpactAndHit.tscn`.
- Leave match mode and character selection untouched.
- Support path, hash, and query spellings through the existing `url.contains()` behavior.

No route table or new router is needed for one additional gallery link.

## Verification

Extend `_test_boot_deep_link()` to cover all three URL spellings and confirm each returns the
gallery scene without changing match configuration. Existing VFX gallery tests continue to cover
scene existence and loading.

# Blaze-Compatible Model Skill Improvement

## Goal

Make `creating-blaze-compatible-models` produce portable, machine-checked evidence without pretending that automated checks prove deformation quality.

## Evidence

- The current `1e-6` local-matrix tolerance rejects an unchanged Maskman FBX export/re-import; measured drift reaches `3.17e-4`.
- The same round trip stays within `2e-5` in world-space rest matrices, normalized axes, lengths, and roll.
- Baseline agents independently wrote incomplete validators: one compared inheritance flags instead of bone axes; another did not validate roll; animation and unweighted vertices were inconsistently handled.
- The existing visual-test gate already resisted deadline pressure, so it needs no extra policy.

## Options

1. **Text-only correction:** smallest diff, but agents would keep reinventing fragile validation code.
2. **Bundled validator:** chosen; one reusable Blender script provides deterministic checks and evidence while mesh fitting remains interactive.
3. **Full conversion automation:** rejected; fitting topology and correcting shoulders, hips, fingers, hair, and clothing are input-dependent visual work.

## Design

- Add `scripts\validate_blaze_fbx.py`.
  - Resolve the canonical FBX from the skill's repository location unless `--reference` is supplied.
  - Import reference and candidate with identical Blender FBX settings in a clean scene.
  - Require exactly one candidate armature, its exact object name/parent path, at least one skinned mesh, exact bone count/order/names/parents, and the six required foot/root bones.
  - Compare armature transforms and bone world-space rest data with a configurable default tolerance of `2e-5`.
  - Reject all candidate actions/NLA animation.
  - Require every mesh vertex to have one to four normalized bone influences.
  - Emit JSON and return nonzero on failure.
- Keep conversion instructions concise and direct agents to run the bundled validator after exporting.
- Reserve `exact` for a passing validator plus visual playback of the required Blaze/Kubold clips; otherwise return `unverified`.
- Add one Blender-runnable regression check covering a valid export and deliberate rig, animation, and weight failures.

## Validation

- Run the validator regression script in Blender.
- Validate an unchanged Maskman round trip structurally at the calibrated tolerance.
- Run old-skill versus revised-skill evals and generate the skill review benchmark.
- Run the skill package validator.

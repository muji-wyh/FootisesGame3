# Training Combo List Design

## Goal

Pressing `4` in the training scene toggles a scrollable list of practical, verified combos
for the selected characters.

## Scope

- Show authored combos, not every theoretical `cancel_into` permutation.
- Reuse the existing move-list panel and its two-character layout.
- Keep `TAB` for moves and `4` for combos.
- Opening one list replaces the other; pressing its shortcut again closes it.
- Add no combo playback, filtering, damage calculation, or input recording.

## Data

`CharacterData` gains a `PackedStringArray` of display-ready combo entries. Each character
module owns its entries beside its move and cancel data. Blaze initially lists the practical
routes already covered by deterministic combat tests:

- `st.MP > Cinder Chain`
- `st.HP > Furnace Hooks`
- `cr.LP > Ember Lift > Inferno Rush`

Display-ready strings are intentional: this feature only presents training guidance. A
structured combo model is unnecessary until another system needs to execute or analyze routes.

## UI and Input

`HUD` keeps one reference panel. Its title, hint, and two body labels switch between move-list
and combo-list content. Existing scrolling and sizing behavior remains shared.

`TrainingScene` handles physical key `4`, calls the HUD combo toggle, and updates the training
shortcut hint to include `4 combos`. Other match scenes do not gain the shortcut.

## Empty and Error States

A character without authored combos shows `No authored combos.` in its column. Invalid move
data is not parsed at runtime because combo entries are presentation strings.

## Tests

The headless suite will verify:

- combo data contains Blaze's three verified routes;
- the combo list starts hidden, opens, renders both character columns, and closes;
- switching between move and combo lists reuses one visible panel;
- the training shortcut hint includes `4 combos`.

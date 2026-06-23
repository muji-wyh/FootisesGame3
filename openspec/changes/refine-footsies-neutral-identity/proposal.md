## Why

The project is named "Footises" in the fighting-game sense: grounded neutral, spacing,
whiff punishes, and clear button identities. The current game already has strong combat
feedback, training support, and data-driven moves, but its design intent is not yet
captured as an explicit product direction. As a result, tuning risks drifting toward
"everything is a good poke" or toward system-led offense that overrides footsies.

This change formalizes the intended neutral game so future balance, UX, training, and
systems work can all reinforce the same design target.

## What Changes

- Define a clear "footsies-first" design contract for the game.
- Define Blaze's grounded normal buttons by role, not only by damage/range.
- Establish that `st.MK` is Blaze's primary mid-range poke, with `st.MP` and `cr.MK`
  as variation buttons and `st.HP` / `st.HK` as read/punish buttons.
- Define guardrails for system mechanics such as Green Rush / DRC so they amplify
  neutral wins rather than replace neutral.
- Define training-mode follow-up needs that directly support spacing and whiff-punish tuning.

## Capabilities

### New Capabilities
- `footsies-neutral`: Captures the game's intended neutral, button identity model, and
  design guardrails for tuning and future features.

### Modified Capabilities
- `training-mode`: Training should evolve toward spacing / whiff-punish practice rather
  than only freeform sandbox use.

## Impact

- Affects future tuning of `characters/blaze/blaze.gd`.
- Affects future combat-system decisions in `scripts/fighter/Fighter.gd`,
  `scripts/match/*`, and related balance/test work.
- Provides design direction for future training-mode improvements.

## Why

Players need a low-friction place to practice movement, attacks, cancels, and spacing without round timers, CPU pressure, or match-ending transitions. A training scene makes the existing combat system easier to tune and verify while keeping normal match flow unchanged.

## What Changes

- Add a Training entry point from the main menu.
- Add a character-select path that starts a dedicated training scene after choosing fighters.
- Add a training scene that reuses the existing stage, fighters, camera, HUD, audio, and move-list systems, but runs continuously with an idle practice dummy.
- Keep health, meter, and drive refreshed so practice does not end on KO or resource depletion.

## Capabilities

### New Capabilities
- `training-mode`: Covers menu access, training scene behavior, practice dummy behavior, continuous reset/resource refresh, and training HUD affordances.

### Modified Capabilities

## Impact

- Affects `GameConst`, `Game`, main menu, character select, new match scene/script files, and headless tests.
- No new external dependencies or asset requirements.

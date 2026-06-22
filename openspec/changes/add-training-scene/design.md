## Context

The existing `MatchScene` builds the stage, fighters, camera, HUD, audio, and `RoundManager`. Training should reuse those combat pieces while avoiding `RoundManager`, because rounds, timers, and results transitions are exactly what training mode must remove.

## Goals / Non-Goals

**Goals:**
- Add a dedicated training scene reachable from the existing menu/character-select flow.
- Reuse the existing combat simulation and presentation systems.
- Keep training continuous by refreshing health, meter, drive, and KO states.
- Preserve current Local 2P and Vs CPU behavior.

**Non-Goals:**
- Add a configurable training dummy UI.
- Implement recording/playback, frame data overlays, or saveable training settings.
- Retarget Fighters Pack characters.

## Decisions

- Add `GameConst.Mode.TRAINING` and let `CharacterSelect` route to `Training.tscn` when selected. This preserves the existing fighter-pick flow and avoids a separate training roster UI.
- Implement `TrainingScene` as a separate script that extends `MatchScene` and reuses helper methods such as rig attachment, HUD wiring, hit sparks, audio, and input handling. This keeps normal match logic untouched and avoids trying to bend `RoundManager` into a non-round mode.
- Use the base `InputController` for the dummy. It already returns neutral input, so no new dummy controller is needed.
- Refresh both fighters when either health reaches zero and refill training resources every tick. This keeps the session continuous without changing core `Fighter` behavior.

## Risks / Trade-offs

- Duplicating the `MatchScene` setup sequence in `TrainingScene` can drift if match setup changes. Mitigation: keep `TrainingScene` small and reuse inherited helper methods for shared wiring.
- Automatic KO refresh may interrupt hit-reaction presentation. Mitigation: delay the refresh briefly so KO feedback remains visible before resetting positions.

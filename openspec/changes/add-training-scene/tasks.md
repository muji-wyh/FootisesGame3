## 1. Scene Flow

- [x] 1.1 Add a Training mode constant and main-menu button that enters character select in training mode.
- [x] 1.2 Route character select confirmation to the training scene when Training mode is active.

## 2. Training Scene

- [x] 2.1 Add a `TrainingScene` script and `Training.tscn` scene that reuse the existing stage, arena, camera, HUD, audio, and fighter rigs.
- [x] 2.2 Run continuous combat against a neutral dummy without `RoundManager`, round timer, round wins, or results transition.
- [x] 2.3 Refresh health, meter, drive, and KO state during training so practice can continue indefinitely.
- [x] 2.4 Add a visible training banner/control hint and preserve TAB move-list and ESC menu behavior.

## 3. Validation

- [x] 3.1 Add headless coverage for training mode routing and continuous reset behavior.
- [x] 3.2 Run Godot import, test suite, and Web export.

## ADDED Requirements

### Requirement: Drive Rush Cancel (DRC) from a connected normal

A connected (hit or block) normal that is special-cancellable (i.e. has a non-empty `cancel_into`) SHALL be cancellable into a forward Drive Rush by inputting a forward dash (`→→`) within the cancel window, provided the fighter can afford the Drive Rush Cancel (DRC) cost. No separate `drive_rush_cancellable` flag is required. This consumes Drive and transitions the fighter into a forward-advancing Drive Rush.

#### Scenario: Normal into Drive Rush on hit
- **WHEN** Blaze lands a cancellable normal and the player double-taps forward within the cancel window with sufficient Drive
- **THEN** the normal cancels into a Drive Rush, the fighter advances forward, and the Drive Rush Cancel cost is deducted from the Drive Gauge

#### Scenario: Insufficient Drive blocks the cancel
- **WHEN** the player attempts a Drive Rush Cancel but the Drive Gauge cannot afford the cost
- **THEN** no Drive Rush occurs and the normal completes its recovery normally

#### Scenario: DRC off a blocked normal (pressure)
- **WHEN** Blaze's special-cancellable normal is blocked and the player double-taps forward within the cancel window with sufficient Drive
- **THEN** the normal cancels into a Drive Rush, advancing for continued pressure, and the DRC cost is deducted

### Requirement: Raw Drive Rush (RDR) from neutral

From an actionable neutral state, a forward dash (`→→`) SHALL perform a Raw Drive Rush by default when the fighter can afford the RDR cost; otherwise it SHALL perform an ordinary forward dash with no Drive cost. RDR thus replaces the neutral movement dash whenever Drive is affordable, and no separate or deliberate input beyond `→→` is required. The RDR cost SHALL be lower than the Drive Rush Cancel (DRC) cost.

#### Scenario: Neutral forward dash becomes Drive Rush
- **WHEN** the player double-taps forward from neutral with sufficient Drive
- **THEN** the fighter performs a Drive Rush (spending the lower raw cost) instead of an ordinary dash

#### Scenario: Falls back to ordinary dash without Drive
- **WHEN** the player double-taps forward from neutral but cannot afford the raw Drive Rush cost
- **THEN** the fighter performs an ordinary forward dash and no Drive is spent

### Requirement: Drive Rush is cancellable into a normal with frame advantage

During a Drive Rush, the fighter SHALL be able to cancel into a grounded normal. The first normal performed out of a Drive Rush SHALL gain frame advantage (modeled as bonus hitstun/advantage on contact) so that links and combo extensions that are otherwise impossible become true combos.

#### Scenario: Drive Rush extends a combo
- **WHEN** Blaze cancels a connected normal into a Drive Rush and then into a follow-up normal
- **THEN** the follow-up connects while the victim is still in hitstun, extending the combo

#### Scenario: Advantage applies only to the first follow-up
- **WHEN** more than one normal is performed after a single Drive Rush
- **THEN** only the first normal out of the Drive Rush receives the Drive Rush frame-advantage bonus

### Requirement: Drive Rush presentation

A Drive Rush SHALL be visually distinct: on the model-backed rig it SHALL play a forward run/skip clip, and on the procedural rig or when the model is absent it SHALL degrade gracefully to a default forward motion without errors.

#### Scenario: Run clip on the animated rig
- **WHEN** a Drive Rush begins and the animated rig is active
- **THEN** the rig plays a forward run/skip clip for the duration of the Drive Rush

#### Scenario: Graceful fallback without model
- **WHEN** a Drive Rush begins and no model-backed rig is present
- **THEN** the fighter still advances and the simulation runs without error

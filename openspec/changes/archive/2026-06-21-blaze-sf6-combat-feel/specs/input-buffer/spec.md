## ADDED Requirements

### Requirement: Buffered cancel input

A move's cancel into a follow-up SHALL be triggered when the follow-up's button was pressed within a bounded buffer window (measured in ticks) ending on the current tick, rather than only on a single frame-fresh press. The buffer window SHALL be small enough to feel deliberate (a few ticks) and is evaluated against the fighter's existing tick-based `InputBuffer`, preserving determinism.

#### Scenario: Pre-pressed follow-up still cancels
- **WHEN** a normal connects and the player pressed the follow-up button a few ticks before the cancel window opened (a buffered input)
- **THEN** the fighter cancels into the follow-up move once the window is open, even though no rising-edge press occurs on that exact tick

#### Scenario: Mashed follow-up cancels
- **WHEN** the player holds or repeatedly taps the follow-up button across the active and recovery frames of a connecting normal
- **THEN** the fighter cancels into the follow-up move (the held/mashed input is honored via the buffer, not ignored)

#### Scenario: Impact hitstop does not consume the buffer
- **WHEN** a follow-up button is pressed before or during the impact hitstop freeze of a connecting normal
- **THEN** the buffered press is still honored when the move resumes after hitstop and the cancel fires (the freeze does not age the input out of the window)

#### Scenario: Stale input does not cancel
- **WHEN** the follow-up button was last pressed longer ago than the buffer window
- **THEN** no cancel occurs and the move completes its recovery normally

### Requirement: Cancel window opens at first contact

Once an attack has connected (on hit or on block), it SHALL be cancellable into an eligible follow-up from the moment of contact through the end of its recovery, including during the active frames and after the impact hitstop, not only during the recovery frames.

#### Scenario: Cancel during active frames after a hit
- **WHEN** a normal's hitbox connects on its first active frame and an eligible buffered follow-up is present
- **THEN** the fighter may cancel into the follow-up without waiting for the recovery frames to begin

#### Scenario: No cancel before contact
- **WHEN** a normal has not yet connected (it is in start-up or whiffing)
- **THEN** the move is not cancellable and behaves as a normal attack

### Requirement: Deterministic, controller-agnostic buffering

Input buffering SHALL be driven entirely by the fixed 60 Hz tick via the existing `InputBuffer`, with no wall-clock timing, and SHALL apply identically to human and CPU controllers since both emit one `InputFrame` per tick.

#### Scenario: CPU benefits from the same buffer
- **WHEN** the CPU controller queues a follow-up press within the buffer window of a connecting normal
- **THEN** the CPU cancels into the follow-up using the same code path as a human player

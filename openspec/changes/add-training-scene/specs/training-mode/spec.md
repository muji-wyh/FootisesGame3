## ADDED Requirements

### Requirement: Training mode entry
The system SHALL expose a Training option from the main menu and SHALL route the player through character select before loading the training scene.

#### Scenario: Starting training from menu
- **WHEN** the player selects Training from the main menu and confirms the character selection
- **THEN** the system loads the training scene instead of the normal match scene

### Requirement: Continuous practice session
The training scene SHALL run combat simulation continuously without round intros, round timer expiration, round wins, match-over transitions, or automatic return to results.

#### Scenario: Practicing after damage
- **WHEN** the player damages or KOs the dummy in training
- **THEN** both fighters remain in the training scene and can continue practicing after the scene refreshes the dummy state

### Requirement: Idle practice dummy
The training opponent SHALL remain neutral and use the selected second character as the dummy unless later configured otherwise.

#### Scenario: Dummy remains passive
- **WHEN** the training scene is running without player-two input
- **THEN** the dummy does not walk, attack, or make CPU decisions

### Requirement: Training HUD affordances
The training scene SHALL show existing combat HUD information and a visible Training banner with basic controls for move list and returning to menu.

#### Scenario: Training guidance visible
- **WHEN** the training scene starts
- **THEN** the player sees that the session is Training mode and can discover TAB for move list and ESC for menu

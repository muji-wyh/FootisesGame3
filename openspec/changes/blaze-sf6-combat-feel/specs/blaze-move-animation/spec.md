## ADDED Requirements

### Requirement: Updated standing-normal clips

Blaze's standing normals SHALL play their designated Kubold clips: `st.MP` → `KB_m_Uppercut_L`, `st.HP` → `KB_m_Overhand_R`, `st.LK` → `KB_p_LowKick_R_1`, `st.MK` → `KB_m_MidKick_R`, and `st.HK` → `KB_m_HighKickRound_R_1`. Clip names are case-sensitive and SHALL match the imported Kubold clip exactly. When a designated clip is unavailable on the rig, the normal SHALL fall back to a default clip without error.

#### Scenario: Standing normals play their updated clips
- **WHEN** Blaze performs `st.MP`, `st.HP`, `st.LK`, `st.MK`, or `st.HK` on the model-backed rig
- **THEN** the rig plays `KB_m_Uppercut_L`, `KB_m_Overhand_R`, `KB_p_LowKick_R_1`, `KB_m_MidKick_R`, or `KB_m_HighKickRound_R_1` respectively

#### Scenario: Graceful fallback for a missing normal clip
- **WHEN** a designated standing-normal clip is not present on the rig
- **THEN** the normal plays a default clip and the simulation runs without error

### Requirement: Updated signature special-move clips

Blaze's signature specials SHALL play their designated Kubold clips: the Flare Bolt fireball SHALL use `KB_Projectile_4`, and the rising uppercut (Blaze Rise) SHALL use `KB_crouch_m_Uppercut_R_2`. When a designated clip is unavailable on the rig, the move SHALL fall back to a default clip without error.

#### Scenario: Fireball plays the updated clip
- **WHEN** Blaze performs the Flare Bolt fireball on the model-backed rig
- **THEN** the rig plays `KB_Projectile_4`

#### Scenario: Uppercut plays the updated clip
- **WHEN** Blaze performs the rising uppercut on the model-backed rig
- **THEN** the rig plays `KB_crouch_m_Uppercut_R_2`

#### Scenario: Graceful fallback for a missing clip
- **WHEN** a designated special clip is not present on the rig
- **THEN** the move plays a default clip and the simulation runs without error

### Requirement: Rising uppercut leaps within the move

The rising uppercut SHALL make the attacker visibly leap: during the move the attacker rises along a scripted vertical arc and returns to the ground by the end of the move (a presentation/positional arc within the move's existing frames, not a fully airborne jump state). The attacker's active hitbox and hurtbox SHALL follow the attacker's elevated position so the move connects on the way up and the attacker's vulnerable boxes rise with him. The arc SHALL be deterministic on the fixed 60 Hz tick and SHALL leave the attacker grounded when the move completes.

#### Scenario: Attacker rises and lands within the move
- **WHEN** Blaze performs the rising uppercut from the ground
- **THEN** the attacker's vertical position increases to a peak partway through the move and returns to ground level by the time the move ends

#### Scenario: Hitbox tracks the rising attacker
- **WHEN** the rising uppercut's active frames occur while the attacker is elevated
- **THEN** the move's hitbox is positioned relative to the attacker's current elevated position (it rises with him)

#### Scenario: Deterministic and grounded on completion
- **WHEN** the rising uppercut finishes
- **THEN** the attacker is back on the ground in a normal actionable/recovery state, with no lingering airborne state, identically across repeated runs of the same inputs

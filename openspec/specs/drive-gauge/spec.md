# drive-gauge Specification

## Purpose

A separate regenerating Drive resource (bars, regeneration, spend API, HUD signal) decoupled from the Super meter.

## Requirements

### Requirement: Drive Gauge is separate from the Super meter

Each fighter SHALL have a Drive Gauge that is independent of the existing Super (Art) meter. Spending or regenerating the Drive Gauge SHALL NOT change the Super meter, and vice versa.

#### Scenario: Spending Drive leaves Super meter unchanged
- **WHEN** a fighter spends Drive on a Drive action
- **THEN** the Drive Gauge decreases and the Super meter is unchanged

#### Scenario: Gaining Super meter leaves Drive unchanged
- **WHEN** a fighter gains Super meter by landing an attack
- **THEN** the Super meter increases and the Drive Gauge is unchanged

### Requirement: Drive Gauge capacity in bars

The Drive Gauge SHALL hold a fixed maximum expressed as whole bars (SF6-style, six bars) backed by finer internal units for smooth regeneration. The gauge SHALL start each round full and SHALL clamp to the range [0, max].

#### Scenario: Full at round start
- **WHEN** a round begins
- **THEN** each fighter's Drive Gauge is at its maximum

#### Scenario: Clamped at bounds
- **WHEN** a spend would take the gauge below zero, or regeneration would take it above the maximum
- **THEN** the gauge is clamped to zero or the maximum respectively

### Requirement: Passive regeneration over time

The Drive Gauge SHALL regenerate at a fixed rate per tick while not at maximum, on the deterministic 60 Hz tick (no wall-clock timing).

#### Scenario: Regenerates after spending
- **WHEN** a fighter has spent Drive and then takes no Drive action for a period
- **THEN** the Drive Gauge increases each tick until it reaches its maximum

### Requirement: Spend API with affordability check

The Drive Gauge SHALL expose a deterministic spend operation that deducts a cost only when the fighter can afford it, returning whether the spend succeeded, so Drive actions can gate on availability.

#### Scenario: Spend fails when insufficient
- **WHEN** a Drive action costing N bars is requested but fewer than N bars are available
- **THEN** the spend fails, the gauge is unchanged, and the Drive action does not occur

#### Scenario: Spend succeeds when affordable
- **WHEN** a Drive action costing N bars is requested and at least N bars are available
- **THEN** the spend succeeds and the gauge decreases by N bars

### Requirement: HUD signal

The Drive Gauge SHALL emit a change notification (current, maximum) when its value changes, so the HUD can render a Drive bar distinct from the Super meter.

#### Scenario: HUD updates on change
- **WHEN** the Drive Gauge value changes from a spend or from regeneration crossing into a new displayed amount
- **THEN** a change signal carrying the current and maximum values is emitted for the UI

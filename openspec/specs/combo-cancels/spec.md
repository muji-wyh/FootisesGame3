# combo-cancels Specification

## Purpose

The cancel / target-combo lattice — which moves cancel into which, when the window opens, and the frame-data guarantees that confirmed strings are true combos.

## Requirements

### Requirement: Gatling chain routes

Each character's normals SHALL define data-driven chain routes (via `MoveData.cancel_into`) following a tiered gatling order, where lighter normals can be cancelled into heavier or equal-system normals on contact. Blaze SHALL provide Ken-flavored routes: lights into mediums, mediums into heavies, and self-chaining lights for hit-confirms.

#### Scenario: Light into medium into heavy
- **WHEN** Blaze lands `st.LP`, then a buffered `st.MP`, then a buffered `st.HP`, each within the cancel window
- **THEN** all three normals connect in sequence as a chained string

#### Scenario: Route not defined
- **WHEN** the player attempts to cancel a normal into a follow-up that is not listed in that normal's `cancel_into`
- **THEN** no cancel occurs and the active move completes normally

### Requirement: Special- and super-cancel from normals

Designated normals SHALL be cancellable into Blaze's specials and (meter permitting) supers on contact. Blaze's `cr.MK` SHALL be a special-cancellable staple that confirms into a special or Drive Rush.

#### Scenario: cr.MK into fireball
- **WHEN** Blaze lands `cr.MK` and the player buffers a quarter-circle-forward + punch within the cancel window
- **THEN** `cr.MK` cancels into the Flare Bolt fireball

#### Scenario: Super-cancel requires meter
- **WHEN** a normal is cancelled into a super but the Super meter is below the super's cost
- **THEN** the super does not come out and the normal completes its recovery

### Requirement: Cancels enabled on hit and on block

A cancel SHALL be permitted once the move has connected on hit OR on block, enabling both combos (on hit) and pressure block-strings (on block). A fully whiffed normal SHALL NOT special-cancel.

#### Scenario: Block-string pressure
- **WHEN** Blaze's normal is blocked and the player buffers an eligible chain follow-up
- **THEN** the follow-up comes out as continued block pressure

#### Scenario: Whiffed normal does not special-cancel
- **WHEN** a normal whiffs (no hit or block contact) and the player inputs a special-cancel
- **THEN** the special does not come out from the cancel path

### Requirement: Confirmed strings are true combos

For Blaze's intended bread-and-butter routes, the frame data SHALL guarantee that a string confirmed on hit is a true combo: the victim remains in hitstun continuously from the first hit until the final hit of the string connects, with no actionable gap.

#### Scenario: Victim cannot escape a confirmed string
- **WHEN** Blaze lands the first normal of a designated true-combo route on hit and immediately cancels into the next move within the cancel window
- **THEN** the victim is in hitstun (not actionable, cannot block or attack) at the moment each subsequent hit of the route connects

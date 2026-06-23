## 1. Design Contract

- [ ] 1.1 Capture the "grounded neutral first" design contract in repository docs or design-facing references used by contributors.
- [ ] 1.2 Audit current combat terminology so future feature proposals use "footsies", "neutral", "poke", "whiff punish", and "variation" consistently.

## 2. Blaze Button Identity

- [ ] 2.1 Review Blaze's grounded normal tuning and explicitly map each button to one of the four roles: close checks, mid-range control, mid-range variation, or read/punish.
- [ ] 2.2 Preserve `st.MK` as the primary mid-range poke while separating `st.MP` and `cr.MK` into distinct variation roles.
- [ ] 2.3 Ensure `st.HP`, `st.HK`, and `cr.HK` remain meaningfully stronger but clearly more committal than the default mid-range buttons.
- [ ] 2.4 Add or update balance tests that express button-role relationships rather than only raw frame/range values.

## 3. System Guardrails

- [ ] 3.1 Review Green Rush / DRC entry conditions, carry, and reward to ensure they amplify neutral wins instead of replacing neutral.
- [ ] 3.2 Add validation scenarios for "system mechanic starts after a spacing win" versus "system mechanic skips neutral too easily".

## 4. Training Follow-up

- [ ] 4.1 Define the minimum training-mode affordances needed for footsies work: fixed-distance poke testing, whiff-punish rehearsal, and defensive-habit drills.
- [ ] 4.2 Propose the next training-mode change focused on spacing and whiff-punish practice.

## 5. Validation

- [ ] 5.1 Re-run the headless combat suite after each tuning pass that changes button identity or system guardrails.
- [ ] 5.2 Perform targeted playtest passes specifically for `st.MK`-led neutral, `cr.MK` low-threat balance, and heavy-button whiff punishability.

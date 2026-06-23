## Context

The current game already has:

- deterministic 60 Hz combat
- strong hitstop and impact FX
- grounded normals tuned in `characters/blaze/blaze.gd`
- training mode for repeated practice
- Green Rush / DRC style system mechanics

What it does not yet have is an explicit, shared design contract describing which
interactions should define the game. Without that contract, tuning can drift in ways
that weaken footsies:

- too many normals overlapping in purpose
- `cr.MK` becoming an all-purpose answer
- heavy buttons being too safe
- system mechanics skipping the neutral game too often

## Goals / Non-Goals

**Goals**
- Make grounded neutral the center of the game's identity.
- Define each grounded normal by role in neutral.
- Make `st.MK` Blaze's default mid-range measuring stick.
- Make systems like Green Rush / DRC subordinate to spacing wins.
- Identify training-mode affordances needed for footsies tuning.

**Non-Goals**
- Rebuild the game into a simulation or sports game.
- Remove all offensive system mechanics.
- Fully rebalance every move immediately in this change.
- Implement training recording/playback in this change.

## Core Design Contract

### 1. Grounded neutral comes first

The game should primarily reward:

- walking into one's own button range
- walking out of the opponent's button range
- whiff punishing overextended buttons
- using low / stand / heavy variations to test defensive habits

The game should not primarily reward:

- bypassing mid-range with universal system movement
- autopilot pressure strings with low positional commitment
- all-purpose medium buttons that solve every interaction

### 2. Buttons have explicit jobs

For Blaze, grounded normals should separate into four buckets:

| Bucket | Buttons | Role |
|---|---|---|
| Close checks | `st.LP`, `st.LK`, `cr.LK` | interrupt, check movement, low-risk stop signs |
| Mid-range control | `st.MK` | primary neutral poke / spacing ruler |
| Mid-range variation | `st.MP`, `cr.MK` | forward-pressure variation and low threat variation |
| Read / punish | `st.HP`, `st.HK`, `cr.HK` | higher-commitment callouts and stronger whiff punishes |

### 3. Systems amplify reads; they do not replace reads

Green Rush / DRC can stay in the game, but their job is:

- to cash out after a spacing win
- to amplify a successful poke or contact

They should not become the default way to begin offense from neutral. If system movement
becomes the dominant entry point, the game stops reading as footsies-first.

## Blaze Neutral Structure

### Blaze's mid-range spine

```text
closer                                                farther

st.MP ------- st.MK ------- cr.MK ------- st.HP ------- st.HK
  │             │             │             │             │
  │             │             │             │             │
 pressure     default       low threat    read punch    read kick
 variation    ruler         variation     punish        longest callout
```

### Intent of each key button

- `st.MK`: The default neutral button. Stable, reliable, and repeatedly usable.
- `st.MP`: A step-in variation. Closer than `st.MK`; more about asserting space than measuring it.
- `cr.MK`: The low variation. Must matter, but must not replace `st.MK`.
- `st.HP`: A straighter heavy read button with meaningful commitment.
- `st.HK`: The farthest heavy callout with strong whiff-punish identity.

## Tuning Heuristics

Future balance work should evaluate changes against these questions:

1. Does this make `st.MK` less clearly the default mid-range button?
2. Does this make `cr.MK` too universal?
3. Does this make `st.HP` / `st.HK` too safe to throw out?
4. Does this blur the distinction between `st.MP` and `st.MK`?
5. Does this make Green Rush / DRC the easiest first answer in neutral?

If the answer to any of these is "yes", the tuning likely moves away from the intended
footsies identity.

## Training Implications

Training mode should eventually support the specific loops footsies players need:

1. fixed-distance poke calibration
2. whiff-punish rehearsal
3. stand-vs-crouch defensive habit testing

That suggests future training-mode features should prioritize:

- repeatable spacing markers / scripts
- deterministic dummy poke playback
- whiff-punish drills
- clearer range/hitbox interpretation tools

## Risks / Trade-offs

- Too much emphasis on footsies could flatten offense if system tools are over-nerfed.
- Too little emphasis leaves the game feeling like generic pressure-first modern 2D combat.
- Making `st.MK` central raises the importance of getting `st.MP` / `cr.MK` separation right;
  if either overlaps too much, the button map becomes muddy again.

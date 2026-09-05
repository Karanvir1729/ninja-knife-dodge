# The Four Trials — story edition

Branch `story-edition` (version 2.1). A separate edition of the app in which the
four games are framed as one story. `main` is untouched by this work.

## The premise

The void came first, and the dojo named it **the Quiet**. It does not kill things,
it unmakes them, and a name is the last part to go. Sensei Kuro is the ninth and
last master of the Star Dojo. He trained a hundred years; then a star fell into
the dojo still burning — the first thing that ever survived — and the daggers came
for it, and he stood between. The daggers are what the Quiet leaves of a star it
has taken. Kuro can still play his own master's drill; he can no longer say her
name. Four trials remain, and his hands are old.

The player earns four seals. Along the way the guides open each trial, the truth
about the daggers lands at the midpoint, and the epilogue hands the dojo over —
Kuro sits down, and Pip says his name out loud so that it stays.

## Structure

| Trial | Game | Glyph | Accent | Seal earned by |
|---|---|---|---|---|
| I — Blade | Knife Dodge | dagger | cyan | dodge 25 daggers in one run |
| II — Eye | Quick Draw | eye | orange | score 20 in one round |
| III — Mind | Shuriken Match | shuriken | magenta | clear level 3 |
| IV — Name | Sensei Says | nine pads | violet | reach round 5 |

Seals are **derived from existing stats**, so past play counts and nothing new is
stored except which seals have been celebrated. Earning all four unlocks the
epilogue, which plays once on the hub and is kept in the journal.

## Pieces

- `story/story.gd` — the single source of truth: trials, lore, seal rules,
  progress, celebration and epilogue dialogue. Add a game by adding a `TRIALS`
  entry and an `ORDER` id.
- `story/cinematic.gd` / `.tscn` — the prologue: seven scripted shots (void,
  training, starfall, the dagger ambush, the passing years, the four pillars,
  title card) with typed narration, a slow camera push-in, and tap-to-advance.
  It plays on first launch, is skippable, and is replayable from the journal or
  "How to play".
- `States/start_state.gd` — the hub: one large trial card per game showing the
  numeral, trial name, illustration, hook, stats and seal progress; the guides
  celebrate a new seal the next time you return.
- `States/story_state.gd` — the journal: chapter cards with lore and seal state,
  a seal wheel, prologue replay and the locked/unlocked epilogue.

## Working on it

```bash
godot --path . -- --film=/tmp/film     # film only the prologue (~50 s) with per-frame state in the log
godot --path . -- --tour=/tmp/tour     # every screen at three aspect ratios + gameplay smoke checks
godot --headless --path . -- --check   # load every script and scene
```

Shipping this edition without disturbing `main`'s build artifacts:

```bash
NINJA_OUT=/Users/karanvirkhanna/game-ninja/ninja-ios-story tools/ship_ios.sh 6
```

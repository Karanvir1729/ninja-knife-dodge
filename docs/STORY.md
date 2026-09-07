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

## The chapter path

Since 2026-09-06 the hub is a path of chapters rather than a menu of games
(`Story.CHAPTERS`, in order): the prologue, Chapter I (the Blade), the Yard
interlude (Star Cricket), Chapter II (the Eye), the turn, Chapter III (the
Mind), Chapter IV (the Name), the epilogue. A chapter is **unlocked when every
trial before it has its seal**; films and the interlude never gate. Locked
chapters sit dimmed with a lock and ask Pip when tapped; a chapter that has just
opened is revealed on the path (scroll, lock breaks, a line from Pip) the next
time the hub is shown. The current chapter carries a NEXT chip and the path is
scrolled to it.

Every chapter opens with a film and every seal closes with one (see
`docs/FILMS.md`): the first launch of a trial plays its opening film and then the
game; a new seal, the turn (at two seals), the ending (at four) and the Yard's
fifty are queued by `Story.pending_films()` and played as one chain from the hub.
A film that has not been built yet is skipped, and the guides' spoken opening
and seal lines remain as the fallback.

## Pieces

- `story/story.gd` — the single source of truth: trials, lore, seal rules,
  progress, the chapter path (`CHAPTERS`, `chapter_unlocked`, `current_chapter`,
  `pending_films`), the spoken fallbacks and the summaries.
- `story/film.gd` / `film.tscn` — the `Film` base every story film extends;
  `story/films/<id>.gd` + `.tscn` are the films (`docs/FILMS.md` has the API).
  The prologue is `story/films/prologue.gd`; the Yard's are `cricket.gd` and
  `cricket_fifty.gd`.
- `States/start_state.gd` — the hub: the scrolling chapter path, the guides,
  film queuing, reveals and the spoken fallbacks.
- `States/story_state.gd` — the journal: chapter cards with lore, seal state
  and film replays, a seal wheel, prologue replay and the locked/unlocked epilogue.

## Working on it

```bash
godot --path . -- --film=/tmp/film --reel=<id>   # film one story film with per-frame state in the log
godot --path . -- --tour=/tmp/tour               # every screen at three aspect ratios + gameplay smoke checks
godot --headless --path . -- --check             # load every script and scene
```

Shipping this edition without disturbing `main`'s build artifacts:

```bash
NINJA_OUT=/Users/karanvirkhanna/game-ninja/ninja-ios-story tools/ship_ios.sh 6
```

## The Yard

Games outside the trials. No seal, but a story of their own in `Story.YARD`, a
place on the chapter path as an interlude, an opening film, a goal film and a
journal entry.

- **Star Cricket** — every spring a cricket team from Japan climbs to the Star Dojo
  to pray before they play India. They have never won. Kuro does not do miracles;
  he does drills, so he laid a pitch in the yard and bowls with the void itself.
  Score fifty in one innings and Pip tells the team a ninja did it.

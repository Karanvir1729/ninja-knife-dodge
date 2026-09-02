# Agent Handoff: Ninja Knife Dodge v2

Last updated: September 1, 2026

## Current status

The v2 rebuild is implemented and verified. The original single-game Godot project is now a polished offline arcade hub containing the rebuilt **Knife Dodge** reflex game and a new **Shuriken Match** puzzle game. This handoff captures the work completed in Claude's local session so another agent can continue without needing that chat history.

- Repository: `https://github.com/Karanvir1729/ninja-knife-dodge`
- Local checkout: `/Users/karanvirkhanna/game-ninja/ninja-knife-dodge`
- Branch: `main`
- Engine: Godot 4.3+; most recent verification used Godot 4.7.2
- Platforms: iPhone and iPad, landscape
- Privacy model: fully offline; no accounts, ads, analytics, network access, or data collection
- Claude design canvas: `https://claude.ai/code/artifact/5c30bb3c-82a6-4675-8952-410068ea3938`

## Original product request

Improve the existing game with a state-of-the-art UI, menu, leaderboards, and creative polish. Add a second, more thoughtful game similar to Candy Crush while keeping the menu and instruction formats consistent across both games. The result must work on iPhone and iPad.

## What is implemented

### Shared game hub

- Neon-void main menu with separate Knife Dodge and Shuriken Match cards.
- Per-game summaries for best score, runs, unlocked level, and stars.
- Shared tutorial chooser, local leaderboards, settings, transitions, pause UI, responsive backgrounds, and audio handling.
- Player name, local lifetime statistics, top-ten leaderboards, and milestone titles.
- Settings for music, SFX, haptics, tutorial replay, privacy/support/credits, and guarded data reset.
- Version 1 high-score migration into the version 2 local save format.

### Knife Dodge

- Preserves the original one-touch movement and dagger-dodging loop.
- New responsive HUD with score, best score, timer, streak, and wave progress.
- Wave announcements for Volley, Crossfire, Ring, and Teeth formations.
- Near-miss scoring and streak multiplier.
- Floating bonuses, screen shake, death flash, particles, and improved feedback.
- Difficulty escalation whenever the wave sequence loops.
- Manual pause and automatic pause when the app backgrounds.

### Shuriken Match

- 8x8 match-3 board with 50 formula-driven levels.
- Move limits, target scores, and one-to-three-star thresholds.
- Four-tile Line, L/T Burst, and five-tile Prism specials.
- Special combinations including crossfire, triple cross, mega burst, prism/color, prism/special, and total-board eclipse.
- Cascade multipliers, hinting, dead-board reshuffling, gravity/refill animation, and leftover-move bonuses.
- Level select, interactive tutorial, play, pause, success, and failure screens.

## Architecture and important files

- `project.godot` registers the shared autoloads and uses `canvas_items` with aspect `expand`.
- `Globals.gd` owns palette constants, formatting, viewport helpers, safe-area calculation, and state navigation.
- `States/state_machine.gd` swaps all screens with a fade. State names include `start`, `tutorial`, `play`, `lose`, `match_levels`, `match_tutorial`, `match_play`, `match_result`, `leaderboard`, and `settings`.
- `autoload/SaveData.gd` owns the version 2 JSON save at `user://save.json`, local leaderboards, settings, stats, tutorials, and v1 migration.
- `autoload/AudioManager.gd` owns music crossfades, pooled SFX, volume settings, and haptics.
- `autoload/DebugTour.gd` loads every scene, captures responsive screenshots, and executes gameplay/tutorial smoke checks with in-memory sample data.
- `match/board_model.gd` is the pure puzzle rules engine: valid moves, run detection, special creation/combinations, cascades, gravity, refill, hints, and shuffle.
- `match/board_view.gd` renders and animates the board and owns pointer input.
- `match/levels.gd` defines the 50-level formula and star thresholds.
- `match/tutorial_layouts.gd` contains deterministic tutorial boards and allowed moves.
- `UI/theme.tres` and the other `UI/` scenes define the shared neon component system.
- `tests/test_board.gd` tests board rules and runs the greedy level-balancing bot.
- `tools/gen_assets.py` regenerates the files in `graphics/gen/` and requires Pillow.
- `tools/gen_sfx.py` regenerates the files in `sounds/gen/` using only the Python standard library.

## Design and layout rules

- Base design viewport: 1408x792.
- Background: `#07080d`; panel: `#0e0f16`; border: `#262a3d`; primary text: `#ebeef8`; muted text: `#8b92ab`.
- Cyan `#56f0ff` represents Knife Dodge, magenta `#ff4fd8` represents Shuriken Match, and gold `#ffd84d` represents stars and records.
- The viewport expands beyond the base dimensions on wider or taller devices. Do not hard-code the base rectangle for gameplay bounds or UI positioning.
- Use `Globals.view_rect()`, `Globals.view_size()`, `Globals.view_center()`, and `Globals.apply_safe_margins()` for responsive work.
- Keep the shared tutorial pattern: instruction at the top, a glowing interactive helper, and progress dots.

## Verification snapshot

All checks below passed on September 1, 2026 with Godot 4.7.2:

```bash
godot --headless --path . -s tests/test_board.gd
# 43 assertions, 0 failures; level-curve bot completed

godot --headless --path . -- --check
# 51 scripts/scenes loaded, 0 failures

godot --path . -- --tour=/tmp/ninja-tour
# 54 screenshots across 16:9, iPhone 19.5:9, and iPad 4:3
# 23 gameplay/tutorial/audio smoke checks, 0 failures
```

The full tour plays six real match-3 moves, completes both interactive tutorials, keeps the Knife Dodge player alive with simulated taps, kills the player, verifies results/stats, and confirms audio settings. It sets `SaveData.read_only`, so it does not overwrite the developer's save.

The headless whole-project check currently prints a non-fatal Godot shutdown warning about two leaked `ObjectDB` instances. It does not produce a test failure, but it is worth investigating if resource-lifetime cleanup becomes a priority.

## Known constraints and tuning notes

- Leaderboards must remain local unless the privacy policy and product requirements are intentionally changed. The current policy promises no networking or data collection.
- The greedy bot clears every sampled early level. Its observed clear rates were 83% at levels 20, 30, and 40 and 66% at level 50. Late levels are deliberately demanding. Tune `per_move` in `match/levels.gd` if player testing shows the curve is too steep.
- Generated `.uid` and `.import` files are intentional Godot project artifacts and belong in version control.
- The old placeholder backgrounds and `UI/thumbnail.tscn` were intentionally removed; their generated/neon replacements are in the new asset and UI directories.
- The iOS preset was bumped to app version 2.0, build 4, and the placeholder Godot icon was replaced.
- Automated desktop checks do not replace a final Xcode archive, signing check, App Store validation, or hands-on testing on physical iPhone and iPad hardware.

## Recommended next work

1. Play both games on physical iPhone and iPad devices and note touch-target, safe-area, text-size, performance, audio, and haptic issues.
2. Review Shuriken Match progression with human playtest data and adjust `match/levels.gd` only if the late-game curve feels unfair.
3. Investigate the two `ObjectDB` instances reported at shutdown if clean diagnostic output is desired.
4. Confirm Apple signing, bundle metadata, App Store screenshots, privacy answers, build-number bumping, archive, and upload in Xcode.
5. After any change, rerun the three commands in the verification section. Use `--quick` with the tour for a faster single-aspect iteration.

## Continuation guardrails

- Preserve the offline/privacy promise unless the owner explicitly authorizes a product change.
- Preserve unrelated user work and inspect `git status` before editing.
- Keep scene changes consistent with the shared theme and safe-area helpers.
- Treat `match/board_model.gd` as the rules source of truth and keep presentation/input concerns in `match/board_view.gd`.
- Update this file when architectural assumptions, validation commands, or known constraints change.

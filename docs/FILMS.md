# Story films

Every chapter of the story edition opens with a short in-engine film, and every
seal closes one. Films are GDScript scenes built on `story/film.gd` (`class_name
Film`): a shared dojo stage, typed captions, tap-to-hurry, SKIP, a slow camera,
spark bursts and a title card. A film is `story/films/<id>.gd` plus
`story/films/<id>.tscn` (a scene inherited from `story/film.tscn` with the script
swapped), and is played with

```gdscript
Globals.go("film", {"film": "<id>", "return": "start"})      # back to a state
Globals.go("film", {"film": "<id>", "play": "knife"})        # then start a game
Globals.go("film", {"film": "seal_blade", "then": {...}})    # then another film
```

Finishing or skipping sets the story flag `Story.film_flag(id)`
(`film_<id>_seen`; the prologue, midpoint and epilogue keep their old flags).
`Story.CHAPTERS` names which film opens each chapter and which plays for its seal;
a film that does not exist yet is skipped, so the hub keeps working while films
are being built.

| id | plays | length |
|---|---|---|
| `prologue` | first launch | ~50 s |
| `blade`, `eye`, `mind`, `name` | first time the chapter is opened | 30-45 s |
| `seal_blade`, `seal_eye`, `seal_mind`, `seal_name` | on the hub, once the seal is earned | 15-20 s |
| `cricket` | first time the interlude is opened | ~50 s |
| `cricket_fifty` | on the hub, after fifty in one innings | ~18 s |
| `midpoint` | on the hub, at two seals (chained after the seal film) | 20-30 s |
| `epilogue` | on the hub, at four seals | 30-40 s |

## Writing one

```gdscript
extends Film

func film_id() -> String: return "seal_blade"
func _shots() -> Array: return [_shot_one, _shot_two, _shot_title]
func _dress() -> void:
	_set_title("TITLE", "CAPS SUBTITLE", "One closing line.", [["glyph_blade", Globals.CYAN]])
func _build_extra() -> void:
	_show_dojo(0.0)                      # the dojo as it stands tonight, at once
	_old = _actor("sensei", _home_sensei(), 0.72, true, "neutral")
	_pip = _actor("pip", _home_pip(), 0.62, false, "happy")

func _shot_one() -> void:
	await _fade(0.0, 1.0)                # every first shot fades in from black
	_caption("Typed narration, one or two sentences, under 90 characters.")
	await _wait(3.0)
	_hint(true)                          # TAP TO CONTINUE before the last wait
	await _wait(1.6)
	_clear_caption()

func _shot_two() -> void:
	_advance = false                     # every later shot starts with this
	...
```

Every shot is a Callable that awaits its own timing. `_wait(sec)` returns early
when the player taps (after the caption has finished typing) or skips; `_shots()`
stops as soon as SKIP is pressed. Durations you pass are multiplied by `PACE`
(1.3), so plan a 30 s film as about 23 s of waits. End with `_shot_title` (the
base one) unless the film needs its own.

### The stage

The view is 1408 x 792 (wider on iPhone, taller on iPad); `_c` is its centre and
everything is placed relative to it. Keep what matters within x +-640 and
y +-360 of `_c`. Nodes live under `$Stage/Far` (torii, mist), `$Stage/Mid`
(platform, lanterns, props), `$Stage/Actors` (guides) and `$Stage/FX` (glyphs,
bursts, labels). The platform top is at `_c.y + 140`, spanning x +-300; a guide
standing on it has its origin around `_c.y + 62` (Sensei) or `+92` (Pip).

| helper | what it does |
|---|---|
| `_sprite(parent, tex, pos, scale, color, additive)` | a tinted sprite from `graphics/gen/story/<tex>.png` or any `res://` path |
| `_actor(character, pos, scale, facing_right, mood)` | a Mascot: `"sensei"`, `"young"` (Kuro a century ago) or `"pip"` |
| `_grow(mascot, from, to, dur)` | tween a guide's size |
| `_label(text, pos, size, color)` | a caps label in the world, centred on `pos` |
| `_show_dojo(dur, second_lantern)` | reveal the stage (lantern 1 is out tonight unless asked) |
| `_lantern(i)`, `_lantern_glow(i)` | the two lanterns and their glows |
| `_caption(text)` / `_caption_now(text)` / `_clear_caption()` | typed narration, instant narration, fade out |
| `_wait(sec)`, `_hint(on)` | pacing, and the TAP TO CONTINUE hint |
| `_fade(alpha, dur)`, `_flash(strength)` | black fade (await it), white flash |
| `_burst(at, color, amount, speed)` | a spark burst |
| `_cam(k, offset, dur)` | zoom the stage by `k` about the centre; `offset` pans (negative x looks right) |
| `_tween_alpha(node, a, dur)` | fade any canvas item |
| `_orbit`, `_orbit_on`, `_swirl`, `_swirl_on` | a spinning node for shurikens or dots, and a slow swirl |
| `_set_title(title, sub, line, glyphs)` | dress the title card; `glyphs` is up to four `[texture, Color]` |
| `_tick(delta)` | per-frame hook for your own motion |

Mascots: `set_mood("neutral"|"happy"|"think"|"excited")`, `hop(strength)`,
`point_at(global_pos)` / `unpoint()`, `set_facing(right)`, `enter(from, home, delay)`.
Palette: `Globals.CYAN` (blade), `ORANGE` (eye), `MAGENTA` (mind), `VIOLET`
(name), `GOLD` (seals, Pip), `GREEN` (the yard), `RED` (the Quiet's copies).
Sounds (`AudioManager.play_sfx(name, pitch, db)`): `whoosh`, `rise`, `impact`,
`shatter`, `seal`, `star_fall`, `star_ding`, `record`, `level_win`, `unlock`,
`pad_1`..`pad_9` (soft tones), `narrator_blip`, `guide_hop`, `guide_pop`,
`tile_land`, `swap_fail`, `shuffle`, `bowl`, `bat_hit`, `six`, `wicket`,
`target_spawn`, `target_hit`, `decoy_hit`, `simon_round`, `simon_fail`.

### Art

Props are white-or-coloured PNGs in `graphics/gen/story/`, drawn by
`tools/gen_story_assets.py` (Pillow, 4x supersampled, ink outlines). A film that
needs new props adds its own generator `tools/gen_film_<id>.py` following the
same style, runs it, then runs `godot --headless --path . --import` so Godot
writes the `.import` files; commit the PNGs and the `.import` files together.

### Checking it

```bash
godot --path . -- --film=/tmp/f --reel=<id>   # play the film unattended, a PNG every 0.8 s
godot --headless --path . -- --check          # every script and scene still loads
godot --path . -- --tour=/tmp/tour --quick    # the smoke tests, films included
```

Look at the frames. Captions must never overlap the actors' faces, nothing
important may sit under the top or bottom bars, and the film must return to the
hub on its own (the log ends with `FILM done ... state=start`).

# Ninja Knife Dodge

A pure reflex survival game built with [Godot 4.3](https://godotengine.org). You are a lone star adrift in the void — tap to propel yourself away from your finger and dodge escalating waves of daggers: timed volleys, full-circle ambushes, and rows that snap shut like teeth. One hit ends the run.

- One-touch controls, landscape, fully offline
- Local high score, no ads, no accounts, no data collection
- Ships on the iOS App Store as **Ninja Knife Dodge**

## Project layout

- `States/` — game states (start, tutorial, play, lose) driven by `state_machine.gd`
- `player/`, `objects/` — the star and the knives
- `ios_icons/` — generated App Store icon set
- `docs/` — support page and privacy policy (GitHub Pages)
- `export_presets.cfg` — Web, macOS, and iOS export presets

## Building for iOS

Open in Godot 4.3, export with the **iOS** preset (generates an Xcode project; `export_project_only=true`), then archive and upload with Xcode. The preset's `application/version` is the build number — bump it before every upload.

## Support / Privacy

Questions or bug reports: [open an issue](https://github.com/Karanvir1729/ninja-knife-dodge/issues) or email [mehar.khanna@uwaterloo.ca](mailto:mehar.khanna@uwaterloo.ca). The game collects no data — see the [privacy policy](docs/privacy.md).

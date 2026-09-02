# Shipping the 2.0 update to the App Store

The 1.x build on the store is the single-game version. 2.0 is a four-game arcade with guides, boosters and optional rewarded ads. This is the checklist for the update.

## 1. Engine and export

- Open the project in the Godot version you export with (4.3 or newer; 4.7.2 was used for development). Install that version's **export templates** (Editor > Manage Export Templates).
- `export_presets.cfg` already has `application/short_version="2.0"` and `application/version="4"`. Bump `application/version` (the build number) before **every** upload, and `short_version` for each store release.
- The iOS preset targets iPhone **and** iPad (`targeted_device_family=2`), landscape only, minimum iOS 12. The whole UI is safe-area aware and fills 19.5:9 and 4:3 screens; there is no letterboxing to explain to reviewers.
- Export with the iOS preset (`export_project_only=true` produces an Xcode project), open it in Xcode, set your team and signing, **Archive**, then upload with the Organizer or Transporter.

## 2. If you ship with rewarded ads

The code ships with a mock ad provider so all reward flows work without any SDK. To serve real ads:

1. Create an AdMob app and a **rewarded** ad unit. Put the unit id in `autoload/Ads.gd` (`ADMOB_REWARDED_UNIT_ID`).
2. Install a Godot 4 AdMob plugin for iOS (for example Poing Studios' `godot-admob-plugin` plus its iOS export plugin) and enable it in the iOS export preset. `Ads.gd` detects the plugin's classes at runtime and falls back to the mock when they are missing.
3. In the exported Xcode project's Info.plist add `GADApplicationIdentifier` (your AdMob app id), `NSUserTrackingUsageDescription` (for the App Tracking Transparency prompt), and the `SKAdNetworkItems` list from Google's docs. Request ATT permission before the first ad loads, or configure non-personalised ads.
4. App Store Connect > App Privacy: the app itself collects nothing, but the ad SDK does. Declare **Device ID** and **Product Interaction / Advertising Data** as collected by third parties for advertising, and answer "Yes" to tracking if you use the IDFA.
5. Point the App Privacy link at the updated policy (`docs/privacy.html`, "Optional rewarded ads" section). The in-app Privacy screen adds the same paragraph automatically when a real ad provider is active.
6. Age rating: rewarded video ads mean answering "Yes" to "Unrestricted Web Access"? No; but do answer the advertising questions truthfully. Keep the 4+ rating unless the ad network's content requires otherwise.

If you ship **without** the plugin, nothing changes for reviewers: no ad ever loads, and the privacy policy's ad paragraph explicitly covers that case.

## 3. Store listing

- Add iPad screenshots (12.9" and 11") alongside the 6.7"/6.5" iPhone set. The debug tour produces clean captures at the right aspect ratios: `godot --path . -- --tour=/tmp/shots` (iphone_* and ipad_* files); upscale to the exact store sizes.
- Suggested "What's New": four games in one (Knife Dodge, Quick Draw, Shuriken Match, Sensei Says); Mind and Skill categories; Sensei Kuro and Pip, your animated guides; local leaderboards with lifetime stats and titles; a 50-level Shuriken Match campaign with a level map; hints, power-ups and level skips; iPad support and safe-area layouts.
- Update the description and keywords for the new games.

## 4. Pre-submission checks

```bash
godot --headless --path . -s tests/test_board.gd   # rules
godot --headless --path . -- --check                # every script and scene loads
godot --path . -- --tour=/tmp/shots                 # screenshots + gameplay smoke checks at 16:9, iPhone, iPad
```

All three must finish with zero failures. Then play each game once on a real device: the first launch shows the guide intro, and each game's tutorial runs once.

## 5. Save-data compatibility

The v1 high score (`user://high_score`) and tutorial flag are migrated into the new `user://save.json` on first launch of 2.0, so existing players keep their best score and skip the Knife Dodge tutorial.

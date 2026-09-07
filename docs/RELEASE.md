# Shipping the 2.0 update to the App Store

The 1.x build on the store is the single-game version. 2.0 is a four-game arcade with guides, boosters and optional rewarded ads. This is the checklist for the update.

## 1. Engine and export

- Open the project in the Godot version you export with (4.3 or newer; 4.7.2 was used for development). Install that version's **export templates** (Editor > Manage Export Templates).
- `export_presets.cfg` already has `application/short_version="2.0"` and `application/version="4"`. Bump `application/version` (the build number) before **every** upload, and `short_version` for each store release.
- The iOS preset targets iPhone **and** iPad (`targeted_device_family=2`), landscape only, minimum iOS 15 (Apple requires 15+ for uploads from spring 2027). The whole UI is safe-area aware and fills 19.5:9 and 4:3 screens; there is no letterboxing to explain to reviewers.
- Export with the iOS preset (`export_project_only=true` produces an Xcode project), open it in Xcode, set your team and signing, **Archive**, then upload with the Organizer or Transporter.

## 2. If you ship with ads

The code ships with a mock ad provider so all reward flows work without any SDK. To serve real ads:

1. Create an AdMob app for the iOS bundle `com.karanvirKhanna.comme` and two ad units in the [AdMob console](https://apps.admob.com): one **rewarded** ("Rewarded boosters") and one **interstitial** ("Between rounds"). You get an app id (`ca-app-pub-XXXX~YYYY`) and one unit id per unit (`ca-app-pub-XXXX/ZZZZ`).
2. They live in Project Settings (`project.godot`): `admob/general/ios/app_id` = `ca-app-pub-8472416478626307~4022491082` and `ninja/ads/rewarded_unit_id` = `ca-app-pub-8472416478626307/4361402439` and `ninja/ads/interstitial_unit_id` = `ca-app-pub-8472416478626307/7349512528` (AdMob account `karan@daybot.ca`, publisher `pub-8472416478626307`, ad units "Rewarded boosters" and "Between rounds"). Interstitial pacing is `ninja/ads/interstitial_every_rounds` (3), `interstitial_min_gap_sec` (120) and `interstitial_warmup_rounds` (2). `Ads.gd` serves Google's **test** unit on any install that carries an embedded provisioning profile (TestFlight, Xcode) and the live unit only on App Store installs, so testers can never generate invalid traffic. AdMob still lists the app as "Requires review / limited ad serving" until Google's app review completes; app-ads.txt verification needs the App Store listing's developer URL to be a domain you control (e.g. daybot.ca) hosting `/app-ads.txt` with `google.com, pub-8472416478626307, DIRECT, f08c47fec0942fa0`.
3. The Poing Studios AdMob plugin (`addons/admob`, with the Godot 4.7.2 iOS binaries in `addons/admob/ios/bin`) is enabled in the project. On export it adds the Google Mobile Ads SDK via Swift Package Manager, links the native plugin, and writes `GADApplicationIdentifier` plus the full `SKAdNetworkItems` list into Info.plist. `tools/ship_ios.sh` needs no changes; the first archive after a fresh export downloads the SDK packages (a few minutes).
4. No App Tracking Transparency prompt is shown and the IDFA is never requested, so ads are non-personalised. App Store Connect > App Privacy: answer **No** to "Do you or your third-party partners use data for tracking?", then declare what the ad SDK still collects - **Identifiers (Device ID)**, **Usage Data (Product Interaction, Advertising Data)** and **Diagnostics (Crash Data)** - as "used for third-party advertising", not linked to the user.
5. Point the App Privacy link at the updated policy (`docs/privacy.html`, "Ads" section). The in-app Privacy screen adds the same paragraph automatically when a real ad provider is active.
6. Age rating: rewarded video ads mean answering the advertising questions truthfully; keep the 4+ rating unless the ad network's content requires otherwise. New AdMob apps usually need a few hours (and a verified payments profile) before live ads fill; until then the SDK reports "no fill" and the game simply offers the booster path instead.

On macOS, in the editor and in the debug tour the game uses its own offline "test ad" overlay instead of the SDK, so tests stay deterministic; only iOS and Android builds with the native plugin show real ads.

## 2b. Accounts: Sign in with Apple and Supabase

Since build 11 players sign in with Apple on first launch (`States/signin_state`), and
`autoload/Backend.gd` mirrors the save to a Supabase project after every round.

- **Supabase project** `ninja-knife-dodge` (org Daybot, ref `inbwlcpvunzeprmhxyhd`,
  `https://inbwlcpvunzeprmhxyhd.supabase.co`). The publishable key and URL live in
  `project.godot` under `ninja/backend/*`; the publishable key is safe to ship. Never put a
  secret key in the app. Schema: table `public.players` (one row per auth user, RLS: own row
  only), view `public.leaderboard` (names and scores, readable by anyone), functions
  `handle_new_user` (row on sign-up), `delete_my_account` (App Review 5.1.1(v)). Auth >
  Providers > Apple is enabled with the bundle id `com.karanvirKhanna.comme` as a client id;
  native sign-in needs no secret key.
- **Native plugin** `ios/plugins/apple_signin` (`apple_signin.gdip`, built by
  `tools/build_ios_plugin.sh` against a Godot source checkout of the template version, see
  the script header). The preset enables it (`plugins/AppleSignIn=true`) and adds the
  `com.apple.developer.applesignin` entitlement (`entitlements/additional`). The App ID has the
  Sign in with Apple capability; the "Ninja App Store" profile was regenerated after adding it
  (uuid in `application/provisioning_profile_uuid_release`).
- **App Privacy**: Sign in with Apple collects an identifier and optionally an email, linked
  to the user, used for app functionality. Declare **Contact Info (Email)**, **Identifiers
  (User ID)** and **Gameplay Content** as linked to the user; the privacy policy has an
  "Your account" section.
- Desktop, the simulator and the debug tour have no Apple plugin: the sign-in screen offers
  "continue on this device" there, and the tour never touches the network.

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

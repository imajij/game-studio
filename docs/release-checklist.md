# Release checklist

Run top to bottom for every release, first build or update.

## Build quality
- [ ] `tools/check.sh <slug>` passes — no script errors or warnings
- [ ] Playtested on a real low/mid-range Android phone: steady 60 fps, no crashes, one full session
- [ ] versionCode bumped (+1) and versionName updated in `export_presets.cfg`
- [ ] `GAME.md` version history row added
- [ ] No debug UI or cheats reachable in release build

## Ads
- [ ] Real IDs present in `ads_config.local.cfg` (gitignored); debug build still uses Google test IDs
- [ ] Rewarded is opt-in only; interstitial placements are natural breaks; no ad covers controls
- [ ] Game plays fine with ads failing (airplane mode test)

## Policy / Play Console
- [ ] Target API level meets Google Play's CURRENT requirement — check
      https://developer.android.com/google/play/requirements/target-sdk (it rises every August;
      set `gradle_build/target_sdk` in the Android preset if Godot's default is behind)
- [ ] Privacy policy URL is live and set in the store listing
- [ ] Data safety form matches the SDKs actually in the build (AdMob ⇒ device/ad identifiers)
- [ ] "Contains ads" declared
- [ ] Target audience declared honestly; under-13 appeal ⇒ Families policy requirements
- [ ] Listing: honest screenshots, original art/names, no keyword stuffing or "#1" claims

## Ship
- [ ] `tools/build-android.sh <slug>` — .aab lands in `builds/`, under 40 MB
- [ ] Upload to Play Console (internal test track first for a new game)
- [ ] `git status` — no secrets or build outputs staged
- [ ] Commit, tag `<slug>/v<versionName>`, `git push --follow-tags`
- [ ] `docs/games-log.md` + README table status updated
- [ ] `~/keystores/` backed up somewhere safe (losing the upload key is painful)

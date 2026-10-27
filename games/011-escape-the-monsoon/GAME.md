# GAME: Escape the Monsoon

- Status: in review (closed test)
- Package: com.zintara.escape_the_monsoon
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Three-lane runner where the monsoon flood wave is permanently behind you and the
things chasing you rotate in absurd themes: flood junk, an aunty stampede, a full
wedding baraat.

## Core loop (30–90 s per round, instant restart)
Run forever → swipe between lanes, swipe up to jump puddles/chappals/garlands,
dodge barrels/aunties/dhol drummers → every hit lets the wave surge closer
(it slowly recedes while you run clean) → wave reaches you = game over.
Theme switches every 400 m with a banner.

## Controls (one thumb, portrait)
Swipe left/right to change lane, swipe up to jump.

## Progression
Distance score + umbrella pickups (+25), all-time best. Speed ramps with distance.

## Ad placements
- Rewarded (opt-in only): one revive per run (wave resets, board clears).
- Interstitial: on restart after game over; AdsManager frequency caps apply.
- Banner: none.

## Art style
Rainy blue-grey road, animated rain streaks, vector runner with jump shadow,
rising water wall whose height telegraphs danger. All characters original.

## Sound list
| Sound | When | File |
|-------|------|------|
| swipe | lane change / jump / theme switch | assets/audio/swipe.wav |
| splash | hit in flood theme | assets/audio/splash.wav |
| crash | hit in other themes | assets/audio/crash.wav |
| pickup | umbrella | assets/audio/pickup.wav |
| game_over | wave catches you | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: Escape the Monsoon
- Short description (80 chars): The flood is behind you. The aunties are ahead. Swipe, jump, survive the rain.
- Full description: see marketing/escape-the-monsoon/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): 3-lane runner, 3 rotating themes, wave pressure, child-directed ads |

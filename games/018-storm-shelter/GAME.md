# GAME: Storm Shelter

- Status: in progress (batch 3)
- Package: com.zintara.storm_shelter
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Shelter-upgrade ad-genre tycoon in vibrant 3D cutaway: dig your bunker deeper,
every floor earns supplies, and a MEGA-STORM lands every 45 seconds — out-upgrade
the storm or it taxes your stockpile.

## Core loop (45 s storm cycles, endless)
Earn supplies → DIG (new producing floor, worker blob moves in) → upgrade the
HATCH before the countdown ends → storm hits with rain/shake/dark sky → hatch ≥
storm level = big bonus + confetti, else lose 35% of supplies → next storm is
stronger. Offline earnings pull you back (4 h cap, 50% rate).

## Controls (one thumb, portrait)
Three buttons: DIG, HATCH, CRATE·AD.

## Progression
Floor costs ×1.38, production ×1.18/floor, hatch costs ×1.5, storm level +1 per
cycle — a pure keep-up race.

## Ad placements
- Rewarded (opt-in only): supply crate = 60 s of production instantly.
- Interstitial: after each storm result (natural break); AdsManager caps apply.
- Banner: none.

## Art style
Vibrant low-poly primitive 3D (kit.gd): candy sky gradient that turns stormy,
lime hills, teal hatch dome, cream rooms with colored machines + candy worker
blobs, confetti bursts. All in-engine, zero textures.

## Sound list
build, coin, storm (rumble), safe (fanfare), crash, game_over, tap — assets/audio/.

## Store listing
- Title: Storm Shelter
- Short description: The storm hits in 45 seconds. Dig deeper, bolt the hatch, out-grow the sky.
- Full description: see marketing/storm-shelter/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: dig/hatch/storm loop, offline earnings, child-directed ads |

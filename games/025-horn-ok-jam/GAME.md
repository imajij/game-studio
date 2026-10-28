# GAME: Horn OK Jam

- Status: in progress (batch 3)
- Package: com.zintara.horn_ok_jam
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Parking-jam ad genre in a bazaar lot: every vehicle drives straight in the
direction its windshield eyes face. Tap in the right order or eat a honking
bump and a wasted tap.

## Core loop (20–60 s per jam, instant retry)
Read the lot → tap a vehicle → clear path = it vrooms off with a dust puff,
blocked = bump + HONK + tap gone → empty the lot before taps run out.
Levels are generated and simulation-verified solvable (greedy-clearable).

## Controls (one thumb, portrait)
Tap vehicles.

## Progression
Jam number saved; vehicles 6→12, spare taps shrink relative to fleet size.

## Ad placements
- Rewarded (opt-in only): +3 taps on a fail, once per jam.
- Interstitial: at result screens; AdsManager caps apply.
- Banner: none.

## Art style
Flow asphalt texture with painted lines, candy vehicles with light cabs and
windshield eyes, ring of tiny cone-roofed bazaar stalls around the lot.

## Sound list
vroom, honk, win, lose, tap — assets/audio/.

## Store listing
- Title: Horn OK Jam
- Short description: Every tap drives a vehicle straight ahead. Wrong order = HONK. Empty the lot.
- Full description: see marketing/horn-ok-jam/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: solvable-verified jams, +3 taps ad, child-directed ads |

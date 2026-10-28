# GAME: Gravity Gully

- Status: in progress (batch 3)
- Package: com.zintara.gravity_gully
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Subway-style endless runner down a candy canyon with one twist that makes it
ours: swipe UP to FLIP GRAVITY and run on the ceiling. Two surfaces, three
lanes each, one accelerating sprint. (Deliberately distinct from 011's 2D
swipe-lane runner via the dual-surface mechanic and full 3D chase cam.)

## Core loop (30–90 s per run, instant restart)
Auto-run → swipe ←→ for lanes, swipe ↑ to flip floor/ceiling → thread candy
blocks on BOTH surfaces → grab coins → speed ramps forever → one crash ends it.
Brief flip grace window keeps flips feeling heroic, not suicidal.

## Controls (one thumb, portrait)
Swipes only.

## Progression
Distance best + banked coins persist. Speed 9→22 with distance.

## Ad placements
- Rewarded (opt-in only): one revive per run (clears nearby blocks).
- Interstitial: on restart; AdsManager caps apply.
- Banner: none.

## Art style
Sunset-sherbet sky, pink/orange canyon walls, teal floor vs sunshine ceiling,
candy-colored blocks, mint particle trail, confetti on coins. All in-engine.

## Sound list
flip, coin, crash, game_over, tap — assets/audio/.

## Store listing
- Title: Gravity Gully
- Short description: Run the floor. Flip to the ceiling. The canyon only gets faster.
- Full description: see marketing/gravity-gully/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: dual-surface runner, coins, revive, child-directed ads |

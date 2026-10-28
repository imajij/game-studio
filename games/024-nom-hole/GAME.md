# GAME: Nom Hole

- Status: in progress (batch 3)
- Package: com.zintara.nom_hole
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
hole.io ad genre, fully single-player: you're a hungry hole in a toy town,
swallowing cones → crates → trees → carts → buses as you grow, racing two AI
holes for the same buffet. All props are empty toys — nobody inside anything.

## Core loop (90 s rounds, instant restart)
Joystick the hole → anything smaller than you within reach sinks in (gulp pitch
drops as you grow) → points grow your radius and the camera pulls back → last-5
-seconds tick panic → standings vs the two rivals.

## Controls (one thumb, portrait)
Dynamic joystick.

## Progression
Best score saved; the in-round power curve (cone-nibbler → bus-eater) IS the hook.

## Ad placements
- Rewarded (opt-in only): +30 seconds, once per round.
- Interstitial: on restart; AdsManager caps apply.
- Banner: none.

## Art style
Toy town on a Flow ground texture, candy crates, lollipop trees, pink-canopy
carts, sunshine buses, ink-dark holes with colored rims (teal you, red/purple AI).

## Sound list
gulp, grow, big, tick, win, game_over, tap — assets/audio/.

## Store listing
- Title: Nom Hole
- Short description: You are a hole. The town is lunch. Out-eat two rival holes in 90 seconds.
- Full description: see marketing/nom-hole/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: grow-and-swallow loop vs 2 AI holes, +30s ad, child-directed ads |

# GAME: Bazaar Tower Defense

- Status: release-ready — Play app creation blocked by weekly limit, create ~2026-11-03
- Package: com.zintara.bazaar_defense
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Meme creatures march the winding gali toward your shop; build desi defense units
on fixed spots and evolve them. Boss every 5th wave. Endless — score is waves
survived.

## Core loop (3–8 min per run, instant restart)
Build phase (5 s between waves) → tap a + spot → Chai Cannon (single shot),
Pakora Mortar (splash) or Fan Blower (slow) → waves of runners/tanks/swarmlings
walk the S-path → leaks cost shop hearts (5) → clear waves for ₹ → EVOLVE
towers to L3 (gold spark ring).

## Controls (one thumb, portrait)
Tap a spot to open the build/evolve panel; tap elsewhere to close; GO button to
start waves early.

## Progression
Endless wave scaling (hp ×1.14/wave), best-wave saved, 3 unit types × 3 levels,
boss waves with crowns.

## Ad placements
- Rewarded (opt-in only): FREE EVOLVE voucher — upgrades your lowest tower;
  2-min cooldown.
- Interstitial: on restart after game over; AdsManager frequency caps apply.
- Banner: none.

## Art style
Olive-green bazaar ground, brown clay path, vector creeps with helmets/crowns,
kettle/kadhai/fan towers with spinning blades and level pips. All original.

## Sound list
| Sound | When | File |
|-------|------|------|
| place / evolve | build actions | assets/audio/place.wav, evolve.wav |
| shoot / hit | combat | assets/audio/shoot.wav, hit.wav |
| wave / win | wave start / cleared | assets/audio/wave.wav, win.wav |
| lose_life | creep leaks | assets/audio/lose_life.wav |
| game_over | shop looted | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: Bazaar Tower Defense
- Short description (80 chars): Chai cannons vs meme creatures. Defend the shop, evolve your units, hold the gali.
- Full description: see marketing/bazaar-defense/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): 3 units × 3 levels, endless waves, bosses, child-directed ads |

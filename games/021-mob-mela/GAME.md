# GAME: Mob Mela

- Status: in progress (batch 3)
- Package: com.zintara.mob_mela
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Crowd-runner ad genre (Count-Masters-style): steer a growing mob of candy blobs
through ×2/+25 gates, dodge the −30% walls, then sumo-shove the rival mob at the
mela gate. Shoving only — losing blobs pop away smiling.

## Core loop (~60 s per mela, instant retry)
10 blobs start → pick the better gate each row (the unchosen gate vanishes) →
red walls cost 30% → finish arch triggers the push-battle: both mobs shed blobs,
the bigger sheds slower → win = next mela with a tougher rival.

## Controls (one thumb, portrait)
Drag to steer. Tap to start.

## Progression
Mela level saved (rival = 18 + 14/level). Gate math is the skill.

## Ad placements
- Rewarded (opt-in only): START ×2 CROWD before the run.
- Interstitial: after each mela result; AdsManager caps apply.
- Banner: none.

## Art style
Festival ground: lime track, cream edges, candy bunting flags on poles, glowing
mint/red gates with Label3D math, confetti everywhere on wins.

## Sound list
gate, pop, win, lose, game_over, tap — assets/audio/.

## Store listing
- Title: Mob Mela
- Short description: Grow the mob through ×2 gates, dodge the red walls, out-shove the rival mela.
- Full description: see marketing/mob-mela/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: gate math + push battle, ×2 start ad, child-directed ads |

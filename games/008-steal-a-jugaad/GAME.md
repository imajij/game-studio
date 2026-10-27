# GAME: Steal a Jugaad

- Status: in review (closed test)
- Package: com.zintara.steal_a_jugaad
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Collect absurd original desi creatures (Samosa Sherni, Chai Walrus, Disco Buffalo…)
off a bazaar conveyor, earn idle rupees from your godown, and raid AI godowns past a
sleepy guard. Steal-a-base loop, fully offline — every "other player" is AI.

## Core loop (30–90 s per round, instant restart)
Creatures walk the conveyor with price tags → tap to buy before they walk off →
each one earns ₹/s on a pedestal → RAID: hold-to-sneak past the guard's
open/closed eye (red-light-green-light) to steal a creature → occasional
counter-thief shows up: tap him 5 times fast or lose your newest creature.

## Controls (one thumb, portrait)
- Tap a conveyor creature to buy it.
- RAID: hold anywhere to sneak, release to freeze; guard's eye open = freeze or get caught.
- Thief alert: tap the thief repeatedly.

## Progression
10 original creatures across 5 rarities (Common → Mythic); income/net-worth climb;
"HOT DROP" featured creature rotates every 10 minutes (2× spawn rate — the FOMO hook);
offline earnings capped at 4 h pull players back.

## Ad placements
- Rewarded (opt-in only): Lucky Crate — rarity-skewed random creature.
- Interstitial: after raid result dismissal only; AdsManager frequency caps apply.
- Banner: none.

## Art style
Flat vector sticker-blobs drawn in-engine (thick dark outlines, rarity-colored
pedestal rings), warm bazaar-night palette. All creatures original.

## Sound list
| Sound | When | File |
|-------|------|------|
| buy | creature bought | assets/audio/buy.wav |
| coin | offline claim | assets/audio/coin.wav |
| crate | rewarded crate opens | assets/audio/crate.wav |
| caught | raid fail / thief escape | assets/audio/caught.wav |
| steal | raid success / thief chased | assets/audio/steal.wav |
| game_over | (reserved) | assets/audio/game_over.wav |
| tap | buttons | assets/audio/tap.wav |

## Store listing
- Title: Steal a Jugaad
- Short description (80 chars): Buy weird desi creatures, earn idle cash, raid the guard. Don't get caught!
- Full description: see marketing/steal-a-jugaad/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): conveyor + raids + thief + crate, child-directed ads |

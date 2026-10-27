# GAME: Rank the Rot

- Status: in review (closed test)
- Package: com.zintara.rank_the_rot
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Swipe-to-tier-list: an original rot creature card appears, you flick it into
S / A / B / F. Then the daily "Mohalla Panel" verdict is revealed and grades your
taste. Arguing with the panel is the retention.

Honesty note: the "panel" is a deterministic in-game jury seeded by the calendar
date — every player sees the same verdict on the same day, but it is NOT real
online voting (the game is fully offline). The listing says "daily panel", never
"community votes".

## Core loop (45–90 s per round, instant restart)
8 random cards from a cast of 10 → swipe ↑ S, → A, ↓ B, ← F (card tilts and
tints as you drag) → reveal: exact match 3 pts, one tier off 1 pt → verdict text
("CERTIFIED TASTE" / "MID. RESPECTFULLY." / "THE PANEL IS DISAPPOINTED").
New panel verdict every calendar day.

## Controls (one thumb, portrait)
Swipe the card in one of four directions.

## Progression
All-time best score; the daily reshuffle is the comeback hook.

## Ad placements
- Rewarded (opt-in only): PEEK — shows the panel's tier for the next 3 cards.
- Interstitial: on restart after the reveal; AdsManager frequency caps apply.
- Banner: none.

## Art style
Cream playing cards with vector creature blobs (10 original characters:
Gyaan Pigeon, WiFi Chacha, Tubelight Tiger, Scooter Shark, Golgappa Ghost,
Filter Coffee Falcon, Thermocol Titan, Dramatic Lizard, Inverter Owl, Mango
Mummy), tier-colored board rows at the bottom.

## Sound list
| Sound | When | File |
|-------|------|------|
| swipe / place | card placed | assets/audio/swipe.wav, place.wav |
| reveal | panel reveal | assets/audio/reveal.wav |
| match / mismatch | verdict quality | assets/audio/match.wav, mismatch.wav |
| game_over | (reserved) | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: Rank the Rot
- Short description (80 chars): Tier-list weird creatures. The daily panel judges your taste. Argue tomorrow.
- Full description: see marketing/rank-the-rot/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): swipe tiering, daily panel verdict, peek hints, child-directed ads |

# GAME: 67 Reflex

- Status: in review (closed test)
- Package: com.zintara.reflex_67
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Hyper-casual timing test: the beat counts 1-2-3-4-5 by itself, then you must tap
EXACTLY on "six…" and "seven". Every pair you land, the beat speeds up.

## Core loop (10–60 s per round, instant restart)
Watch the ring fill → beats 1–5 tick automatically → tap on 6, tap on 7
(±0.17 s good, ±0.09 s PERFECT) → tempo ramps 3.5% per pair → three lives.
Tapping early during 1–5 also costs a life (no spamming).

## Controls (one thumb, portrait)
Tap anywhere. That's the whole game.

## Progression
Score (2 per PERFECT, 1 per GOOD), perfect streak counter, daily best + all-time
best stored locally. The daily best resets every calendar day — the comeback hook.

## Ad placements
- Rewarded (opt-in only): one revive per run (3 lives back).
- Interstitial: on restart after game over; AdsManager frequency caps apply.
- Banner: none.

## Art style
Neon minimal: dark indigo field, cyan beat ring that flips hot pink on 6/7,
giant Baloo number, full-screen color flash on perfect/miss.

## Sound list
| Sound | When | File |
|-------|------|------|
| beat | beats 1–5 | assets/audio/beat.wav |
| six / seven | landed taps | assets/audio/six.wav, seven.wav |
| perfect | perfect window | assets/audio/perfect.wav |
| fail | missed window / early | assets/audio/fail.wav |
| game_over | lives out | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: 67 Reflex
- Short description (80 chars): The beat counts to five. YOU are six and seven. How fast can you stay on it?
- Full description: see marketing/reflex-67/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): 6-7 timing loop, daily best, child-directed ads |

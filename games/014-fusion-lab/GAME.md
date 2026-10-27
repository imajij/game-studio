# GAME: Brainrot Fusion Lab

- Status: in review (closed test)
- Package: com.zintara.fusion_lab
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Mash two essences (Jalebi + Tubelight = "Jalelight") into a fusion creature and
battle the Lab's AI fusions. Fully offline — every opponent is generated locally.

Families-safety note: fusion names are assembled from fixed syllable pools only.
There is NO free-text input and NO sharing, so Play's UGC rules don't trigger.

## Core loop (30–60 s per round, instant restart)
Pick 2 of 8 essences → FUSE (zap!) → auto-named fusion with POWER/SPEED/CHAOS
stats (sum of parents) → 3-heart battle vs a random AI fusion: each exchange both
sides swing with a random stat + jitter, higher roll lands the hit → win trophies
and streaks.

## Controls (one thumb, portrait)
Tap essences, tap FUSE, tap through the result.

## Progression
Trophy count + best streak saved. Two rare essences (Dhol, Monsoon Cloud — the
best stat totals) are sealed behind a one-time rewarded ad, unlocked forever.

## Ad placements
- Rewarded (opt-in only): one-time permanent unlock of both rare essences.
- Interstitial: when leaving the result screen; AdsManager frequency caps apply.
- Banner: none.

## Art style
Teal lab bench, fusion creatures drawn as blended-color blobs with one antenna
from each parent and parent-colored half-rings. All essences original.

## Sound list
| Sound | When | File |
|-------|------|------|
| fuse | fusion created | assets/audio/fuse.wav |
| spawn | battle starts | assets/audio/spawn.wav |
| hit | each exchange | assets/audio/hit.wav |
| win / lose | battle result | assets/audio/win.wav, lose.wav |
| game_over | (reserved) | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: Brainrot Fusion Lab
- Short description (80 chars): Fuse a jalebi with a tubelight. Name it Jalelight. Send it to battle. Science!
- Full description: see marketing/fusion-lab/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): fuse + auto-name + AI battles, rare unlock, child-directed ads |

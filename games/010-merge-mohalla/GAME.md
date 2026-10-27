# GAME: Merge Mohalla

- Status: in review (closed test)
- Package: com.zintara.merge_mohalla
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Watermelon-game-style drop-merge, desi street edition: two chai cups make a samosa,
two samosas make a jalebi… ten tiers deep until the Cursed Hybrid. What's the final
form? That curiosity is the hook.

## Core loop (60–120 s per round, instant restart)
Drag to aim, release to drop → same objects touching merge into the next tier
(physics push everything around) → keep the gali below the red line → overfill
for ~2 s = GALI JAM, game over.

## Controls (one thumb, portrait)
Touch/drag anywhere to position the drop; release to drop.

## Progression
Score per merge (tier × 10, final-form merge +1000), all-time best, and a
"FOUND x/10 THINGS" discovery counter saved across runs.

## Ad placements
- Rewarded (opt-in only): Jhadu Sweep — clears all tier-1/2 clutter; 2-min cooldown,
  only offered when the board is crowded.
- Interstitial: on restart after game over; AdsManager frequency caps apply.
- Banner: none.

## Art style
Flat vector circles with faces and tier accents, warm chai-brown gali backdrop,
confetti on discoveries. All objects original.

## Sound list
| Sound | When | File |
|-------|------|------|
| drop | item dropped | assets/audio/drop.wav |
| merge | ordinary merge (pitch rises with tier) | assets/audio/merge.wav |
| big_merge | new discovery / final form / sweep | assets/audio/big_merge.wav |
| warn | danger line breached | assets/audio/warn.wav |
| game_over | gali jam | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: Merge Mohalla
- Short description (80 chars): Two chai cups make a samosa. Keep merging. The final form is… cursed.
- Full description: see marketing/merge-mohalla/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): 10-tier physics merge, discovery log, child-directed ads |

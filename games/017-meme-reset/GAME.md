# GAME: Meme Reset 2014

- Status: release-ready — Play app creation blocked by weekly limit, create ~2026-11-03
- Package: com.zintara.meme_reset
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Contrarian play on the "Great Meme Reset": a retro CRT brick-smasher set in 2014
internet. Golden bricks drop collectible era-cards — ORIGINAL tributes to 2010s
artifacts (Shutter Shades, Planking Pete, Dial-Up Demon, Swag Fedora…), no real
meme IP, no real people.

## Core loop (60–120 s per round, instant restart)
Drag the fedora-paddle → launch the ball → smash neon brick walls (cyan bricks
take 2 hits) → golden bricks drop a random missing era-card → clear the wall,
level up, ball speeds up → 3 balls then SIGNAL LOST.

## Controls (one thumb, portrait)
Touch/drag to move the paddle; tap to launch.

## Progression
Score + best, endless levels (rows cap at 7, speed climbs), and the 10-card
era collection that persists forever — the "remember this?" share hook.

## Ad placements
- Rewarded (opt-in only): one EXTRA BALL per run.
- Interstitial: on restart after game over; AdsManager frequency caps apply.
- Banner: none.

## Art style
Dark CRT purple with scanlines, magenta/cyan/gold bricks, fedora-shaped paddle,
glowing ball. Era-cards are text + icons, all original.

## Sound list
| Sound | When | File |
|-------|------|------|
| bounce / brick | ball hits | assets/audio/bounce.wav, brick.wav |
| card | era-card drop | assets/audio/card.wav |
| lose_ball | ball lost | assets/audio/lose_ball.wav |
| level | wall cleared | assets/audio/level.wav |
| game_over | out of balls | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: Meme Reset 2014
- Short description (80 chars): The internet got reset. Smash your way back to 2014 and collect the era-cards.
- Full description: see marketing/meme-reset/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): CRT brick-smasher, 10 era-cards, extra ball, child-directed ads |

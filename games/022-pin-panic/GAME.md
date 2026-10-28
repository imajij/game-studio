# GAME: Pin Panic

- Status: in progress (batch 3)
- Package: com.zintara.pin_panic
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Pull-the-pin ad genre: tap the blue pins in the right order so the gold balls
pour into the pot and the purple gunk pours anywhere else. Real 3D physics in a
cream vat board.

## Core loop (15–40 s per vat, instant retry)
Read the layout → tap pins (they slide out with a clack) → gravity does the rest
→ enough gold in the pot = POT OF GOLD, one gunk ball in = GUNKED. Endless
seeded vats: more gold, more gunk, trickier pin tilts as levels climb.

## Controls (one thumb, portrait)
Tap a pin. That's it.

## Progression
Vat number saved; layouts seeded per level (deterministic retries).

## Ad placements
- Rewarded (opt-in only): SKIP VAT after a fail.
- Interstitial: at result screens; AdsManager caps apply.
- Banner: none.

## Art style
Lavender-peach sky, cream board, sky-blue pins with ball knobs, sunshine gold
vs purple gunk, orange pot, confetti pours on wins.

## Sound list
pin, gold, gunk, win, lose, tap — assets/audio/.

## Store listing
- Title: Pin Panic
- Short description: Pull the right pin. The gold falls, the gunk follows. Don't mix them up.
- Full description: see marketing/pin-panic/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: physics pins, seeded vats, skip ad, child-directed ads |

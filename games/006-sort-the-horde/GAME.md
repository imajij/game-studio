# GAME: Sort the Horde

- Status: prototype (greybox done; art + AdMob ids pending)
- Package: com.zintara.sort_the_horde
- Target audience age: 13+ (general casual; not designed for children)
- Privacy policy URL: (required before release)

## Concept
The horde descends one creature at a time. Ghouls get swiped LEFT into the
dungeon; babies get swiped RIGHT into daycare. Past score 15 the horde plays
dirty: ghouls arrive in cute bows, babies arrive wearing fake fangs.

## Core loop (30–90 s, instant restart)
Read → swipe → next (falls faster every point) → streak bonus (+5 every 10)
→ one misread or timeout costs a life → 3 lives → "one more sort".

## Controls (one thumb, portrait)
Swipe left/right anywhere (90 px threshold). Tap to restart.

## Cast (original)
Ghouls: Grimble · Soggy Joe · Bitey. Babies: Beanie · Pudge · Sprout.
Disguises are visual lies only — type never changes.

## Ad placements (wired, Google test ids until release)
- Rewarded revive (opt-in, once): full lives, keep score and speed.
- Interstitial: restart tap only, AdsManager caps.

## Art style (pending)
Dungeon-purple vs daycare-yellow split palette, Flow sticker pass. Greybox:
jagged-brow fanged circles vs sparkle-eyed blushing circles.

## Sounds
Synth placeholders (correct chime pitched by streak, wrong buzz, swipe
whoosh, game-over walk, tap).

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 0.1.0 | 1 | 2026-10-26 | Greybox + ads wiring (unreleased) |
| 1.0.0 | 1 | 2026-10-27 | First Play Store build: child-directed ads (Families), signed .aab |

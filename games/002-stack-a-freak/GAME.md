# GAME: Stack-a-Freak

- Status: prototype (greybox done; art + AdMob ids pending)
- Package: com.zintara.stack_a_freak
- Target audience age: 13+ (general casual; not designed for children)
- Privacy policy URL: (required before release)

## Concept
A crane swings a squishy square freak over a narrow platform; tap to drop it
and stack the tower as high as you can. Three fallen freaks and it's over.

## Core loop (30–90 s, instant restart)
Watch the swing → time the tap → wobble sweat → +1 per stacked freak,
+3 perfect-drop bonus (landed within 22 px of the stack top) → crane speeds
up as the tower grows → camera climbs with you.

## Controls (one thumb, portrait)
Tap anywhere to release. Tap to restart on game over.

## The freaks (visual variety only — same physics)
Blobby Greg (jelly teal) · Mister Loaf (crust tan) · Angry Flan (caramel) ·
Bricked Frog (green) · Stressed Mallow (pink) · The Unit (big, concrete).
Sizes 150–200 px; mass scales with area, so The Unit crushes sloppy towers.

## Ad placements (wired, Google test ids until release)
- Rewarded "GLUE · AD" (opt-in): freezes every settled freak solid — once per
  round, offered only with 4+ stacked and an ad loaded.
- Interstitial: on the restart tap, AdsManager caps (≥3 rounds, ≥150 s).

## Art style (pending)
Flow sticker pass like Jar of Goofs but square plush bodies; daylight mint
pastel backdrop. Greybox = rounded squares with googly eyes.

## Sounds
Synth placeholders in assets/audio (drop whoosh, landing thud pitched by
mass, perfect ding, falling whistle, game-over walk, tap).

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 0.1.0 | 1 | 2026-10-26 | Greybox + ads wiring (unreleased) |
| 1.0.0 | 1 | 2026-10-27 | First Play Store build: child-directed ads (Families), signed .aab |

# GAME: Noodle Naagin

- Status: in progress (batch 3)
- Package: com.zintara.noodle_naagin
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
snake.io ad genre on a glowing rangoli night floor: your neon noodle eats diyas
and grows; four AI noodles hunt the same diyas; any head that touches a body
pops into diyas for everyone else. Fully offline, all rivals local AI.

## Core loop (30–120 s per life, instant restart)
Joystick sets heading (head always slithers forward) → diyas = +1 segment with
rising pitch → cut off an AI so IT pops → walls and bodies kill → your pop
scatters your whole length as loot.

## Controls (one thumb, portrait)
Dynamic joystick.

## Progression
Best length saved; AI respawn smaller after dying.

## Ad placements
- Rewarded (opt-in only): revive with a 10 s shield, once per run.
- Interstitial: on restart; AdsManager caps apply.
- Banner: none.

## Art style
Flow rangoli-glow floor texture, candy wall ring, five neon noodle colors,
diya cups with flame orbs, pop bursts in the loser's color.

## Sound list
eat, pop, shield, win(reserved), game_over, tap — assets/audio/.

## Store listing
- Title: Noodle Naagin
- Short description: Eat diyas, grow long, make the other noodles pop first.
- Full description: see marketing/noodle-naagin/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: io-snake vs 4 AI, shield revive, child-directed ads |

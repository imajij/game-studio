# GAME: Glow Hunt

- Status: in progress (batch 3)
- Package: com.zintara.glow_hunt
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Top-down neon arena TAG (the Bullet-Echo-style vision-cone hook, fully defanged):
robo-blobs hide in the dark, only your torch cone reveals them, zap them all
before their cones catch you. No weapons, no harm — tagged bots sit down grey.

## Core loop (40–90 s per round, instant next round)
Joystick-sneak the arena → bots appear only inside your light cone → ZAP button
tags the nearest lit bot (pop + confetti) → stand in a bot's cone 0.6 s and YOU
get tagged (3 hearts) → clear all bots = round up: +1 bot, faster.

## Controls (one thumb + one button, portrait)
Dynamic joystick (lower half) to move/face; ZAP button bottom-right.

## Progression
Endless rounds (round N = 3+N bots, speed ramps), best round saved.

## Ad placements
- Rewarded (opt-in only): one heart refill per run.
- Interstitial: on restart after game over; AdsManager caps apply.
- Banner: none.

## Art style
Neon-on-indigo: candy wall ring, purple grid floor, teal player cone vs orange
bot cones, every blob a different candy color. Vibrancy in the dark.

## Sound list
zap, tagged, win, tick, game_over, tap — assets/audio/.

## Store listing
- Title: Glow Hunt
- Short description: They hide in the dark. Your torch finds them. Zap all five before they tag you.
- Full description: see marketing/glow-hunt/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: cone fog-of-war tag loop, child-directed ads |

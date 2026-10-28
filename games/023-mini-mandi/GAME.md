# GAME: Mini Mandi

- Status: in progress (batch 3)
- Package: com.zintara.mini_mandi
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
Arcade-idle market (My-Mini-Mart ad genre): walk your blob around a sunny plot,
harvest veggies into a wobbling head-stack, dump them at the pink-roofed stall,
and the customer queue pays you. Buy pads unlock patches and upgrades.

## Core loop (endless pottering, 30-second satisfaction cycles)
Patch grows veggies → walk over = auto-pick (stack wobbles) → stall = auto-drop
→ customers take 1–3 and pay → stand on a glowing pad ~1 s to buy: PATCH 2/3,
BASKET+, SPEED+.

## Controls (one thumb, portrait)
Dynamic joystick only. Everything else is proximity-automatic.

## Progression
Coins/caps/speed persist; patches re-unlock per session pads (cheap early wins).

## Ad placements
- Rewarded (opt-in only): ×2 pay for 60 s.
- Interstitial: only at purchase moments (natural breaks); AdsManager caps apply.
- Banner: none.

## Art style
Sunny farm plot (Flow ground texture via kit), orange stall with pink roof,
candy customers, veggie-colored crate stack, coin bursts.

## Sound list
pick, sell, unlock, drop, game_over(reserved), tap — assets/audio/.

## Store listing
- Title: Mini Mandi
- Short description: Pick, stack, sell, upgrade. Your little mandi runs on your own two thumbs. Well, one.
- Full description: see marketing/mini-mandi/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-28 | First build: harvest/carry/sell loop, buy pads, x2 ad, child-directed ads |

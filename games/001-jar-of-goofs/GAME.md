# GAME: Jar of Goofs

- Status: prototype (M1 greybox done; M3 art done early — audio still pending)
- Package: com.zintara.jar_of_goofs
- Target audience age: 13+ (general casual audience; not designed for children)
- Privacy policy URL: (required before release)

## Concept
Physics drop-and-merge puzzle: drag to aim, release to drop creatures into a
jar; two identical creatures touching merge into the next tier. Game over if
any settled creature stays above the danger line for 2 seconds.

## Core loop (30–90 s per round, instant restart)
Aim → drop → watch the merge chain → jar fills → risk/reward stacking near the
line → game over → "one more try" tap. Score per merge; higher tiers pay
triangular-number points (tier 11 merge = 55 pts).

## Controls (one thumb, portrait)
- Touch/drag anywhere: pending creature follows finger X (clamped to jar).
- Release: drop. 0.45 s cooldown, then the next creature appears.
- Next-creature preview top right. Game over screen: tap to restart.

## Creature chain (11 tiers, all original characters)
| Tier | Name | Greybox color | Radius px | Merge pts |
|------|------|---------------|-----------|-----------|
| 1 | Bloop (blinking pea) | pea green | 40 | – (drops only) |
| 2 | Sir Crumbs (cookie with monocle) | cookie brown | 49 | 1 |
| 3 | Sock Goblin | dusty purple | 60 | 3 |
| 4 | Toastradamus (fortune-telling toast) | toast tan | 73 | 6 |
| 5 | Croissant Crab | baked orange | 89 | 10 |
| 6 | Lord Pickleton | pickle green | 108 | 15 |
| 7 | Bananarchy (banana with sunglasses) | yellow | 132 | 21 |
| 8 | Fridge Philosopher | ice blue | 160 | 28 |
| 9 | Capybara in a Suit | fur brown | 196 | 36 |
| 10 | Grandpa Galaxy | deep purple | 240 | 45 |
| 11 | The Cosmic Bloop (final form) | cosmic magenta | 292 | 55 |

Only tiers 1–4 appear as drops (uniform random). Two Cosmic Bloops don't
merge (TODO: decide — maybe both vanish for a big bonus).

## Progression
High score (SaveManager `high_score`). Milestone 2 adds the Goofdex
collection as a second axis.

## Physics tuning (knobs live as constants in scripts)
Gravity 3000, bounce 0.2, friction 0.8, merge pop impulse 220/kg, merge pop
scale 0.4→1.0 TRANS_BACK 0.25 s, mass ∝ radius². Retune after phone feel test.

## Ad placements (Milestone 4 — implemented 2026-10-26)
- Rewarded revive (opt-in, IN): green button on game over, once per round;
  clears the top third of the jar and resumes.
- Rewarded "shake the jar" (opt-in, IN): bottom-left button during play
  (visible only when an ad is loaded); kicks all creatures to resettle.
- Rewarded double coins: waits for M2 (no coins yet).
- Interstitial (IN): fires on the restart tap after game over (so it never
  pre-empts the revive offer), gated by AdsManager caps (≥3 rounds played,
  ≥150 s apart).
- Banner: waits for a menu/Goofdex screen. Never during gameplay.

Plugin: poing-studios godot-admob-plugin v5.1.0 (`addons/admob`, Android
AARs for Godot 4.7.2 in `addons/admob/android/bin`). Game autoload
`AdsManager` points at `scripts/admob_adapter.gd`, which extends the shared
studio_core AdsManager and implements its `_plugin_*` stubs; gradle build is
required (debug preset uses it too). App ID: plugin's project-setting default
is Google's TEST app id — set `admob/general/android/app_id` to the real one
(and real unit ids in `ads_config.local.cfg`) at release. Tree pauses during
the shake ad; `rewarded_closed` unpauses. Before release: add the UMP
consent flow (ConsentInformation / ConsentForm, see plugin get-started docs)
ahead of MobileAds.initialize for GDPR regions.

## Art style (Milestone 3 — art DONE 2026-10-26, audio pending)
Flat cartoon sticker style: thick dark-navy outlines, white sticker border,
big expressive eyes, cream-to-peach pastel backdrop, Baloo 2 display font.
All 11 creatures + backdrop + app icon generated with Google Flow (Nano
Banana 2.1, 1024², own prompts/original characters), background-removed and
packed to 512² transparent PNGs (`assets/art/creatures/`). Regeneration
prompts: shared sticker-style preamble + per-character description — see the
Flow project "Jar of Goofs — game art". Sprites draw at 2.35× collision
radius (`Creature.SPRITE_DIAMETER_FACTOR`).

## Sound list (placeholder in M2, final in M3)
| Sound | When | File |
|-------|------|------|
| plop | creature dropped | TBD |
| pop (pitch rises with tier) | merge | TBD |
| uh-oh sting | danger line armed | TBD |
| round-end sting | game over | TBD |
| tap | UI buttons | TBD |

## Milestones
1. **Greybox (done)** — colored circles with tier numbers, physics, drag/drop,
   merging, scoring, danger line (2 s), game over, instant restart, high score.
2. **Discovery & juice** — "NEW GOOF UNLOCKED" first-discovery card with funny
   one-line bios, Goofdex collection screen with silhouettes for undiscovered
   tiers, placeholder sounds, screen shake + particles on merge.
3. **Art & audio pass** — final flat-cartoon art, final sounds + music.
4. **Ads** — via AdsManager as listed above.
5. **Release prep** — docs/release-checklist.md, privacy policy, store listing,
   screenshots, internal test track.

## Store listing (draft at Milestone 5)
- Title:
- Short description (80 chars):
- Full description:

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 0.1.0 | 1 | 2026-10-26 | Milestone 1 greybox (unreleased) |

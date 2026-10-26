# GAME: Jar of Goofs

- Status: prototype (Milestone 1 greybox)
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

## Ad placements (Milestone 4 — none before that)
- Rewarded revive (opt-in): clear the top third of the jar, once per round.
- Rewarded "shake the jar" (opt-in): small physics nudge to settle a stack.
- Rewarded double coins (opt-in, once coins exist with the Goofdex).
- Interstitial: after game over only, via AdsManager caps (never first 2
  rounds, ≥150 s apart).
- Banner: menu / Goofdex screens only. Never during gameplay.

## Art style (Milestone 3)
Simple, bold, flat cartoon; thick outlines, big faces, 2–3 shapes per
creature; must read at 60 px on a small screen. Original characters only.

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

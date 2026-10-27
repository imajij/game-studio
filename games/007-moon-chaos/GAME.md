# GAME: Moon Chaos

- Status: greybox (core loop playable in shapes; art + ads + automation pending)
- Package: com.zintara.moon_chaos
- Target audience age: 13+ (general casual; **see the flag below**)
- Privacy policy URL: (required before release)
- Platform: Android only for v1. Code is kept iOS-clean so iOS is a later
  export rather than a rewrite, but no iOS build is planned.

> **Audience flag (decide before release):** a cheerful moon-sweeping tycoon
> skews younger than the rest of the catalogue. If under-13s are expected to
> play, this must be declared child-directed and Google Play **Families
> policy** applies (certified ad SDKs, child-directed ad settings, stricter
> content). Never misdeclare the audience. Current assumption follows games
> 003-006: declared 13+, with G-rated ad content requested anyway.

## Concept
You are the cleaner on a filthy Moon. Sweep lunar dust, carry it to the depot,
load the shipment rocket, and watch it fly. The cash buys better tools, a
bigger pack, and eventually the collectors and conveyors that sweep for you.
Original setting and characters — no reuse of any existing cleaning game.

## Core loop
Sweep dust (hold to move, auto-sweeps under the tool) → pack fills → carry to
the depot → dump → the rocket loads and launches on a timer or when full →
cash rolls up → spend on upgrades → clear 100% of the zone → unlock the next.

## Controls (one thumb, portrait)
Dynamic virtual joystick anywhere in the lower-left; the base appears under
the thumb instead of at a fixed spot. One big contextual action button in the
lower right: **DUMP** at the depot, **LAUNCH** when the rocket has a payload.
Pinch to zoom between 8 m and 24 m. Fixed camera angle, no rotation, no bob.

## Zones (v1)
| # | Zone | Grid | Unlock | Payout | Introduces |
|---|------|------|--------|--------|------------|
| 1 | Landing Pad | 24x32 | – | 1.0x | the loop itself |
| 2 | Crater Rim | 32x40 | $400 | 1.15x | Glint dust (2.5x value) |
| 3 | Solar Field | 40x48 | $2,200 | 1.35x | static-cling hazard *(not built yet)* |
| 4 | Mining Shelf | 48x56 | $9,000 | 1.6x | collectors |
| 5 | Dark Side | 56x64 | $32,000 | 2.0x | mergers |

Zones 1-3 are meant to take under 10 minutes combined — unverified until it
has been played on a phone.

## Progression
Tools: Toothbrush → Hand Broom → Vacuum Pack → Roller Rig (each widens the
sweep radius and speed). Upgrade tracks: carry capacity, move speed, depot
capacity, rocket payout. Soft currency is cash from shipments; moon crystals
are the premium currency, found rarely while sweeping and from rewarded ads.

**No IAP in v1** — crystals are earnable only. `profile.entitlements` exists
in the save so `ads_removed` can be added later without a save migration, but
no billing SDK is included.

## Ad placements (wired through the shared AdsManager, test IDs until release)
- Rewarded, opt-in only: 2x shipment payout, instant rocket, speed boost.
- Interstitial: **zone completion only**, never during sweeping. The shared
  AdsManager caps apply (not in the first 3 rounds, max 1 per ~150 s).
- Banner: not used; it would crowd the HUD.
- The game plays fine with no ad plugin installed — every call is a safe no-op.

## Architecture
Simulation (`scripts/sim/`) is pure GDScript: RefCounted, no Node, no
autoloads, deterministic and serialisable. The view (`scripts/view/`,
`scripts/ui/`) renders it and owns every autoload call. The moon surface is
flat, so the sim stays planar in `Vector2` grid coordinates and only the view
maps to `Vector3(x, 0, y)` — the 3D decision costs the sim nothing.

All tunable numbers live in `data/balance.json`, validated by name on load.
Saves store only `def_id`s and upgrade levels, so retuning that file reaches
existing saves without a migration.

`tools/test.sh moon-chaos` runs 222 headless checks across 6 suites, including
dust conservation through the automation network and the offline-earnings cap.

## Art style (pending)
Greybox is shapes only: white-blue clean floor, dark grey dust layer rendered
as a single alpha-masked plane (no shader), capsule player, box depot,
cylinder rocket. Real art comes only after the loop is confirmed fun.

## Sounds (pending)
Quiet ambient bed with a mute toggle, sweep hiss, dump thud, rocket countdown
and launch roar, cash counter ticks.

## Known gaps before this is a real game
- Automation (collectors/conveyors/mergers) is simulated and tested but has no
  build UI or 3D representation yet.
- The zone-3 static-cling hazard is supported by `DustGrid.add_dust()` but not
  yet driven by anything.
- Daily contract is implemented and tested in sim, not surfaced in the UI.
- The upgrade panel overlaps the playfield; placement needs a phone test.
- No audio, no haptic tuning, no art.

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 0.1.0 | 1 | 2026-10-27 | Sim layer + 3D greybox of the core loop (unreleased) |

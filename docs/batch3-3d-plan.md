# Batch 3 — fifteen 3D "ad-genre" games (018–032)

Planned 2026-10-28. Goal: the hyper-casual 3D genres that dominate Instagram/Reels
ads — shelter-upgrade tycoons, crowd runners, arena shooters, subway-style runners,
pull-the-pin, hole.io, arcade-idle — every one **completely single player, fully
offline** (all "opponents" are local AI), original IP, and **Families-safe**
(the whole catalogue is declared Everyone incl. under-13; nothing here may break
that — no guns, no blood, no harm depiction; zapping/tagging/popping only).

## The 15

| # | Slug | Name | Ad genre it rides | Core loop (30–90 s) | Rewarded ad |
|---|------|------|-------------------|---------------------|-------------|
| 018 | storm-shelter | Storm Shelter | "upgrade your shelter!" bunker tycoon | Dig rooms downward, assign worker blobs, stock supplies, reinforce the hatch before each timed MONSOON MEGA-STORM; survive = loot + deeper floors | instant supply crate |
| 019 | glow-hunt | Glow Hunt | Bullet Echo-style top-down arena | Top-down 3D arena in darkness; your torch cone vs 5 AI robo-blobs; zap-tag them with a light pulse before they tag you; last one glowing wins; fog-of-war stealth is the hook | second life |
| 020 | gravity-gully | Gravity Gully | Subway Surfers endless runner (distinct from 011 via gravity flip) | 3-lane 3D runner where swipe-up FLIPS you to run on the ceiling; trains/arches force flips; coins + daily best | revive |
| 021 | mob-mela | Mob Mela | Count Masters crowd runner | Run through ×2/+10 gates growing a blob crowd, lose blobs to obstacles, final push-battle vs an AI crowd | double crowd at start |
| 022 | pin-panic | Pin Panic | pull-the-pin puzzles | 3D vats: pull pins in the right order to route water/gold to the pot and keep the gunk out; 60+ generated levels | skip level |
| 023 | mini-mandi | Mini Mandi | arcade-idle (My Mini Mart) | Joystick-walk, harvest veggies, carry wobbling stacks to stalls, serve customer blobs, unlock stations/helpers | speed boost |
| 024 | nom-hole | Nom Hole | hole.io | You are a hole in a tiny 3D town; swallow cones→carts→buses as you grow; 90-second score run vs 2 AI holes | +30 seconds |
| 025 | horn-ok-jam | Horn OK Jam | parking/traffic jam | Tap vehicles to drive them out of a gridlocked 3D bazaar lot; limited taps; honking chaos | +3 taps |
| 026 | tile-toofan | Tile Toofan | Shortcut Run / stack-floor | Grab floor tiles while running, auto-spend them to bridge gaps; risk long shortcuts over water; finish-line multiplier | golden tile pack |
| 027 | laddu-giant | Laddu Giant | Giant Rush / Fat Pusher size-runner | Eat laddus to grow HUGE, squeeze through gates that shrink you, end-wall smash scaled to your size | start at 2× size |
| 028 | noodle-naagin | Noodle Naagin | snake.io | 3D glowing noodle grows eating diyas; 4 AI noodles to outlive; walls + self = pop | shield 10 s |
| 029 | rang-tubes | Rang Tubes 3D | ball-sort puzzle | Sort colored balls between 3D glass tubes; generated levels, undo tokens | extra undo pack |
| 030 | toda-todi | Toda Todi | cannon demolition / Knock Balls | Flick a cannon to topple block forts; star rating by shots left; pure physics joy, blocks only | +3 cannonballs |
| 031 | dhulai-deluxe | Dhulai Deluxe | power-wash / deep-clean ASMR | Spray-wash filthy 3D objects (auto-rickshaw, statue, water tank) one panel at a time; % clean meter; (distinct from Moon Chaos: aim-spray per object, not walk-sweep tycoon) | instant foam blast |
| 032 | tempo-overload | Tempo Overload | overloaded-cargo driving | Tilt-steer a tempo with a swaying cargo stack down a hill course; deliver what survives; stack higher = pay higher | cargo straps (stability) |

Naming/IP: genres are not protectable; names, characters, art and levels are all
original. Nothing references Bullet Echo / Subway Surfers / any real game or brand.

**Distinctness audit vs existing 17** (Play repetitive-content policy): every entry
has a unique core verb. The two near-neighbours are flagged and differentiated:
020 vs 011 (2D swipe-lanes vs 3D gravity-flip ceiling-running), 031 vs 007
(walk-and-sweep tycoon vs aim-spray object detailing). 029 vs 006 share the word
"sort" only (tube puzzle vs swipe classification).

## Families / IARC line (applies to every game)

- Declared Everyone incl. under-13, child-directed ads (TFCD + G) — same as fleet.
- 019 Glow Hunt is the sensitive one: it is TAG with light pulses between robot
  blobs — no weapons, no hit reactions beyond a "boop + sit down" pop. IARC
  violence answers stay No. If it ever feels shooter-y in playtest, it ships as
  pure hide-and-seek.
- 030 topples blocks, 024 swallows objects (empty vehicles, no people), 021's
  push-battle is sumo-style shoving of smiling blobs.

## Tech foundation (build once, reuse 15×)

- Godot 4.7 Mobile renderer, portrait. Budget: 60 fps on 2–3 GB phones —
  unshaded/vertex-lit flat-color materials, ONE directional light, no real-time
  shadows (blob shadow decals), pooled objects, < 60 draw calls.
- **Look**: low-poly primitive kits (Box/Cylinder/Capsule/Prism meshes + a shared
  24-color palette material set) — the crossy-road/kenney aesthetic, built
  in-engine, zero texture downloads, keeps .aabs ~36 MB.
- New per-game-template pieces (developed in 018, then copied forward; shared/
  stays untouched so released games are unaffected):
  - `camera_rig.gd` — smooth-follow ortho-ish 3D cam presets (top-down, chase, side)
  - `joystick.gd` — ported from Moon Chaos (dynamic thumb-stick, press anywhere)
  - `palette.gd` — material cache for the 24 flat colors
  - `blobby.tscn` — capsule character with face, squash-stretch, pooled
- Sim-vs-view split (Moon Chaos pattern, headless-testable) only where state is
  deep: 018, 023, 032. The pure-reflex games skip it.
- SFX: extend sfx_pack with 15 new profiles. Icons/feature graphics: Flow sticker
  pass (project "Zintara batch3 art"), screenshots = real gameplay via shot_runner
  (works for 3D — proven on Moon Chaos).

## Build order (tech clustering, 3 waves of 5)

1. **Movers**: 020 runner → 021 crowd → 026 tiles → 027 size → 028 snake
   (shared: forward-track runner core + joystick/swipe input)
2. **Arenas & tycoons**: 019 arena → 024 hole → 023 mandi → 018 shelter → 032 truck
   (shared: top-down cam + joystick + AI wander)
3. **Puzzle/physics**: 022 pins → 025 jam → 029 tubes → 030 cannon → 031 wash
   (shared: level-select scaffold + physics scenes)

Per game: greybox loop → check.sh → juice (squash, particles, haptics) → SFX →
GAME.md → commit `[slug]`. Then the proven release pipeline (AdMob app+units →
signed .aab → marketing → Play driver → submit).

## Play Console rollout vs the weekly limit (~15 creations/week)

- **Week of Nov 3**: create Bazaar Tower Defense + Meme Reset 2014 (owed from
  batch 2) + up to ~13 batch-3 apps as they're ready.
- **Week of Nov 10**: remaining batch-3 apps.
- AdMob app creation has shown no such limit; do all 15 whenever builds are ready.

## Risks, stated plainly

- **Account pace**: this takes the catalogue to 32 apps in ~3 weeks on a new
  personal account. Each game having a genuinely distinct mechanic + original art
  is the defense, and the weekly cap forces spacing — but if Google ever flags
  the account for volume, pausing new submissions and doubling down on the best
  performers is the fallback. Worth deciding consciously before wave 3.
- **Quality bar**: ad-genre games live on juice and tuning. 15 games at closed-test
  quality is doable with the primitive-kit look; production pushes should go only
  to the ones testers actually retain (D1 ≥ ~25% rule from CLAUDE.md).
- **3D perf on low-end**: validate 020 (the busiest scene) on the tablet before
  mass-producing the runner core.

## Status

| # | Game | Status |
|---|------|--------|
| 018–032 | all fifteen | planned — not started |

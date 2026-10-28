# game-studio

Solo-dev monorepo of small, ad-supported casual mobile games for Google Play, built with
**Godot 4 / GDScript**. One self-contained Godot project per game under `games/`.
All conventions live in [CLAUDE.md](CLAUDE.md) — read that first.

## Games

| # | Game | Slug | Status | Version | Play Store | Notes |
|---|------|------|--------|---------|------------|-------|
| 001 | Jar of Goofs | jar-of-goofs | closed test (live) | 1.0.0 | – | drop-and-merge puzzle; art+ads+Goofdex in |
| 002 | Stack-a-Freak | stack-a-freak | closed test (live) | 1.0.0 | – | crane tower stacker; art+ads in |
| 003 | Moth to the Lamp | moth-to-the-lamp | closed test (live) | 1.0.0 | – | endless flutter climber; art+ads in |
| 004 | Snack Slasher | snack-slasher | closed test (live) | 1.0.0 | – | swipe slicer; art+ads in |
| 005 | Gobble Gus | gobble-gus | closed test (live) | 1.0.0 | – | catch/dodge feeder; art+ads in |
| 006 | Sort the Horde | sort-the-horde | in review (closed test) | 1.0.0 | – | swipe sorter; art+ads in |
| 007 | Moon Chaos | moon-chaos | closed test (live) | 1.0.0 | – | 3D lunar cleaning tycoon; sim+tests+greybox in |
| 008 | Steal a Jugaad | steal-a-jugaad | closed test (live) | 1.0.0 | – | collect/raid tycoon vs AI guard; vector art |
| 009 | 67 Reflex | reflex-67 | closed test (live) | 1.0.0 | – | precision beat taps on 6 & 7; daily best |
| 010 | Merge Mohalla | merge-mohalla | closed test (live) | 1.0.0 | – | physics drop-merge, 10 desi tiers |
| 011 | Escape the Monsoon | escape-the-monsoon | closed test (live) | 1.0.0 | – | 3-lane runner, rotating wave themes |
| 012 | Aura Farming Idle | aura-farming | closed test (live) | 1.0.0 | – | tap/idle clicker, respect prestige |
| 013 | Rank the Rot | rank-the-rot | closed test (live) | 1.0.0 | – | swipe tier-list vs daily panel verdict |
| 014 | Brainrot Fusion Lab | fusion-lab | closed test (live) | 1.0.0 | – | fuse essences, auto-names, AI battles |
| 015 | Guess the Sound or Get Yeeted | guess-the-sound | closed test (live) | 1.0.0 | – | original synth audio quiz, elimination |
| 016 | Bazaar Tower Defense | bazaar-defense | release-ready (Play slot ~Nov 3) | 1.0.0 | – | 3 evolving units, endless waves |
| 017 | Meme Reset 2014 | meme-reset | release-ready (Play slot ~Nov 3) | 1.0.0 | – | CRT brick-smasher, era-card collection |

Statuses: `prototype` → `internal test` → `closed test` → `production` → `killed`.
Full metrics live in [docs/games-log.md](docs/games-log.md).

## Quick commands

```sh
tools/new-game.sh <slug> "Display Name"   # create games/NNN-<slug> from _template
tools/sync-shared.sh                      # push shared/addons/studio_core into every game
tools/check.sh <slug>|all                 # headless import + script error check
tools/test.sh <slug>|all                  # headless unit tests (games that have tests/)
tools/build-android.sh <slug>             # release .aab → builds/<slug>-<version>.aab
```

## Setup on a fresh machine

1. Install Godot 4 (standard build) to `/Applications/Godot.app`, Homebrew `git-lfs` and
   `openjdk@17`, and Android Studio (for the Android SDK).
2. `git lfs install` once, then clone.
3. Fill in `studio.cfg` (studio name, package prefix) if not already done.
4. In Godot: Editor Settings → Export → Android → set SDK + JDK paths.
5. Keystores live outside the repo in `~/keystores/` — restore from backup, never commit.

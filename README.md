# game-studio

Solo-dev monorepo of small, ad-supported casual mobile games for Google Play, built with
**Godot 4 / GDScript**. One self-contained Godot project per game under `games/`.
All conventions live in [CLAUDE.md](CLAUDE.md) — read that first.

## Games

| # | Game | Slug | Status | Version | Play Store | Notes |
|---|------|------|--------|---------|------------|-------|
| 001 | Jar of Goofs | jar-of-goofs | prototype | 0.1.0 | – | drop-and-merge puzzle; M1 greybox done |

Statuses: `prototype` → `internal test` → `closed test` → `production` → `killed`.
Full metrics live in [docs/games-log.md](docs/games-log.md).

## Quick commands

```sh
tools/new-game.sh <slug> "Display Name"   # create games/NNN-<slug> from _template
tools/sync-shared.sh                      # push shared/addons/studio_core into every game
tools/check.sh <slug>|all                 # headless import + script error check
tools/build-android.sh <slug>             # release .aab → builds/<slug>-<version>.aab
```

## Setup on a fresh machine

1. Install Godot 4 (standard build) to `/Applications/Godot.app`, Homebrew `git-lfs` and
   `openjdk@17`, and Android Studio (for the Android SDK).
2. `git lfs install` once, then clone.
3. Fill in `studio.cfg` (studio name, package prefix) if not already done.
4. In Godot: Editor Settings → Export → Android → set SDK + JDK paths.
5. Keystores live outside the repo in `~/keystores/` — restore from backup, never commit.

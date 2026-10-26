# CLAUDE.md — Game Studio Monorepo

You are my game development partner. I am a solo developer building small, ad-supported
casual/"brainrot"-style mobile games for Google Play using Godot 4. All games live in this
single repository and are tracked on GitHub. Read this whole file before doing anything.

## Studio identity (fill these in)
- Developer / studio name: <YOUR STUDIO NAME>          <!-- also set in studio.cfg -->
- Android package prefix: com.<yourstudio>   (each game: com.<yourstudio>.<gameslug>)
- GitHub username: imajij
- Repo name: game-studio (private)
- Machine: MacBook Pro, Apple Silicon (M5 Pro), macOS, zsh shell
- Primary market assumption: India + other Tier-2/3 markets, low/mid-range Android phones

Note: tools/new-game.sh reads STUDIO_NAME and PACKAGE_PREFIX from studio.cfg at the repo
root and refuses to run until they are filled in.

## Tech stack
- Engine: Godot 4 (latest stable, standard GDScript build, NOT .NET/C#)
- Language: GDScript only, with static typing wherever possible
- Godot binary: /Applications/Godot.app/Contents/MacOS/Godot
  (create a zsh alias `godot` pointing to it if missing)
- Android: OpenJDK 17 (Homebrew), Android SDK via Android Studio
- Export format for Play Store: Android App Bundle (.aab)
- Ads: Google AdMob through a maintained Godot 4 AdMob plugin (verify the plugin's
  current recommended version and install steps from its official repo before using it)
- Version control: git + GitHub CLI (`gh`), Git LFS for large binary assets

## Repository structure (keep exactly this layout)
game-studio/
├── CLAUDE.md                  # this file
├── README.md                  # overview + table of all games and their status
├── .gitignore
├── .gitattributes             # Git LFS rules
├── studio.cfg                 # studio name + package prefix, read by tools/
├── games/
│   ├── _template/             # base Godot project every new game is copied from
│   └── <NNN-gameslug>/        # one self-contained Godot project per game, e.g. 001-skibidi-dash
│       ├── project.godot
│       ├── scenes/
│       ├── scripts/
│       ├── assets/{art,audio,fonts}/
│       ├── addons/            # synced copy of shared addons + game-specific plugins
│       ├── export_presets.cfg
│       └── GAME.md            # design doc, ad placements, version history, store listing text
├── shared/
│   └── addons/studio_core/    # reusable code: AdsManager, SaveManager, Analytics, AudioManager,
│                              # SceneTransition, Settings, haptics, debug overlay
├── tools/
│   ├── new-game.sh            # copies _template → games/NNN-slug, sets name + package id
│   ├── sync-shared.sh         # copies shared/addons into every game's addons/ folder
│   ├── build-android.sh       # headless export of a given game to .aab into builds/
│   └── check.sh               # headless import + script error check for one or all games
├── docs/
│   ├── games-log.md           # tracking table: game, status, release date, installs, D1/D7, ARPDAU
│   ├── release-checklist.md
│   └── play-policy-notes.md
├── marketing/<gameslug>/      # icons, feature graphics, screenshots, short-video clips, store text
└── builds/                    # local build output — gitignored

Rules:
- Every game is its own Godot project (its own project.godot). Never put two games in one project.
- Game folders are numbered in creation order: 001-, 002-, 003-...
- Shared code is edited ONLY in shared/addons/studio_core, then pushed to games with
  tools/sync-shared.sh. Never edit the synced copy inside a game directly.
- Keep README.md's games table and docs/games-log.md updated whenever a game is created,
  released, updated, or killed.

## Git & GitHub rules
- Remote: private GitHub repo `game-studio` under my account, created with `gh repo create`.
- Branch: work on `main` for small changes; use a branch `game/<slug>` for a new game's
  first build, then merge.
- Commit messages: `[<gameslug>] short description` for game work,
  `[shared] ...`, `[tools] ...`, `[docs] ...`, `[repo] ...` for everything else.
- Commit after every meaningful working step (a feature works, a bug is fixed). Small commits.
- Push to GitHub at the end of every working session and after every release.
- Tag each Play Store release: `<gameslug>/v<versionName>` (e.g. skibidi-dash/v1.0.2).
- Use Git LFS for: *.png *.jpg *.jpeg *.webp *.psd *.kra *.wav *.ogg *.mp3 *.ttf *.otf *.mp4 *.blend
- Before each commit, run `git status` and confirm no secrets or build outputs are staged.

## .gitignore must include
- .godot/ (in every game folder), *.tmp, builds/, android/build/
- export_credentials.cfg (Godot stores keystore passwords here — NEVER commit)
- *.keystore, *.jks, *.aab, *.apk, .env, any google-services or service-account JSON
- .DS_Store
- Note: in Godot 4, the *.import files next to assets SHOULD be committed.

## SECRETS — absolute rules
- The Android upload keystore lives OUTSIDE the repo at ~/keystores/<gameslug>-upload.keystore
  (or one shared studio upload key at ~/keystores/studio-upload.keystore).
- Never print, commit, or paste keystore passwords, AdMob account credentials, or API keys
  into any tracked file. If you find a secret in a tracked file, stop and tell me.
- Remind me to back up ~/keystores to a safe place (losing the upload key is painful).
- Real AdMob app IDs / ad unit IDs go in a gitignored per-game config file
  (games/<slug>/ads_config.local.cfg) with a committed ads_config.example.cfg template.
- During development ALWAYS use Google's official AdMob test ad unit IDs. Only switch to
  real IDs in release builds. Never tap real ads on my own devices.

## Game design defaults (for every game unless I say otherwise)
- Portrait orientation, one-thumb controls, playable within 3 seconds of launch.
- Core loop of 30–90 seconds per round; instant restart; clear sense of progress
  (levels, unlocks, collection, or high score).
- ORIGINAL characters and names only. Do not use characters, names, or art from existing
  memes, games, or franchises that someone else may own. Parody the vibe, not the IP.
- Target 60 fps on low-end Android (2–3 GB RAM). Use the Mobile or Compatibility renderer,
  compressed textures, pooled objects, no heavy shaders.
- Keep the .aab small (aim under 40 MB). Prefer .ogg audio, compressed/atlased images.
- Save progress locally (SaveManager). No login, no network required to play.

## Ad monetization rules
- Rewarded video is the primary format: opt-in only (revive, double coins, unlock skin).
- Interstitials: never in the first 2 rounds of a new player's first session, never
  mid-gameplay, at most one per ~2–3 minutes of play, shown only at natural breaks.
- Banner: optional, only on menus/game-over screens, never covering controls.
- All ad calls go through AdsManager (shared/addons/studio_core), which handles loading,
  frequency capping, test vs real IDs, and failures (game must work fine if ads fail).
- Ask me before adding any additional ad network or mediation.

## Play Store policy guardrails
- Every game needs a privacy policy URL (ads collect device identifiers). Help me draft it.
- Help me fill the Data safety form accurately based on the SDKs actually included.
- Target audience: ask me per game. If the game could appeal to children under 13, flag it:
  Google Play Families policy then applies (child-directed ad settings, certified ad SDKs,
  stricter content rules). Never misdeclare the audience.
- Use the target API level Google Play currently requires — check this before every release.
- Avoid near-duplicate games: each game must have a distinct core mechanic, art, and
  listing, to stay clear of Google Play's spam / repetitive-content policy.
- Store listing: no misleading screenshots, no keyword stuffing, no fake "#1" claims.

## How you should work
1. Before writing code, briefly state your plan (files you'll create/change) for anything
   larger than a small fix.
2. After changes, run tools/check.sh for the affected game (headless Godot import) and fix
   all script errors and warnings before telling me it's done.
3. Tell me exactly what to test manually on my Android phone and what I should see.
4. Ask before: installing anything system-wide, deleting files or games, force-pushing,
   rewriting git history, changing shared/ code that affects released games, or spending money.
5. Never use `sudo` unless I explicitly approve it.
6. Keep GDScript clean: typed variables, signals over polling, one script per responsibility,
   short comments explaining "why", constants at top, no magic numbers.
7. When something is beyond what you can do (Play Console clicks, AdMob dashboard setup,
   phone testing, creating keystores with passwords), give me clear step-by-step
   instructions instead of guessing.
8. If you're unsure about a current Godot, plugin, AdMob, or Play Store detail, say so and
   check official docs rather than relying on memory.

## Creating a new game (standard procedure)
1. Ask me for: working title, one-sentence concept, core mechanic, target audience age.
2. Run tools/new-game.sh to create games/NNN-slug from _template, set display name and
   package id com.<yourstudio>.<slug>, versionCode 1, versionName 0.1.0.
3. Create GAME.md with: concept, core loop, controls, progression, ad placements,
   art style, sound list, and an empty version history table.
4. Build a playable greybox of the core loop FIRST (shapes, no art). Commit.
5. Only after I confirm it's fun on my phone: add art, juice (particles, screen shake,
   sounds, haptics), progression, then ads.
6. Add the game to README.md and docs/games-log.md with status "prototype".

## Release procedure
1. Walk through docs/release-checklist.md.
2. Bump versionCode (+1) and versionName in export_presets.cfg; update GAME.md history.
3. Switch AdsManager to real IDs for the release build only; confirm test IDs remain the
   default for debug builds.
4. Run tools/build-android.sh <slug> → builds/<slug>-<versionName>.aab
5. Commit, tag `<slug>/v<versionName>`, push with tags.
6. Give me the Play Console upload steps and release notes text.
7. Update games-log.md status (internal test / closed test / production).

## Tracking performance
- After each game launches, I'll paste numbers from Play Console and AdMob. Record them in
  docs/games-log.md: installs, DAU, D1/D7 retention, eCPM, ARPDAU, monthly revenue.
- Help me decide per game: iterate, double down (update + promote), or kill.
  Rough guide: D1 retention under ~25% after real players → usually rework or kill.

# Batch 4 — productive / utility apps (non-game expansion)

Planned 2026-10-28 on Ajij's direction: "create productive apps, apps that pull
traction like religious calendars, calorie trackers… check my github, many apps
previously built but never published — add them too."

## Why this genre is a good call (revenue math)

- Utility apps retain: a calendar or tracker opened daily beats a hyper-casual's
  D7 collapse.
- **Not child-directed** → declared 13+/18+ → **personalized ads allowed** →
  eCPMs typically 2–3× what the TFCD games can ever earn per impression.
- Religious/festival calendars are a proven high-traction Play category in India
  with evergreen search volume.

## Roster

### Revivals (found on github.com/imajij, built but never published)

| App | Repo | What it is | State | Verdict |
|-----|------|-----------|-------|---------|
| LifeTracker | `life_tracker` (Flutter) | Calorie + workout + water + sleep + study + habit tracker; local-first (Drift/SQLite); optional bring-your-own Gemini key with offline fallback | MVP complete per IMPLEMENTATION_NOTES; AI call itself stubbed (fallback works) | **Publish — flagship**. This IS the calorie tracker. |
| Smaran | `Smaran` (Flutter) | Offline family calendar for parents/elderly: big text, reminders, categories, photos, backup | Feature-complete, small, 100% offline | **Publish** + use as the fork-base below. |
| ikiru | `zest_app_v1` (Flutter) | Real-life side-quests: daily challenges, XP, map events, photo proof, social feed | Depends on auth + Render backend (`ikiru-backend…onrender.com`) likely asleep | **Defer** — needs backend revival or offline rework. |
| Roamly | `MVP_Roamly` (Flutter) | Travel MVP | Needs its Go backend | Skip for now. |

### New build

| App | Base | Concept |
|-----|------|---------|
| Tyohar Calendar (working title) | fork of Smaran | Religious/festival calendar: preloaded Hindu festival + vrat/panchang dates (2026–2028), reminder defaults, festival detail notes, Smaran's elderly-friendly UI. Offline. Original data tables compiled by us. |

## Per-app work items (the Flutter pipeline, parallel to the Godot one)

1. Package rename `com.example.*` → `com.zintara.<app>` (safe — never published).
2. Branding: Flow icon pass + Play listing assets (same compositor as games).
3. Signing: studio upload keystore via `android/key.properties` (NOT committed)
   + `signingConfigs.release`; same `~/keystores/studio-upload.keystore`.
4. AdMob (google_mobile_ads): light touch — banner on secondary screens +
   occasional interstitial; **UMP consent flow required** because these serve
   personalized ads (EEA/UK); AdMob apps + units on ajijuttam2006.
   Ship v1.0 working first; ads may land in v1.1 if integration drags.
5. Play declarations differ from the games: audience 13+ (NOT child-directed),
   IARC utility questionnaire, Data safety: all data on-device only ("no data
   collected/shared") — keep LifeTracker's Gemini strictly bring-your-own-key
   so no health data ever leaves the device; category Health & Fitness
   (LifeTracker) / Productivity (Smaran) / Lifestyle or Events (Tyohar).
6. Same closed-testing path: Zintara testers list, 14-day clock, same
   tools/play-automation scripts.

## Publish queue vs the weekly creation limit (~15/window)

- **Nov-3 window**: bazaar-defense, meme-reset (owed) + LifeTracker, Smaran,
  Tyohar Calendar (3 utility slots) + ~10 of games 018–027.
- **Nov-10 window**: remaining games 028–032 (+ ikiru if its backend gets revived).

## Status

| App | Status |
|-----|--------|
| LifeTracker | RELEASE-READY — com.zintara.life_tracker, signed 1.0.0 .aab (62 MB) in game-studio/builds/, emulator-verified end-to-end (onboarding→dashboard→nutrition→habits), Flow icon + listing + 4 real screenshots. Known cosmetic bug: dashboard greets "User" instead of saved name. |
| Smaran | RELEASE-READY — com.zintara.smaran, signed 1.0.0 .aab (55 MB), emulator-verified (calendar→add event w/ reminder+color→agenda), Flow icon + listing + 4 real screenshots. |
| Tyohar Calendar | not started (fork of Smaran, next) |
| ikiru | deferred — backend |

2026-10-28 (later): Flutter pipeline proven. Gotchas: flutter config --jdk-dir
/opt/homebrew/opt/openjdk@17 (Java 25 breaks Gradle 8.14); pin ndkVersion
"28.2.13676358"; `flutter build appbundle` wrapper fails on missing
cmdline-tools — run `./gradlew bundleRelease` in android/ instead (works, signs
correctly); AVD "Medium_Phone_API_37.0" exists for emulator screenshots via adb.
Both apps queued for the Nov-3 Play window alongside the games.

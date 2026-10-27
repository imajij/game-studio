# GAME: Guess the Sound or Get Yeeted

- Status: in review (closed test)
- Package: com.zintara.guess_the_sound
- Target audience: Everyone incl. under-13 (declared child-directed, Families policy)
- Privacy policy URL: https://imajij.github.io/privacy.html

## Concept
A mystery sound plays; four names appear; pick fast or your listener blob gets
physically yeeted off the screen. All 10 quiz sounds are ORIGINAL synth creations
(Wet Slap, Angry Kettle, Sad Horn, Robot Burp, Tiny Violin, Haunted Door…) —
nothing licensed, nothing sampled.

## Core loop (~20 s per round, instant restart)
Sound plays → 4 buttons → timer bar shrinks (6 s, tightening to 2.8 s as your
streak grows, tick-tick warning at 3) → wrong or slow = YEET (blob spins off,
correct answer revealed) → streak = score.

## Controls (one thumb, portrait)
Tap an answer; tap "again" to replay the sound.

## Progression
Streak + all-time best. Timer pressure ramps with streak.

## Ad placements
- Rewarded (opt-in only): one SECOND CHANCE per run (continue the streak).
- Interstitial: on restart after yeet; AdsManager frequency caps apply.
- Banner: none.

## Art style
Indigo stage, big listener blob with one giant ear, animated sound-wave arcs,
physics-flavored yeet arc with spin on loss.

## Sound list
| Sound | When | File |
|-------|------|------|
| q_* (10) | quiz prompts | assets/audio/q_*.wav |
| correct / wrong | answer feedback | assets/audio/correct.wav, wrong.wav |
| yeet | elimination | assets/audio/yeet.wav |
| tick | last 3 seconds | assets/audio/tick.wav |
| game_over | (reserved) | assets/audio/game_over.wav |
| tap | ui | assets/audio/tap.wav |

## Store listing
- Title: Guess the Sound or Get Yeeted
- Short description (80 chars): A sound plays. Four names. Three seconds. Guess wrong and physics handles you.
- Full description: see marketing/guess-the-sound/listing.md

## Version history
| versionName | versionCode | Date | Notes |
|-------------|-------------|------|-------|
| 1.0.0 | 1 | 2026-10-27 | First Play Store build (closed test): 10 original quiz sounds, streak loop, second chance, child-directed ads |

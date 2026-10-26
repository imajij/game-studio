# studio_core

Shared autoload singletons for every game. **Edit only here**, then run
`tools/sync-shared.sh` to push into each game's `addons/` folder. The
template's `project.godot` already registers all of them as autoloads.

Load order matters and is set in `project.godot`:
`SaveManager → Settings → Analytics → AudioManager → Haptics → AdsManager → SceneTransition → DebugOverlay`

| Singleton | Use |
|-----------|-----|
| `SaveManager` | `get_value(key, default)` / `set_value(key, value)` — JSON in `user://`, saves immediately |
| `Settings` | `music_on` / `sfx_on` / `haptics_on` bools; emits `setting_changed` |
| `Analytics` | `log_event(name, props)` — local counters only, prints in debug |
| `AudioManager` | `play_music(stream)`, `play_sfx(stream, pitch_jitter)`, `stop_music()` |
| `Haptics` | `light()` / `medium()` / `heavy()` — gated by setting, no-op off-mobile |
| `AdsManager` | `round_finished()`, `maybe_show_interstitial()`, `is_rewarded_ready()`, `show_rewarded(type)`; signals `rewarded_earned`, `rewarded_unavailable`, `interstitial_closed`. Test IDs in debug; real IDs from `ads_config.local.cfg` in release. Plugin adapter stubs inside — wire the AdMob plugin per game. |
| `SceneTransition` | `change_to("res://scenes/x.tscn")` — fade to black, input-blocked |
| `DebugOverlay` | FPS/memory label, debug builds only, no API |

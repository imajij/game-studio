extends Node
## All ad calls go through here. The game must play fine when ads are
## unavailable, so every public call is safe with NO AdMob plugin installed.
##
## Debug builds ALWAYS use Google's official test ad units. Real IDs are read
## from res://ads_config.local.cfg (gitignored; see ads_config.example.cfg)
## and only used in release builds.
##
## Wiring a real plugin: install the AdMob plugin into the game's addons/
## folder (check the plugin's official repo for current version + setup),
## then fill in the "_plugin_*" adapter functions below. Game code and the
## frequency-cap rules above them never change.

signal interstitial_closed
signal rewarded_earned(reward_type: String)
## Fired when a rewarded ad closes, with or without a reward (unpause here).
signal rewarded_closed
signal rewarded_unavailable

## Google's official Android TEST ad units — safe to show and tap.
## Verify against current AdMob docs when wiring the plugin.
const TEST_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const TEST_BANNER_ID: String = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"

const CONFIG_PATH: String = "res://ads_config.local.cfg"
const CONFIG_SECTION: String = "admob"

## Policy guardrails (CLAUDE.md): no interstitials in a new player's first
## rounds, at most one per ~2–3 minutes, natural breaks only.
const MIN_ROUNDS_BEFORE_INTERSTITIAL: int = 3
const MIN_SECONDS_BETWEEN_INTERSTITIALS: float = 150.0

var _ids: Dictionary = {}
var _rounds_played: int = 0
var _last_interstitial_at: float = -INF

func _ready() -> void:
	_load_ids()


## Call once at the end of every round, win or lose.
func round_finished() -> void:
	_rounds_played += 1


## Call at natural breaks only (game over / level complete screen). Shows an
## interstitial if the frequency rules allow it; returns true if one showed.
func maybe_show_interstitial() -> bool:
	if _rounds_played < MIN_ROUNDS_BEFORE_INTERSTITIAL:
		return false
	var now := _now_sec()
	if now - _last_interstitial_at < MIN_SECONDS_BETWEEN_INTERSTITIALS:
		return false
	if not _plugin_interstitial_ready():
		return false
	_last_interstitial_at = now
	Analytics.log_event("ad_interstitial_shown")
	_plugin_show_interstitial()
	return true


## Use to show/hide the opt-in reward button.
func is_rewarded_ready() -> bool:
	return _plugin_rewarded_ready()


## Only call from an explicit opt-in button the player tapped.
## Emits rewarded_earned(reward_type) on success, rewarded_unavailable if not.
func show_rewarded(reward_type: String) -> void:
	if not _plugin_rewarded_ready():
		rewarded_unavailable.emit()
		return
	Analytics.log_event("ad_rewarded_shown", {"type": reward_type})
	_plugin_show_rewarded(reward_type)


func app_id() -> String:
	return _id("app_id", TEST_APP_ID)


func banner_id() -> String:
	return _id("banner_id", TEST_BANNER_ID)


# --- plugin adapter --------------------------------------------------------
# Stubs: replace when the AdMob plugin is installed for this game. With no
# plugin, interstitials silently skip and rewarded reports unavailable.

func _plugin_interstitial_ready() -> bool:
	return false


func _plugin_show_interstitial() -> void:
	interstitial_closed.emit()


func _plugin_rewarded_ready() -> bool:
	return false


func _plugin_show_rewarded(reward_type: String) -> void:
	rewarded_earned.emit(reward_type)


# --- id handling -----------------------------------------------------------

func _id(key: String, test_id: String) -> String:
	if OS.is_debug_build():
		return test_id
	var real := String(_ids.get(key, ""))
	return real if not real.is_empty() else test_id


func _load_ids() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		if not OS.is_debug_build():
			push_warning("AdsManager: no ads_config.local.cfg — release build is using TEST ids")
		return
	for key: String in ["app_id", "banner_id", "interstitial_id", "rewarded_id"]:
		_ids[key] = String(cfg.get_value(CONFIG_SECTION, key, ""))


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0

extends "res://addons/studio_core/ads_manager.gd"
## Jar of Goofs AdMob adapter: implements the shared AdsManager plugin stubs
## against the poing-studios AdMob plugin (addons/admob). Lives per-game
## because only games that ship ads carry the plugin; the shared AdsManager
## keeps working standalone everywhere else.
##
## Off Android (desktop runs, check.sh) the plugin wrappers are null-safe
## no-ops, so ads simply report "not ready" and the game plays fine.

const RETRY_LOAD_SEC: float = 15.0

var _interstitial: InterstitialAd = null
var _rewarded: RewardedAd = null
var _pending_reward_type: String = ""

func _ready() -> void:
	super()
	# Google Play Families policy: the store listing declares the audience
	# includes children under 13, so every ad request is tagged child-directed
	# (TFCD) with ad content capped at G. TFCD traffic gets non-personalized
	# ads automatically, so no UMP consent form is needed.
	var config := RequestConfiguration.new()
	config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	MobileAds.set_request_configuration(config)
	# initialize() is async — loading an ad before it completes throws on
	# Android, so both first loads live in the completion callback.
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_load_interstitial()
		_load_rewarded()
	MobileAds.initialize(listener)


# --- shared-stub overrides --------------------------------------------------

func _plugin_interstitial_ready() -> bool:
	return _interstitial != null


func _plugin_show_interstitial() -> void:
	if _interstitial == null:
		interstitial_closed.emit()
		return
	_interstitial.show()


func _plugin_rewarded_ready() -> bool:
	return _rewarded != null


func _plugin_show_rewarded(reward_type: String) -> void:
	if _rewarded == null:
		rewarded_unavailable.emit()
		return
	_pending_reward_type = reward_type
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		rewarded_earned.emit(_pending_reward_type)
	_rewarded.show(listener)


# --- ad loading -------------------------------------------------------------

func _load_interstitial() -> void:
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = func() -> void:
			_destroy_interstitial()
			interstitial_closed.emit()
			_load_interstitial()
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
			_destroy_interstitial()
			interstitial_closed.emit()
			_load_interstitial()
		ad.full_screen_content_callback = content
		_interstitial = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_retry(_load_interstitial)
	InterstitialAdLoader.new().load(
		_id("interstitial_id", TEST_INTERSTITIAL_ID), AdRequest.new(), callback)


func _load_rewarded() -> void:
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = func() -> void:
			_destroy_rewarded()
			rewarded_closed.emit()
			_load_rewarded()
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
			_destroy_rewarded()
			rewarded_closed.emit()
			_load_rewarded()
		ad.full_screen_content_callback = content
		_rewarded = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_retry(_load_rewarded)
	RewardedAdLoader.new().load(
		_id("rewarded_id", TEST_REWARDED_ID), AdRequest.new(), callback)


func _destroy_interstitial() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null


func _destroy_rewarded() -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null


func _retry(loader: Callable) -> void:
	get_tree().create_timer(RETRY_LOAD_SEC).timeout.connect(loader)

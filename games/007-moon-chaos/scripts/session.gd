extends Node
## Owns the GameSim instance and bridges it to SaveManager.
##
## SaveManager.set_value() writes the whole JSON file synchronously on every
## call, which is right for a score-and-lives arcade game but would thrash the
## disk if a ticking tycoon treated it as a live store. So the sim is the live
## store and disk is written only at checkpoints: after a shipment, on zone
## progress, on a purchase, and on app pause.

const SAVE_KEY: String = "moon_chaos"

var sim: GameSim = null
var balance: Balance = null

## Offline reward waiting to be shown. The main scene consumes this rather
## than listening for a signal, because autoloads finish _ready() before the
## main scene exists and would miss it.
var pending_offline: Offline.Result = null


func _ready() -> void:
	balance = Balance.load_default()
	if not balance.is_valid():
		# Loud, because every number in the game is wrong from here on.
		push_error("Session: balance.json failed validation — %s" % str(balance.errors))
	_load()


func save_now() -> void:
	if sim == null:
		return
	sim.profile.last_seen_unix = int(Time.get_unix_time_from_system())
	# to_dict() builds a fresh Dictionary every call on purpose: set_value()
	# skips the write when the value equals what it already holds, so handing
	# back the same instance would silently no-op the save.
	SaveManager.set_value(SAVE_KEY, sim.to_dict())


func reset_progress() -> void:
	sim = GameSim.new_game(balance)
	_connect_checkpoints()
	save_now()


func _load() -> void:
	var raw: Variant = SaveManager.get_value(SAVE_KEY, null)
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		sim = GameSim.from_dict(raw as Dictionary, balance)
	else:
		sim = GameSim.new_game(balance)

	_connect_checkpoints()
	_credit_offline()


func _credit_offline() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var last: int = sim.profile.last_seen_unix
	if last > 0:
		var res: Offline.Result = sim.apply_offline(float(now - last))
		if not res.is_empty():
			pending_offline = res
			Analytics.log_event("offline_earned", {"cash": res.cash, "capped": res.capped})
	sim.profile.last_seen_unix = now


func _connect_checkpoints() -> void:
	sim.shipment_launched.connect(_on_checkpoint_launch)
	sim.zone_completed.connect(_on_checkpoint_zone)
	sim.zone_unlocked.connect(_on_checkpoint_zone)
	sim.upgrade_purchased.connect(_on_checkpoint_upgrade)
	sim.tool_upgraded.connect(_on_checkpoint_tool)


func _on_checkpoint_launch(payout: int, payload: int) -> void:
	Analytics.log_event("shipment_launched", {"payout": payout, "payload": payload})
	save_now()


func _on_checkpoint_zone(zone_id: String) -> void:
	Analytics.log_event("zone_progress", {"zone": zone_id})
	save_now()


func _on_checkpoint_upgrade(track: String, level: int) -> void:
	Analytics.log_event("upgrade_bought", {"track": track, "level": level})
	save_now()


func _on_checkpoint_tool(tier: int) -> void:
	Analytics.log_event("tool_bought", {"tier": tier})
	save_now()


func _notification(what: int) -> void:
	# Mobile OSes kill backgrounded apps without warning, so pause is the last
	# reliable moment to get progress onto disk.
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE:
			save_now()

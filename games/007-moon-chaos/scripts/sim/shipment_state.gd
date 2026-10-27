class_name ShipmentState
extends RefCounted
## The shipment rocket. Fills from the depot, launches on a timer or when
## full, and pays out once the launch animation has had its moment.

enum Status { FILLING, LAUNCHING }

var status: Status = Status.FILLING
var payload: Dictionary = {}              ## dust type index -> amount
var seconds_until_launch: float = 0.0
var launch_seconds_left: float = 0.0
var pending_multiplier: float = 1.0       ## 2.0 after the rewarded ad


func payload_total() -> int:
	return Economy.total_of(payload)


func fill_pct(capacity: int) -> float:
	if capacity <= 0:
		return 0.0
	return clampf(float(payload_total()) / float(capacity) * 100.0, 0.0, 100.0)


func is_full(capacity: int) -> bool:
	return payload_total() >= capacity


func can_launch_now() -> bool:
	return status == Status.FILLING and payload_total() > 0


func reset(auto_launch_seconds: float) -> void:
	status = Status.FILLING
	payload = {}
	seconds_until_launch = auto_launch_seconds
	launch_seconds_left = 0.0
	pending_multiplier = 1.0


func begin_launch(launch_seconds: float) -> void:
	status = Status.LAUNCHING
	launch_seconds_left = maxf(launch_seconds, 0.0)


func to_dict() -> Dictionary:
	# A launch in flight is deliberately NOT persisted mid-animation: on reload
	# the rocket is back on the pad still holding its payload, so a kill during
	# the launch cannot eat the load.
	return {
		"payload": payload.duplicate(),
		"seconds_until_launch": seconds_until_launch,
		"pending_multiplier": pending_multiplier,
	}


static func from_dict(d: Dictionary, auto_launch_seconds: float) -> ShipmentState:
	var s := ShipmentState.new()
	s.status = Status.FILLING
	s.launch_seconds_left = 0.0
	s.seconds_until_launch = float(d.get("seconds_until_launch", auto_launch_seconds))
	s.pending_multiplier = maxf(float(d.get("pending_multiplier", 1.0)), 1.0)
	var p: Variant = d.get("payload", {})
	if p is Dictionary:
		for key: Variant in (p as Dictionary).keys():
			s.payload[int(key)] = int((p as Dictionary)[key])
	return s

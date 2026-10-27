class_name Offline
extends RefCounted
## Offline earnings: automation keeps working while the app is closed, at a
## reduced rate and with a hard cap.
##
## Pure and static so the cap, the clock-tamper guard and the no-automation
## case are all unit-testable without a running game.

class Result extends RefCounted:
	var dust: int = 0
	var cash: int = 0
	var elapsed_used: float = 0.0   ## seconds actually credited
	var capped: bool = false        ## true when the cap clipped the reward

	func is_empty() -> bool:
		return dust <= 0 and cash <= 0


## `elapsed_sec` is now - last_seen and may be negative if the player moved
## their device clock backwards, so it is clamped at both ends: no automation
## means no reward, and a wound-back clock must not pay out either.
static func compute(elapsed_sec: float, throughput_per_sec: float,
		cash_per_dust: float, rate_mult: float, cap_hours: float) -> Result:
	var res := Result.new()
	if throughput_per_sec <= 0.0 or rate_mult <= 0.0:
		return res

	var cap_sec: float = maxf(cap_hours, 0.0) * 3600.0
	var used: float = clampf(elapsed_sec, 0.0, cap_sec)
	res.elapsed_used = used
	res.capped = elapsed_sec > cap_sec
	if used <= 0.0:
		return res

	res.dust = int(floor(throughput_per_sec * used * rate_mult))
	res.cash = int(floor(float(res.dust) * maxf(cash_per_dust, 0.0)))
	return res

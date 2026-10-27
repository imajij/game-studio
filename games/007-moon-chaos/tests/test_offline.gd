extends "res://tests/test_case.gd"


func suite_name() -> String:
	return "offline"


func run() -> void:
	_no_automation()
	_clock_guards()
	_cap()
	_maths()


func _no_automation() -> void:
	var res: Offline.Result = Offline.compute(3600.0, 0.0, 1.0, 0.5, 8.0)
	eq(res.dust, 0, "no automation earns no dust offline")
	eq(res.cash, 0, "no automation earns no cash offline")
	ok(res.is_empty(), "the result reports itself empty")
	ok(not res.capped, "nothing to cap when nothing is earned")

	var zero_rate: Offline.Result = Offline.compute(3600.0, 10.0, 1.0, 0.0, 8.0)
	ok(zero_rate.is_empty(), "a zero offline rate earns nothing")


func _clock_guards() -> void:
	# A player winding the device clock backwards must not be paid for it.
	var backwards: Offline.Result = Offline.compute(-9999.0, 10.0, 1.0, 0.5, 8.0)
	eq(backwards.dust, 0, "a negative elapsed earns no dust")
	eq(backwards.cash, 0, "a negative elapsed earns no cash")
	approx(backwards.elapsed_used, 0.0, "a negative elapsed credits no time")
	ok(not backwards.capped, "a negative elapsed is not reported as capped")

	var instant: Offline.Result = Offline.compute(0.0, 10.0, 1.0, 0.5, 8.0)
	ok(instant.is_empty(), "no elapsed time earns nothing")


func _cap() -> void:
	var cap_hours: float = 8.0
	var within: Offline.Result = Offline.compute(3600.0, 10.0, 1.0, 1.0, cap_hours)
	approx(within.elapsed_used, 3600.0, "an hour away credits an hour")
	ok(not within.capped, "an hour is under the 8 hour cap")

	var beyond: Offline.Result = Offline.compute(100.0 * 3600.0, 10.0, 1.0, 1.0, cap_hours)
	approx(beyond.elapsed_used, cap_hours * 3600.0, "100 hours away credits only the cap")
	ok(beyond.capped, "exceeding the cap is reported so the UI can say so")

	var exactly: Offline.Result = Offline.compute(cap_hours * 3600.0, 10.0, 1.0, 1.0, cap_hours)
	ok(not exactly.capped, "landing exactly on the cap is not over it")

	# A zero cap must earn nothing rather than everything.
	var no_cap: Offline.Result = Offline.compute(3600.0, 10.0, 1.0, 1.0, 0.0)
	ok(no_cap.is_empty(), "a zero cap disables offline earnings")


func _maths() -> void:
	# 10 dust/sec for one hour at half rate = 18000 dust; at 2 cash each = 36000.
	var res: Offline.Result = Offline.compute(3600.0, 10.0, 2.0, 0.5, 8.0)
	eq(res.dust, 18000, "dust is throughput * seconds * rate")
	eq(res.cash, 36000, "cash is dust * cash_per_dust")
	ok(not res.is_empty(), "a real reward is not empty")

	# Rounding must never invent dust out of a sub-unit sliver.
	var sliver: Offline.Result = Offline.compute(1.0, 0.4, 1.0, 0.5, 8.0)
	eq(sliver.dust, 0, "a sub-unit sliver floors to zero rather than rounding up")

	var negative_cash: Offline.Result = Offline.compute(3600.0, 10.0, -5.0, 1.0, 8.0)
	eq(negative_cash.cash, 0, "a negative cash rate cannot pay out")

	# Earnings scale linearly with time inside the cap.
	var one_hour: Offline.Result = Offline.compute(3600.0, 10.0, 1.0, 1.0, 8.0)
	var two_hours: Offline.Result = Offline.compute(7200.0, 10.0, 1.0, 1.0, 8.0)
	eq(two_hours.dust, one_hour.dust * 2, "twice the time is twice the dust")

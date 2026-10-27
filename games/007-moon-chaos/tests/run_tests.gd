extends SceneTree
## Headless test runner — no third-party dependency.
##   tools/test.sh moon-chaos
## or: godot --headless --path games/007-moon-chaos --script res://tests/run_tests.gd
##
## The project must have been imported at least once, or the sim's class_name
## globals are not registered yet and every suite fails to parse.

const SUITES: Array[String] = [
	"res://tests/test_dust_grid.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_offline.gd",
	"res://tests/test_automation.gd",
	"res://tests/test_contract.gd",
]


func _initialize() -> void:
	var total_checks: int = 0
	var total_failures: int = 0
	print("")

	for path: String in SUITES:
		var script: Variant = load(path)
		if script == null:
			print("  [FAIL] could not load " + path)
			total_failures += 1
			continue

		var suite: RefCounted = (script as GDScript).new()
		suite.run()
		total_checks += suite.checks as int
		var label: String = (suite.suite_name() as String).rpad(14)

		if (suite.failures as PackedStringArray).is_empty():
			print("  [PASS] %s %d checks" % [label, suite.checks])
		else:
			var count: int = (suite.failures as PackedStringArray).size()
			total_failures += count
			print("  [FAIL] %s %d checks, %d failed" % [label, suite.checks, count])
			for f: String in suite.failures:
				print("         - " + f)

	print("")
	print("  %d checks, %d failure(s)" % [total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)

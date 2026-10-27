extends RefCounted
## Minimal assert helpers for the headless suites.
##
## Deliberately no class_name: tests/ is excluded from the Android export, and
## a globally-registered class whose file is absent from the bundle makes the
## release build log load errors at startup.

var failures: PackedStringArray = []
var checks: int = 0


func suite_name() -> String:
	return "unnamed"


## Override with the suite's assertions.
func run() -> void:
	pass


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func eq(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s — got %s, expected %s" % [label, str(actual), str(expected)])


func approx(actual: float, expected: float, label: String, tol: float = 0.0001) -> void:
	checks += 1
	if absf(actual - expected) > tol:
		failures.append("%s — got %s, expected %s" % [label, str(actual), str(expected)])

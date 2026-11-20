extends SceneTree

const STREAM = preload("res://core/movement_stream.gd")
var failed: bool = false

func _initialize() -> void:
	var stream: STREAM = STREAM.new()
	stream.reset(Vector3.ZERO, 0.0)
	check(stream.accept(1, Vector3(0.25, 0, 0), Vector3(5, 0, 0), 0, 0, 0.05), "normal movement")
	check(not stream.accept(1, Vector3.ZERO, Vector3.ZERO, 0, 0, 0.1), "stale sequence rejected")
	check(not stream.accept(2, Vector3(100, 0, 0), Vector3.ZERO, 0, 0, 0.1), "teleport rejected")
	check(not stream.accept(2, Vector3(NAN, 0, 0), Vector3.ZERO, 0, 0, 0.1), "NaN rejected")
	check(not stream.accept(2, Vector3.ZERO, Vector3(100, 0, 0), 0, 0, 0.1), "speed rejected")
	check(stream.accept(2, Vector3(0.5, 0, 0), Vector3(5, 0, 0), 0, 0, 0.1), "recovery after rejected sample")
	# Repeated packets cannot replenish displacement credit without elapsed time.
	for index: int in 20:
		stream.accept(index + 3, stream.position + Vector3(0.25, 0, 0), Vector3.ZERO, 0, 0, 0.1)
	check(stream.position.x < 3.0, "packet flood cannot multiply jitter tolerance")
	stream.reset(Vector3.ZERO, 0.0)
	stream.push(1, Vector3.ZERO, Vector3.ZERO, deg_to_rad(179), 0, 1.0)
	stream.push(2, Vector3(2, 0, 0), Vector3.ZERO, deg_to_rad(-179), 0, 1.2)
	stream.push(1, Vector3(99, 0, 0), Vector3.ZERO, 0, 0, 1.3)
	var sample: Dictionary = stream.sample(1.2)
	check(absf(sample.position.x - 1.0) < 0.001, "delayed interpolation midpoint")
	check(absf(absf(sample.yaw) - PI) < 0.01, "yaw takes shortest arc")
	check(stream.sample(5.0).position == Vector3(2, 0, 0), "holds last snapshot on loss")
	stream.reset(Vector3.ZERO, 0.0)
	stream.push(1, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 1.0, false)
	stream.push(2, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 0.0, 0.0, 1.2, true)
	check(not bool(stream.sample(1.2).grounded), "grounded state remains false before the landing snapshot time")
	check(bool(stream.sample(1.3).grounded), "grounded state changes at the landing snapshot time")
	if not failed:
		print("M3 movement checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

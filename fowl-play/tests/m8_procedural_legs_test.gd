if float(controller.get("left_swing_progress")) <= 0.0:
		_fail("Swing phase should expose a normalized progress value")
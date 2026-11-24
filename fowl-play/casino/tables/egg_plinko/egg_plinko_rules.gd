## Host-side Plinko path generation and payout calculation.
## Clients receive the resolved path and multiplier; they never choose outcomes.
class_name EggPlinkoRules
extends RefCounted

const ROW_COUNT: int = 12
const SLOT_MULTIPLIERS: Array[float] = [
	8.0, 3.0, 1.5, 1.2, 1.0, 0.8, 0.6,
	0.8, 1.0, 1.2, 1.5, 3.0, 8.0,
]

const BOARD_TOP_Y: float = 3.02
const BOARD_BOTTOM_Y: float = 1.28
const ROW_SPACING: float = (BOARD_TOP_Y - BOARD_BOTTOM_Y) / float(ROW_COUNT)
const PEG_SPACING_X: float = 0.155
const STEP_X: float = 0.155


## Builds a visual path in table-local coordinates and returns its landing slot.
## The binomial left/right decisions create the familiar Plinko distribution.
static func build_path(rng: RandomNumberGenerator, start_position: Vector3 = Vector3(0.0, BOARD_TOP_Y + 0.22, -0.02)) -> Dictionary:
	var path := PackedVector3Array()
	path.append(start_position)
	var horizontal_steps: int = 0
	var current_x: float = 0.0
	for row_index: int in range(ROW_COUNT):
		var direction: int = -1 if rng.randi_range(0, 1) == 0 else 1
		var peg_y: float = BOARD_TOP_Y - float(row_index) * ROW_SPACING
		var peg_x: float = current_x + float(direction) * STEP_X * 0.5
		path.append(Vector3(peg_x, peg_y - ROW_SPACING * 0.22, -0.015))
		horizontal_steps += direction
		current_x = float(horizontal_steps) * STEP_X * 0.5
		var row_y: float = BOARD_TOP_Y - float(row_index + 1) * ROW_SPACING
		path.append(Vector3(current_x, row_y, -0.015))
	var slot_index: int = clampi(roundi(float(horizontal_steps + ROW_COUNT) * 0.5), 0, SLOT_MULTIPLIERS.size() - 1)
	var slot_width: float = 0.19
	var slot_x: float = (float(slot_index) - float(SLOT_MULTIPLIERS.size() - 1) * 0.5) * slot_width
	path.append(Vector3(slot_x, BOARD_BOTTOM_Y - 0.13, -0.015))
	return {
		"path": path,
		"slot_index": slot_index,
		"multiplier": SLOT_MULTIPLIERS[slot_index],
	}


static func calculate_gross_return(stake: int, multiplier: float) -> int:
	if stake <= 0 or multiplier < 0.0:
		return 0
	return maxi(0, floori(float(stake) * multiplier))


static func get_slot_multipliers() -> Array[float]:
	return SLOT_MULTIPLIERS.duplicate()

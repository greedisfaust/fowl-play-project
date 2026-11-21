## Pure, shared tuning and payout rules for Chicken Cross.
extends RefCounted

const TILE_COUNT: int = 12

const FAILURE_CHANCES: Array = [
	0.03, 0.05, 0.08, 0.12, 0.17, 0.23,
	0.30, 0.39, 0.49, 0.60, 0.72, 0.85,
]

const CASHOUT_MULTIPLIERS: Array = [
	1.5, 2.2, 3.2, 4.7, 6.8, 9.8,
	14.0, 20.0, 29.0, 42.0, 61.0, 90.0,
]

static func failure_chance_for_tile(tile_number: int) -> float:
	if tile_number < 1 or tile_number > TILE_COUNT:
		return -1.0
	return float(FAILURE_CHANCES[tile_number - 1])

static func multiplier_for_tile(tile_number: int) -> float:
	if tile_number < 1 or tile_number > TILE_COUNT:
		return 0.0
	return float(CASHOUT_MULTIPLIERS[tile_number - 1])

## Returns a gross wallet return. Fractional currency is rounded down.
static func gross_return_for_stake(stake: int, tile_number: int) -> int:
	if stake <= 0:
		return 0
	var multiplier: float = multiplier_for_tile(tile_number)
	if multiplier <= 0.0:
		return 0
	return maxi(0, floori(float(stake) * multiplier))

## The host supplies a fresh roll for each player's tile entry.
static func roll_failed(tile_number: int, roll: float) -> bool:
	var chance: float = failure_chance_for_tile(tile_number)
	if chance < 0.0 or roll < 0.0 or roll >= 1.0:
		return false
	return roll < chance

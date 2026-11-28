## Authoritative Perya Color Game rules and payout math.
## Each die independently selects one of six equally likely colors.
class_name PeryaRules
extends RefCounted

const COLOR_NAMES: Array[String] = ["RED", "BLUE", "YELLOW", "GREEN", "WHITE", "PINK"]
const MATCH_GROSS_MULTIPLIERS: Array[int] = [0, 2, 3, 4]
const DICE_COUNT: int = 3
const COLOR_COUNT: int = 6

static func roll_dice(rng: RandomNumberGenerator) -> Array[int]:
	var result: Array[int] = []
	for _die_index: int in range(DICE_COUNT):
		result.append(rng.randi_range(0, COLOR_COUNT - 1))
	return result

static func count_matches(dice: Array[int], color_index: int) -> int:
	if dice.size() != DICE_COUNT or color_index < 0 or color_index >= COLOR_COUNT:
		return 0
	var matches: int = 0
	for die_color: int in dice:
		if die_color == color_index:
			matches += 1
	return matches

## Wallet settlement uses gross return: original stake plus net winnings.
static func calculate_gross_return(stake: int, match_count: int) -> int:
	if stake <= 0 or match_count < 0 or match_count > DICE_COUNT:
		return 0
	return stake * MATCH_GROSS_MULTIPLIERS[match_count]

static func calculate_bet_return(stake: int, dice: Array[int], color_index: int) -> int:
	return calculate_gross_return(stake, count_matches(dice, color_index))

static func theoretical_return_rate() -> float:
	# P(k matches) = C(3,k) * (1/6)^k * (5/6)^(3-k).
	# Gross multipliers are 0x, 2x, 3x and 4x.
	return (75.0 * 2.0 + 15.0 * 3.0 + 1.0 * 4.0) / 216.0

static func theoretical_house_edge() -> float:
	return 1.0 - theoretical_return_rate()

static func is_valid_dice(dice: Array[int]) -> bool:
	if dice.size() != DICE_COUNT:
		return false
	for color_index: int in dice:
		if color_index < 0 or color_index >= COLOR_COUNT:
			return false
	return true

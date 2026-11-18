## Shared configuration resource for simulated props.
## Owns weight, pickup, throwable, and size classification without per-prop constants.

class_name PropProfile
extends Resource

enum WeightClass {
	LIGHT,
	MEDIUM,
	HEAVY,
	IMMOVABLE,
}

@export var weight_class: WeightClass = WeightClass.MEDIUM
@export var pickup_allowed: bool = true
@export var throwable: bool = true
@export var size_class: StringName = &"medium"

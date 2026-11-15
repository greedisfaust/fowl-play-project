## Collision layer and mask constants for Fowl Play.
## Scene and gameplay code must use these values instead of raw layer numbers.

extends Node

const WORLD_STATIC: int = 1
const DEVICES: int = 2
const PROPS: int = 3
const CARRIED: int = 4
const HEALTHY_PLAYERS: int = 5
const LIMP_BODIES: int = 6
const ELEVATOR: int = 7
const PUNCH_HITBOX: int = 8
const PARRY_BARRIER: int = 9

const LAYER_MASK_WORLD_STATIC: int = (1 << (PROPS - 1)) | (1 << (HEALTHY_PLAYERS - 1)) | (1 << (LIMP_BODIES - 1))
const LAYER_MASK_DEVICES: int = (1 << (HEALTHY_PLAYERS - 1)) | (1 << (LIMP_BODIES - 1))
const LAYER_MASK_PROPS: int = (1 << (WORLD_STATIC - 1)) | (1 << (PROPS - 1)) | (1 << (HEALTHY_PLAYERS - 1)) | (1 << (LIMP_BODIES - 1))
const LAYER_MASK_CARRIED: int = 0
const LAYER_MASK_HEALTHY_PLAYERS: int = (1 << (WORLD_STATIC - 1)) | (1 << (DEVICES - 1)) | (1 << (PROPS - 1)) | (1 << (LIMP_BODIES - 1)) | (1 << (ELEVATOR - 1))
const LAYER_MASK_LIMP_BODIES: int = (1 << (WORLD_STATIC - 1)) | (1 << (PROPS - 1)) | (1 << (HEALTHY_PLAYERS - 1)) | (1 << (LIMP_BODIES - 1))
const LAYER_MASK_ELEVATOR: int = (1 << (HEALTHY_PLAYERS - 1)) | (1 << (LIMP_BODIES - 1))
const LAYER_MASK_PUNCH_HITBOX: int = (1 << (HEALTHY_PLAYERS - 1)) | (1 << (PROPS - 1)) | (1 << (PARRY_BARRIER - 1))
const LAYER_MASK_PARRY_BARRIER: int = 1 << (PUNCH_HITBOX - 1)

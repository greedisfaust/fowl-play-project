## Shared tuning constants for Fowl Play.
## This autoload is the single source of truth for gameplay and debug values.

extends Node

const INTERACT_REQUEST_INTERVAL_S: float = 0.15

const PLAYER_SPEED_MPS: float = 5.0
const JUMP_SPEED_MPS: float = 6.5
const GRAVITY_MPS2: float = 20.0
const MOUSE_SENSITIVITY: float = 0.003
const MOVE_INTERP_DELAY_S: float = 0.1
const MOVE_SANITY_MAX_SPEED_MPS: float = 15.0
const MOVE_SEND_HZ: float = 20.0

const LEG_STEP_CYCLE_DISTANCE_M: float = 2.5
const LEG_MIN_WALK_SPEED_MPS: float = 0.15
const LEG_MAX_THIGH_SWING_RAD: float = deg_to_rad(24.0)
const LEG_MAX_KNEE_BEND_RAD: float = deg_to_rad(36.0)
const LEG_FOOT_COUNTER_ROTATION: float = 0.6
const LEG_BLEND_RESPONSE: float = 10.0
const LEG_VELOCITY_RESPONSE: float = 12.0
const MAX_PUNCH_POS_ERROR_M: float = 6.0

const TAP_MAX_SECONDS: float = 0.25
const CHARGED_PUNCH_HOLD_SECONDS: float = 1.0
const CHARGED_PUNCH_COOLDOWN_SECONDS: float = 2.0
const JAB_COOLDOWN_SECONDS: float = 0.35
const QUICK_PUNCH_RANGE_M: float = 2.5
const QUICK_PUNCH_DURATION_S: float = 0.10
const CHARGED_PUNCH_RANGE_M: float = 3.5
const LUNGE_SPEED_MPS: float = 12.0
const LUNGE_DURATION_S: float = 0.5
const LUNGE_STEER_MAX_RAD_S: float = 3.0
const PARRY_GRACE_SECONDS: float = 1.5
const PARRY_COOLDOWN_SECONDS: float = 1.5
const PARRY_LIMP_SECONDS: float = 3.5

const LIMP_SECONDS: float = 3.5
const LIMP_MAX_SECONDS: float = 6.0
const LIMP_SETTLED_SPEED_MPS: float = 1.0
const GET_UP_BLEND_SECONDS: float = 0.5

const THROW_AUTO_FIRE_SECONDS: float = 1.0
const THROW_SPEED_MPS: float = 14.0
const THROW_SPEED_LIMP_MPS: float = 38.0
const REACH_M: float = 3.2
const HAND_REACH_COOLDOWN_S: float = 0.12
const CARRY_ACTION_INTERVAL_S: float = 0.15
const CARRY_RAGDOLL_SPRING_N_PER_M: float = 700.0
const CARRY_RAGDOLL_DAMPING_N_PER_MPS: float = 90.0
const CARRY_RAGDOLL_MAX_FORCE_N: float = 2400.0

const ENET_PORT: int = 7777
const MAX_PLAYERS: int = 4
const PEER_ID_HOST: int = 1
const NETWORK_TICK_RATE_HZ: int = 60
const NETWORK_PEER_TIMEOUT_S: float = 2.0

const RAGDOLL_SEND_HZ: int = 30
const RAGDOLL_INTERP_DELAY_S: float = 0.04
const BODY_SNAPSHOT_HZ: int = 15
const BODY_MAX_SPEED_MPS: float = 20.0
const BODY_KILL_PLANE_Y_M: float = -10.0
const HIPS_SYNC_TOLERANCE_M: float = 0.25

## Wall clearance for ragdoll recovery placement.
const WALL_CLEARANCE_MAX_RADIUS: float = 1.5
const WALL_CLEARANCE_STEP: float = 0.15
const WALL_CLEARANCE_ANGLE_COUNT: int = 8

const MAX_FULL_RAGDOLLS: int = 4
const MAX_AWAKE_BODIES: int = 70

const DEBUG_CONSOLE_WORD: String = "ilovedebugging"
const DEBUG_LOG_CAPACITY: int = 500
const DEBUG_UNLOCK_BUFFER_TIMEOUT_S: float = 1.0

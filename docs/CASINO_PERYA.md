# Perya — Filipino Color Game

Status: rules agreed; implementation in progress.

## Physical table and interaction
- Six betting colors: red, blue, yellow, green, white, and pink.
- Six betting spaces sit on the left side of the table; a transparent three-die cage and result tray sit on the right.
- Players use the physical betting keypad to enter an amount and press CONFIRM. Confirmation only selects the amount; it does not reserve money or place a bet.
- After selecting an amount, players click any color space to place a separate wager of that amount on that color. Repeated clicks place additional wagers. Players can change the selected amount and place more bets on any color.
- Each placed bet is represented by a physical chip. Chips have a neutral casino finish with a clear player-identity colored rim/outline and remain individually attributable in the shared wallet.
- The START / ROLL control locks all bets and begins the shared three-die roll. No bets can be placed or changed after start.
- Losing-color bets are lost; they are not refunded. Winning-color bets settle independently.

## Payouts
Payouts are gross returns, including the original stake:
- 0 matching dice: 0x
- 1 matching die: 2x
- 2 matching dice: 3x
- 3 matching dice: 4x

For one selected color, each die independently has a 1/6 chance of matching. The exact return rate is:
(75*2 + 15*3 + 1*4) / 216 = 199/216 = 92.1296%.
The theoretical house edge is 17/216 = 7.8704%.

## Multiplayer and authority
- Host generates all three dice results and validates every bet.
- Every bet is a separate shared-wallet wager with bettor peer ID, color index, and selected stake.
- The host locks the single table round before rolling and settles every locked wager exactly once from the same authoritative dice result.
- Dice results and chip placement records are replicated to clients; clients do not generate outcomes.

## Performance
- Reuse shared chip meshes/materials where possible.
- Keep one authoritative dice result and avoid per-frame polling for terminal or chip state.
- Keep dice animation limited to the three dice; avoid particle-heavy effects.

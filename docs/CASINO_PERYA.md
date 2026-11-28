# Perya — Filipino Color Game

Status: table scene, controller, visual builder, terminal profile, casino registration, and payout checks implemented; Godot runtime verification remains pending.

## Physical table and interaction
- Six betting spaces—red, blue, yellow, green, white, and pink—are arranged on the left side of the table.
- A gold-trimmed, open-front three-die cage and result area occupy the right side. Each physical die has all six Perya colors on its faces and tumbles to a landing pose with the host-selected result facing up.
- Players enter an amount on the physical betting keypad and press CONFIRM. This only selects their chip value; it does not reserve money or place a bet.
- After selecting an amount, players click any color space to place a separate wager of that amount on that color. Repeated clicks create additional independent wagers. Players may change the selected amount and bet on any color again.
- A placed wager reserves its stake immediately. The only amount restriction is the player's remaining shared-wallet balance; Perya does not impose a profile maximum or extra per-color wager cap.
- The felt shows one compact physical chip stack per player per color. Each stack uses the player's identity-color rim, a visible chip count, and an aggregate stake label. Individual bets remain separate in the shared wallet for attribution and settlement.
- The START / ROLL button locks every wager and begins the shared three-die roll. The keypad selection and all color spaces are locked until settlement.
- Losing-color wagers receive 0x and are not refunded. Winning-color wagers settle independently.

## Payouts
Payouts are gross returns, including the original stake:
- 0 matching dice: 0x
- 1 matching die: 2x
- 2 matching dice: 3x
- 3 matching dice: 4x

For one selected color, each die independently has a 1/6 chance of matching. The exact return rate is:
(75*2 + 15*3 + 1*4) / 216 = 199/216 = 92.1296%.
The theoretical house edge is 17/216 = 7.8704%.

## Presentation
- Color pads use the shared Interactable focus outline and animate on selection.
- Chip stacks pop into place and update in place rather than spawning an unbounded object per wager.
- The roll control depresses and the cage glow rises as all three six-color dice tumble and bounce to their host-selected landing faces. Color pads visibly lock during the roll and reopen after settlement. Winning colors receive a short pulse.
- The terminal retains the latest dice result and explains the wager flow and gross-return multipliers.

## Multiplayer and authority
- The host generates all three dice results and validates every bet.
- Every bet is a separate shared-wallet wager with bettor peer ID, color index, and selected stake.
- The host locks the single table round before rolling and settles every locked wager exactly once from the same authoritative dice result.
- Keypad chip-value selections, color bets, and roll requests are sent to the host for validation; accepted selections, dice results, and chip-stack presentation records are replicated to clients. Clients do not generate outcomes.
- Pre-start departure refunds are reflected in the physical chip stacks. A casino day-end request settles an already-started round immediately from its fixed host result, cancels any in-flight dice tweens, and snaps the dice to the authoritative result rather than waiting for presentation animation.

## Performance
- Chip cylinder/rim meshes and materials are reused; each player/color stack uses two MultiMesh instances and is aggregated rather than spawning one node per bet. Player stacks are laid out from actual peer IDs rather than assuming network IDs are consecutive.
- Static table geometry is built once. Only three dice, selected color surfaces, and active chip stacks animate.
- No per-frame polling is used for betting, terminal, or chip state.

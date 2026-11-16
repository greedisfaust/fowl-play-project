# Fowl Play --- Gameplay Loop Overview

**Document type:** Background gameplay-loop overview\
**Source basis:** Fowl Play Game Design Document (GDD), Version 3\
**Status:** Historical/provisional design background. The active technical
authority is `docs/PROJECT_OVERVIEW.md`; this document must not override its
current scope or decisions.

For implementation progress and the next development slice, read [PROJECT_STATE.md](PROJECT_STATE.md) and [the active session index](sessions/_ACTIVE.md). The casino/economy layer remains outside the completed D0/M0 scope.

------------------------------------------------------------------------

## 1. Purpose

This document describes the fundamental gameplay structure of *Fowl
Play* by identifying its **inner loop**, **outer loop**, and the
relationship between them.

The current GDD is expected to undergo substantial revision. For that
reason, this overview focuses on the game's broader gameplay identity
rather than treating every currently documented feature as permanent.
Specific minigames, player-interaction mechanics, timers, quota values,
and progression rules may change as development continues.

## 2. Gameplay Overview

*Fowl Play* is designed around cooperative multiplayer play in which a
group of friends participates in casino-style games while managing
shared resources and responding to one another's decisions.

The gameplay has two connected layers:

-   **Inner loop:** the repeated, moment-to-moment tables players
    perform during play.
-   **Outer loop:** the larger progression DAY 1 → DAY 10 structure that gives those
    repeated activities a longer-term purpose.

The inner loop produces the immediate outcomes---such as winnings,
losses, and player interactions. The outer loop determines what those
outcomes mean for the group's overall progress.

## 3. Inner Gameplay Loop

The inner loop describes what players repeatedly do during an active
gameplay session.

### 3.1 Inner Loop Sequence

1.  **Choose an table.** Players decide which available casino game
    or activity to participate in.
2.  **Commit a bet.** A player makes a wager or otherwise commits
    part of the group's available resources.
3.  **Play and make bet.** The player engages with the activity
    and makes decisions that involve risk and potential reward.
4.  **Resolve the outcome.** The activity produces a result that may
    increase or decrease the group's resources.
5.  **React and interact.** Teammates observe, discuss, encourage,
    discourage, or otherwise respond to the decisions and outcomes.
6.  **Return to the table choice.** Players decide what to do next,
    repeating the loop while the larger session continues.

### 3.2 Inner Loop Diagram

``` mermaid
flowchart TD
    A[Choose a casino activity] --> B[Commit a resource or place a bet]
    B --> C[Play and make risk-reward decisions]
    C --> D[Resolve the outcome]
    D --> E[Update shared resources]
    E --> F[React and interact with teammates]
    F --> A
```

### 3.3 Role of Social Interaction

Social interaction is part of the moment-to-moment gameplay, not simply
something that happens between rounds. Players share the consequences of
important decisions, creating opportunities for cooperation,
disagreement, encouragement, and chaotic situations.

The current GDD expresses this through a shared wallet and physical
intervention mechanics. Those mechanics are examples of how social
interaction can be implemented; they are not assumed to be permanent
requirements of every future version.

## 4. Outer Gameplay Loop

The outer loop describes the larger structure that motivates players to
continue engaging with the inner loop.

In Version 3 of the GDD, the larger objective is to progress through a
sequence of days, earn enough money to satisfy each day's quota, and
ultimately escape the contract.

### 4.1 Outer Loop Sequence

1.  **Begin a progression day.** The game establishes the current
    objective and the conditions for that stage.
2.  **Engage with the inner loop.** Players participate in casino
    activities to build or preserve their shared resources.
3.  **Evaluate group progress.** The game checks the group's results
    against the current objective.
4.  **Apply the outcome.** Success advances the group; failure applies
    the relevant consequence or may end the run.
5.  **Continue or conclude the run.** The group repeats the progression
    structure until it reaches the final objective or loses.

### 4.2 Outer Loop Diagram

``` mermaid
flowchart TD
    A[Begin a progression stage] --> B[Play activities through the inner loop]
    B --> C[Evaluate shared progress against the objective]
    C --> D{Objective achieved?}
    D -- Yes --> E[Advance to the next stage]
    E --> A
    D -- No --> F[Apply failure consequence]
    F --> G{Can the run continue?}
    G -- Yes --> A
    G -- No --> H[Run ends]
    E --> I[Final objective reached]
    I --> J[Successful ending]
```

*Note: This is a conceptual progression diagram. The exact number of
stages, success conditions, failure rules, and recovery systems are
subject to revision.*

## 5. Relationship Between the Inner and Outer Loops

The two loops are connected through the outcomes of moment-to-moment
play.

  -----------------------------------------------------------------------
  Inner loop activity                 Contribution to the outer loop
  ----------------------------------- -----------------------------------
  Participating in casino activities  Creates opportunities to make
                                      progress toward the larger
                                      objective

  Placing wagers or committing        Determines how much of the group's
  resources                           shared resources are at risk

  Winning or losing                   Changes the resources available for
                                      future stages

  Making risk-and-reward decisions    Influences the group's chances of
                                      meeting its objectives

  Interacting with teammates          Shapes how the group responds to
                                      shared risks and decisions
  -----------------------------------------------------------------------

The inner loop generates the results; the outer loop gives those results
meaning.

For example, a successful bet is an immediate reward. Its larger
significance comes from how it helps the group progress toward its
overall objective. Conversely, a loss matters not only because resources
were lost, but because it may make the next objective harder to achieve.

## 6. Foundational Design Elements

The following elements are supported by the Version 3 GDD and describe
the broader direction of the gameplay:

-   **Cooperative multiplayer:** players work toward a shared overall
    outcome.
-   **Casino-style activities:** players engage with gambling-inspired
    minigames.
-   **Shared resources:** individual decisions can affect the group's
    collective resources.
-   **Risk and reward:** players repeatedly decide how much risk to
    accept for a potential gain.
-   **Social decision-making:** players observe and respond to the
    choices of their teammates.
-   **Longer-term progression:** repeated activities contribute toward a
    larger objective and an eventual run outcome.

These are the foundational elements this overview uses to explain the
gameplay structure. They should be reviewed against the revised GDD as
the design changes.

## 7. Features That May Change During Revision

The following features appear in Version 3 but should be treated as
current implementations or design proposals rather than fixed
assumptions for this overview:

-   The specific roster of five minigames.
-   The hit, stun, carry, and throw mechanics.
-   The Blessed and Cursed Watched Player system.
-   The ten-day progression structure.
-   The five-minute daily timer.
-   Daily quota calculations and values.
-   The one-time extra-life system and wallet-halving penalty.
-   The exact table availability and rotation rules.
-   The specific win and loss conditions.

If these features are replaced, the inner and outer loop descriptions
can be updated without necessarily changing the overall framework.

## 8. Design Summary

*Fowl Play* is structured around a repeated cycle of participating in
casino activities, making risk-and-reward decisions, resolving outcomes,
and responding to teammates. Those repeated interactions form the
**inner gameplay loop**.

The **outer gameplay loop** organizes those activities into a larger
progression challenge. It gives the group a shared objective, makes the
consequences of individual decisions accumulate, and provides a reason
to continue playing.

In short:

-   **Inner loop:** Choose an table → commit betting → play and
    decide → resolve the outcome → react with teammates → repeat.
-   **Outer loop:** Begin a day → play the inner loop → evaluate
    progress → advance, recover, or end the run.

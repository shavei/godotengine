class_name CeremonyTimeline
extends RefCounted
## When each beat of the gift ceremony plays (docs/GDD.md Section 3.1, step 4): the Spark
## leaves the hero, flies to the villager, bursts, the villager and their house take the
## power's colors, then the villager says their line. The first ceremony plays until the
## line has been on screen for a moment; later ones can be skipped at once.

## The screen frames the villager and the Spark rises from the hero.
const RISE_AT: float = 0.4
## The Spark flies from the hero to the villager.
const FLY_AT: float = 1.0
## It bursts on the villager; their colors and roof change over SWAP_TIME.
const BURST_AT: float = 2.3
const SWAP_TIME: float = 0.9
## The villager's line and their new service appear.
const LINE_AT: float = 3.2
## The first ceremony can be continued once the line has shown this long.
const FIRST_READ_TIME: float = 1.5
## The ceremony ends on its own (GDD: 5 to 8 seconds).
const DURATION: float = 7.5


## Later ceremonies skip at once; the first waits until the line has been read.
static func can_skip(ceremonies_seen: int, elapsed: float) -> bool:
	return ceremonies_seen > 0 or elapsed >= LINE_AT + FIRST_READ_TIME


static func is_over(elapsed: float) -> bool:
	return elapsed >= DURATION


## 0 until the Spark leaves the hero, 1 when it reaches the villager.
static func flight(elapsed: float) -> float:
	return clampf((elapsed - FLY_AT) / (BURST_AT - FLY_AT), 0.0, 1.0)


## 0 before the burst, 1 once the villager and their house wear the power's colors.
static func swap(elapsed: float) -> float:
	return clampf((elapsed - BURST_AT) / SWAP_TIME, 0.0, 1.0)


static func has_burst(elapsed: float) -> bool:
	return elapsed >= BURST_AT


static func shows_line(elapsed: float) -> bool:
	return elapsed >= LINE_AT

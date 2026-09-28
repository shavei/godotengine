class_name StatusEffects
extends RefCounted
## Status effect rules (docs/GDD.md Section 7.3), pure so they can be tested headless.
## StatusComponent owns one per actor and ticks it.
## - Burn: damage per stack every interval, stacks to 3.
## - Chill: slows moving and attacking; enough stacks Freeze (no moving, no acting).
## - Root: cannot move, can still act.
## - Stagger: hits fill a bar; a full bar Stuns (no moving, no acting) and empties.
## Bosses: durations are shorter, and they cannot be Frozen or Rooted: a freeze or a
## root fills their (bigger) stagger bar instead.

signal status_added(id: StringName)
signal status_removed(id: StringName)
## The stagger bar filled up and the actor is stunned.
signal staggered

const BURN: StringName = &"burn"
const CHILL: StringName = &"chill"
const FREEZE: StringName = &"freeze"
const ROOT: StringName = &"root"
const STUN: StringName = &"stun"

var balance: BalanceData
var is_boss: bool = false
## Current fill of the stagger bar (0 to stagger_max()).
var stagger: float = 0.0

## id -> { "time": float, "stacks": int }
var _active: Dictionary = {}
var _burn_clock: float = 0.0
## Bosses: a root fills the stagger bar at most once per (boss) root duration.
var _boss_root_wait: float = 0.0


func _init(tuning: BalanceData = null, boss: bool = false) -> void:
	balance = tuning if tuning != null else BalanceData.new()
	is_boss = boss


## Adds `count` stacks of a status from a hit (burn, chill or root).
func apply(id: StringName, count: int = 1) -> void:
	match id:
		BURN:
			_add(BURN, balance.burn_duration, count, balance.burn_max_stacks)
		CHILL:
			if has(FREEZE) or has(STUN):
				return
			_add(CHILL, balance.chill_duration, count, balance.chill_freeze_stacks)
			if self.stacks(CHILL) >= balance.chill_freeze_stacks:
				remove(CHILL)
				if is_boss:
					add_stagger(balance.boss_freeze_stagger)
				else:
					_add(FREEZE, balance.freeze_duration, 1, 1)
		ROOT:
			if is_boss:
				if _boss_root_wait <= 0.0:
					_boss_root_wait = balance.root_duration * balance.boss_status_duration_scale
					add_stagger(balance.boss_root_stagger)
			else:
				_add(ROOT, balance.root_duration, 1, 1)
		_:
			push_warning("StatusEffects: unknown status %s" % id)


## Fills the stagger bar. A full bar stuns and empties. No build-up while stunned.
func add_stagger(amount: float) -> void:
	if amount <= 0.0 or has(STUN):
		return
	stagger += amount
	if stagger >= stagger_max():
		stagger = 0.0
		_add(STUN, balance.stagger_stun, 1, 1)
		staggered.emit()


func stagger_max() -> float:
	return balance.boss_stagger_bar if is_boss else balance.stagger_bar


func stagger_fraction() -> float:
	return clampf(stagger / maxf(stagger_max(), 1.0), 0.0, 1.0)


func has(id: StringName) -> bool:
	return _active.has(id)


func stacks(id: StringName) -> int:
	return _active[id]["stacks"] if _active.has(id) else 0


func time_left(id: StringName) -> float:
	return _active[id]["time"] if _active.has(id) else 0.0


func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_active.keys())
	return ids


func remove(id: StringName) -> void:
	if _active.erase(id):
		if id == BURN:
			_burn_clock = 0.0
		status_removed.emit(id)


func clear() -> void:
	for id: StringName in active_ids():
		remove(id)
	stagger = 0.0


## Frozen or stunned: no moving and no acting.
func is_held() -> bool:
	return has(FREEZE) or has(STUN)


## Multiplier on the actor's own movement (0 when it cannot move).
func move_scale() -> float:
	if is_held() or has(ROOT):
		return 0.0
	return action_scale()


## Multiplier on how fast the actor acts (its AI clock, attack timings).
func action_scale() -> float:
	if is_held():
		return 0.0
	if has(CHILL):
		return 1.0 - balance.chill_slow
	return 1.0


## Advances every timer. Returns the burn damage dealt during this step.
func tick(delta: float) -> int:
	var damage: int = 0
	_boss_root_wait = maxf(_boss_root_wait - delta, 0.0)
	if has(BURN):
		_burn_clock += delta
		while _burn_clock >= balance.burn_interval and balance.burn_interval > 0.0:
			_burn_clock -= balance.burn_interval
			damage += balance.burn_damage * stacks(BURN)
	for id: StringName in _active.keys():
		var entry: Dictionary = _active[id]
		entry["time"] -= delta
		if entry["time"] <= 0.0:
			remove(id)
	return damage


func _add(id: StringName, duration: float, add_stacks: int, max_stacks: int) -> void:
	var time: float = duration * (balance.boss_status_duration_scale if is_boss else 1.0)
	if _active.has(id):
		var entry: Dictionary = _active[id]
		entry["time"] = maxf(entry["time"], time)
		entry["stacks"] = mini(entry["stacks"] + add_stacks, max_stacks)
		return
	_active[id] = {"time": time, "stacks": clampi(add_stacks, 1, maxi(max_stacks, 1))}
	status_added.emit(id)

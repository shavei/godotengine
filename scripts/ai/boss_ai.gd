class_name BossAI
extends EnemyAI
## Base for boss behavior: picks moves from the boss's BossPattern and announces the
## enrage. Bosses shrug off hits (their data has hit_stun 0), so interrupt() never runs
## from a hit. Subclasses read their numbers from `boss` (the enemy's BossData).

var boss: BossData
var pattern: BossPattern


func setup(owner_enemy: Enemy) -> void:
	super.setup(owner_enemy)
	boss = owner_enemy.data as BossData
	if boss == null:
		push_error("%s needs BossData" % owner_enemy.data.id)
		boss = BossData.new()
	pattern = BossPattern.from_data(boss)


func hp_fraction() -> float:
	return float(enemy.health.hp) / maxf(enemy.health.max_hp, 1.0)


## The boss's next move; emits the enemy's `enraged` the first time HP is below the line.
func next_move() -> StringName:
	if pattern.check_enrage(hp_fraction()):
		enemy.announce_enrage()
	return pattern.next(hp_fraction())

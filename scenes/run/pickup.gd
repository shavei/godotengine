class_name Pickup
extends Node2D
## Loot on the floor (docs/GDD.md Section 9): coins, materials, Crystal or Power Shards.
## Pops out where it dropped, then drifts to a hero who comes close and is collected on
## touch. After a room clear every pickup flies to the nearest hero.

signal collected(pickup: Pickup, hero: Hero)

const POP_TIME: float = 0.3
const FRICTION: float = 260.0
const MAGNET_RADIUS: float = 40.0
const COLLECT_RADIUS: float = 10.0
const MAGNET_ACCEL: float = 900.0
const MAX_SPEED: float = 320.0

var currency: StringName = Wallet.COINS
var amount: int = 1
var velocity: Vector2 = Vector2.ZERO
## True after a room clear: fly to the nearest hero from anywhere.
var attracted: bool = false

var _time: float = 0.0
var _done: bool = false


static func create(pickup_currency: StringName, pickup_amount: int, launch: Vector2 = Vector2.ZERO) -> Pickup:
	var pickup: Pickup = Pickup.new()
	pickup.currency = pickup_currency
	pickup.amount = pickup_amount
	pickup.velocity = launch
	return pickup


func attract() -> void:
	attracted = true


func is_collected() -> bool:
	return _done


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var hero: Hero = _nearest_hero()
	if _time >= POP_TIME and hero != null:
		var to_hero: Vector2 = hero.global_position - global_position
		if to_hero.length() <= COLLECT_RADIUS:
			collect(hero)
			return
		if attracted or to_hero.length() <= MAGNET_RADIUS:
			velocity = (velocity + to_hero.normalized() * MAGNET_ACCEL * delta).limit_length(MAX_SPEED)
			# Never overshoot: the hero is reached this frame.
			if velocity.length() * delta >= to_hero.length():
				collect(hero)
				return
		else:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	position += velocity * delta
	queue_redraw()


## Hands the pickup to `hero` once. The room adds it to the hero's wallet.
func collect(hero: Hero) -> void:
	if _done:
		return
	_done = true
	collected.emit(self, hero)
	queue_free()


func _nearest_hero() -> Hero:
	var best: Hero = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var hero: Hero = node as Hero
		if hero == null or hero.health.is_dead():
			continue
		var distance: float = global_position.distance_squared_to(hero.global_position)
		if distance < best_distance:
			best = hero
			best_distance = distance
	return best


func _draw() -> void:
	var color: Color = Wallet.currency_color(currency)
	var outline: Color = Color(0.05, 0.03, 0.05)
	var bob: Vector2 = Vector2(0.0, sin(_time * 5.0 + position.x) * 1.5)
	match currency:
		Wallet.COINS:
			draw_circle(bob, 4.0, outline)
			draw_circle(bob, 3.0, color)
		Wallet.CRYSTAL, Wallet.SHARDS:
			var gem: PackedVector2Array = [bob + Vector2(0, -6), bob + Vector2(4, 0), bob + Vector2(0, 6), bob + Vector2(-4, 0)]
			draw_colored_polygon(gem, color)
			gem.append(gem[0])
			draw_polyline(gem, outline, 1.0)
		_:
			var log_rect: Rect2 = Rect2(bob + Vector2(-5, -3), Vector2(10, 6))
			draw_rect(log_rect.grow(1.0), outline)
			draw_rect(log_rect, color)

class_name TechniqueBehavior
extends Node
## The part of a Technique that is more than numbers (TechniqueData.behavior_script): a
## node the hero carries in a run room that listens to the hero's signals (a dodge, a
## perfect dodge, a drop in HP) and acts. Hero.apply_techniques() adds one per Technique
## that has a script, and replaces them all on the next call. Numbers live in BalanceData.

var hero: Hero
var technique: TechniqueData


## Called by Hero.apply_techniques() before the node enters the tree.
func attach(owner_hero: Hero, data: TechniqueData) -> void:
	hero = owner_hero
	technique = data
	name = String(data.id).to_pascal_case()


## Where effects go: the hero's world (next to the hero).
func world() -> Node:
	return hero.get_parent()

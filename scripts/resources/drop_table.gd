class_name DropTable
extends Resource
## What an enemy, chest or reward drops (docs/GDD.md Sections 6.2 and 15.3). Every
## entry rolls on its own; LootRoller does the rolling.

@export var entries: Array[DropEntry] = []

class_name ServiceData
extends Resource
## What a villager does for the hero (docs/ARCHITECTURE.md Section 4.1): a base service
## with no power, or the Novice or Adept service of a villager+power combo.
## Stat modifiers join with the ModifierStack (M4 PR 2); for now it is the text shown on
## villager cards and in the village.

@export_multiline var description: String = ""

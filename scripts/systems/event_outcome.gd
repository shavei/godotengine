class_name EventOutcome
extends RefCounted
## What happened when an Event choice was made. Returned by EventResolver.resolve().

## False if the hero could not pay the cost (nothing else happened).
var paid: bool = false
var success: bool = false
## The hero's HP after the cost and any heal.
var hp: int = 0
## Rolled reward: currency -> amount. Empty on a failure.
var gains: Dictionary[StringName, int] = {}
var text: String = ""

class_name BotLevel
extends Resource
## How well a computer player plays: what it's allowed to do and the ranges
## its personality is rolled from. The lobby picks one per CPU slot
## (entities/controllers/levels/); each mode's BotBrain reads it, so the same
## level means "easy" in whatever way that mode's bots play.

@export var display_name := "NORMAL"
@export var moves := true  # false: stands still, a training dummy
@export var pushes := true # false: never pushes (still runs, eats, dodges)
@export var dashes := true
@export var shields := true # false: never raises its shield

@export_group("Personality ranges")
## Each bot rolls its personality numbers (see BotBrain) inside these ranges on spawn.
@export var aggression := Vector2(0.4, 1.0)
@export var caution := Vector2(0.2, 0.9)
@export var greed := Vector2(0.2, 0.9)
@export var skill := Vector2(0.3, 1.0)

@export_group("Reflexes")
@export var reaction_scale := 1.0 # multiplies the delay before pushing

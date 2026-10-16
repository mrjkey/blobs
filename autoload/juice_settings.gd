class_name JuiceSettings
extends Resource
## Screen shake, hitstop, sparks and sound volume. Read by the Juice and Sfx
## autoloads; the values live in autoload/juice_settings.tres.

@export_group("Hitstop")
@export var hitstop_push := 0.06       # freeze when a push connects
@export var hitstop_bump := 0.03       # freeze on a hard blob-vs-blob hit
@export var hitstop_min_impact := 500.0
@export var hitstop_elimination := 0.08

@export_group("Shake")
@export var shake_push := 7.0
@export var shake_whiff := 1.5
@export var shake_per_impact := 0.012
@export var shake_min_impact := 250.0
@export var shake_elimination := 10.0
@export var shake_max := 18.0
@export var shake_decay := 9.0

@export_group("Sparks and sound")
@export var spark_min_impact := 150.0
@export var sfx_volume_db := -8.0

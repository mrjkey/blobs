class_name Blob
extends Node2D

signal pushed(blob: Blob) # main listens: shake, hitstop, shockwave
signal bumped(blob: Blob, impact: float)
signal ate_food(blob: Blob)
signal eliminated(blob: Blob)

@export var stats: BlobStats
@export var color := Color.WHITE
@export var display_name := "Blob"
@export var show_push_ring := false # cooldown ring + arrow, for human-controlled blobs

var vel := Vector2.ZERO
var mass := 1.0
var radius := 22.0
var move_dir := Vector2.ZERO # set by PlayerInput or BotBrain
var alive := true
var push_cooldown := 0.0
var push_buffer := 0.0
var windup := 0.0
var stun := 0.0
var ring_danger := 0.0 # 0..1, set by the arena while outside the ring

@onready var body: BlobBody = $Body
@onready var push_sound: AudioStreamPlayer2D = $PushSound

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set_mass(mass)
	pass

#func set_mass(m: float) -> void:
	#mass = clampf(m, 0.5, T.MAX_MASS)
	#radius = T.BASE_RADIUS * pow(mass, T.SIZE_RADIUS_EXP)

func request_push() -> void:
	push_buffer = 0.15


## Distance from this blob's centre that a push can reach.
func push_reach() -> float:
	return radius + stats.push_range * pow(mass, stats.push_range_mass_exp)


func push_ready() -> bool:
	return push_cooldown <= 0.0 and windup <= 0.0


func is_winding_up() -> bool:
	return windup > 0.0

func step_motion(h: float) -> void:
	pass
	
func _release_push() -> void:
	var reach := radius + stats.push_range
	for other: Blob in get_tree().get_nodes_in_group("blobs"):
		if other == self or not other.alive:
			continue
	push_sound.play()
	pushed.emit(self)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

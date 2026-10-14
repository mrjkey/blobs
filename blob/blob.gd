class_name Blob
extends Node2D

signal pushed(blob: Blob) # main listens: shake, hitstop, shockwave
signal bumped(blob: Blob, impact: float)
signal ate_food(blob: Blob)
signal eliminated(blob: Blob)

@export var stats: BlobStats
@export var color := Color.WHITE
@export var display_name := "Blob"

var vel := Vector2.ZERO
var mass := 1.0
var radius := 22.0
var move_dir := Vector2.ZERO # set by PlayerInput or BotBrain
var alive := true
var push_cooldown := 0.0
var push_buffer := 0.0
var windup := 0.0
var stun := 0.0

@onready var body: Node2D = $Body
@onready var push_sound: AudioStreamPlayer2D = $PushSound

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set_mass(mass)
	pass

func request_push() -> void:
	push_buffer = 0.15

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

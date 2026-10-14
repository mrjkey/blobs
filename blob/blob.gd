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
	set_mass(mass)


func set_mass(m: float) -> void:
	mass = clampf(m, 0.5, stats.max_mass)
	radius = stats.base_radius * pow(mass, stats.size_radius_exp)


func max_speed() -> float:
	return stats.base_speed / pow(mass, stats.size_speed_exp)


func accel() -> float:
	return stats.base_accel / pow(mass, stats.size_accel_exp)


func request_push() -> void:
	push_buffer = 0.15


## Distance from this blob's centre that a push can reach.
func push_reach() -> float:
	return radius + stats.push_range * pow(mass, stats.push_range_mass_exp)


func push_ready() -> bool:
	return push_cooldown <= 0.0 and windup <= 0.0


func is_winding_up() -> bool:
	return windup > 0.0


## Called by BlobPhysics once per substep. `in_mud` is true outside the ring.
func step_motion(h: float, in_mud: bool) -> void:
	var control := 1.0
	if stun > 0.0:
		control = stats.stun_control
	if in_mud:
		control *= stats.outside_control
	var top := max_speed()
	# Flying faster than you could run means you got launched: keep the momentum,
	# but bleed it off fast so hits read as a sharp shove, not a slow drift.
	var launched := vel.length() > top * 1.05
	if launched:
		control *= stats.knockback_control
	var target := move_dir * top
	var acc := accel()
	if move_dir.dot(vel) < 0.0:
		acc *= stats.turn_accel_mult  # snappy direction changes
	vel += (target - vel).limit_length(acc * control * h)
	var drag := stats.knockback_drag if launched else stats.drag
	if in_mud:
		drag += stats.outside_drag
	vel *= exp(-drag * h)
	position += vel * h


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

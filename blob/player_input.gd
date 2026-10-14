extends Node
@onready var blob: Blob = get_parent()

func _physics_process(_delta: float) -> void:
	blob.move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("push"):
		blob.request_push()

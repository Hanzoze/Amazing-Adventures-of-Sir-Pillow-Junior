extends Camera3D

@export var FOLLOW_SPEED: float = 5.0
@export var OFFSET: Vector3 = Vector3(0, 20, 12)

var target: Node3D = null

func _ready() -> void:
	target = get_parent()
	if target and is_instance_valid(target):
		global_position = target.global_position + OFFSET

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	var target_pos = target.global_position + OFFSET
	var t: float = clamp(FOLLOW_SPEED * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, t)

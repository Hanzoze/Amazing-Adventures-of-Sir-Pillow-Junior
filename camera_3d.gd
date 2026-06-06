extends Camera3D

@export var FOLLOW_SPEED: float = 5.0
@export var OFFSET: Vector3 = Vector3(0, 20, 12) # Идеальное смещение для изометрии (X, Y, Z)

var target: Node3D = null

func _ready() -> void:
	# Ищем игрока на сцене уровня. 
	# "Player" — это должно быть точное имя ноды твоего игрока в дереве сцены уровня
	target = get_parent()
	
	if target and is_instance_valid(target):
		# Мгновенно перемещаем камеру в точку над игроком при старте, чтобы не было рывка
		global_position = target.global_position + OFFSET
	else:
		printerr("Камера не смогла найти ноду с именем 'Player' на сцене!")

func _physics_process(delta: float) -> void:
	# Если цель потерялась или ещё не создана, ничего не делаем
	if not target or not is_instance_valid(target):
		return
	
	# Вычисляем, где камера ДОЛЖНА находиться
	var target_pos = target.global_position + OFFSET
	
	# Плавно двигаем камеру из текущей позиции в целевую
	var t: float = clamp(FOLLOW_SPEED * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, t)

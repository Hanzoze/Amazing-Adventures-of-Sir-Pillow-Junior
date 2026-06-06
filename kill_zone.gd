extends Area3D

func _ready() -> void:
	monitoring = true
	monitorable = false
	
	collision_layer = 0
	collision_mask = 1 << 1
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("die") and not body.is_dead:
		print("[ЗОНА СМЕРТИ] Объект ", body.name, " попал в ", name, ". Мгновенное уничтожение!")
		body.die()

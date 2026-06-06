extends Node

@export var enemy_scene: PackedScene
@export var spawn_points: Array[Node3D]
@export var hud: CanvasLayer

var current_wave: int = 0
var active_enemies_count: int = 0
var enemies_container: Node3D

func _ready() -> void:
	enemies_container = Node3D.new()
	enemies_container.name = "EnemiesContainer"
	# Deferred so the scene tree is ready before adding the container
	get_tree().current_scene.add_child.call_deferred(enemies_container)
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func start_next_wave() -> void:
	current_wave += 1
	active_enemies_count = current_wave
	for i in range(current_wave):
		spawn_enemy()

func spawn_enemy() -> void:
	if not enemy_scene:
		return
	var enemy = enemy_scene.instantiate()
	if enemies_container:
		enemies_container.add_child(enemy)
	else:
		get_tree().current_scene.add_child(enemy)
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_killed)
	if spawn_points.size() > 0:
		var base_pos = spawn_points.pick_random().global_position
		var offset = Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
		enemy.global_position = base_pos + offset
	else:
		enemy.global_position = Vector3.ZERO

func _on_enemy_killed() -> void:
	Global.enemies_killed += 1
	if hud and hud.has_node("EnemiesCounterLabel"):
		hud.get_node("EnemiesCounterLabel").text = str(Global.enemies_killed)
	active_enemies_count -= 1
	if active_enemies_count <= 0:
		active_enemies_count = 0
		await get_tree().create_timer(3.0).timeout
		start_next_wave()

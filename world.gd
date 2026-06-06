@tool
extends Node3D

@export var map_2d: TileMapLayer
@export var radius: float = 1.0

@export var tile_library: Dictionary = {
	0: preload("res://assets/models/grass.glb"),
	1: preload("res://assets/models/water.glb"),
	2: preload("res://assets/models/low_grass.glb"),
	3: preload("res://assets/models/high_grass.glb")
}

func _ready():
	if map_2d:
		generate_from_2d()

func generate_from_2d():
	for child in get_children():
		if child is Node3D:
			child.queue_free()
	for cell in map_2d.get_used_cells():
		var tile_id = map_2d.get_cell_source_id(cell)
		if tile_library.has(tile_id):
			spawn_3d_tile(cell, tile_library[tile_id])

func spawn_3d_tile(grid_pos: Vector2i, scene: PackedScene):
	var tile_instance = scene.instantiate()
	add_child(tile_instance)
	var width = sqrt(3) * radius
	var height_step = 1.5 * radius
	var row_is_odd = fposmod(grid_pos.y, 2) >= 1.0
	var x_offset = (width / 2.0) if row_is_odd else 0.0
	tile_instance.position = Vector3(
		grid_pos.x * width + x_offset,
		0,
		grid_pos.y * height_step
	)

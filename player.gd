extends CharacterBody3D

@onready var hud: CanvasLayer = get_tree().current_scene.get_node("HUD")
@onready var attack_area: Area3D = $Knight/AttackArea

@export var max_health: float = 100.0
var current_health: float = max_health
var is_dead: bool = false

@export var SPEED: float = 15.0
@export var JUMP_VELOCITY: float = 15.0
@export var ROTATION_SPEED: float = 10.0
@export var FLIP_ROTATION: bool = true

@export var GRAVITY_MULTIPLIER: float = 2.0
@export var FALL_GRAVITY_MULTIPLIER: float = 8.0

const ATTACK_DURATION: float = 0.97
const INPUT_WINDOW_DELAY: float = 0.12
const LUNGE_DURATION: float = 0.18
const LUNGE_FORCE: float = 50.0
const LUNGE_DAMPING: float = 15.0

@onready var knight_mesh: Node3D = $Knight
@onready var animation_tree: AnimationTree = $AnimationTree

var base_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_lunge_velocity: Vector3 = Vector3.ZERO

var combo_step: int = 0
var is_attacking: bool = false
var can_attack: bool = true
var attack_timer: float = 0.0
var lunge_timer: float = 0.0
# Ensures damage is dealt exactly once per strike
var damage_inflicted_this_strike: bool = false
# Buffers an attack input if pressed too early
var has_buffered_attack: bool = false


func _ready() -> void:
	if animation_tree:
		animation_tree.active = true
	if hud:
		hud.call_deferred("init_health", max_health)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		if velocity.y > 0:
			velocity.y -= base_gravity * GRAVITY_MULTIPLIER * delta
		else:
			velocity.y -= base_gravity * FALL_GRAVITY_MULTIPLIER * delta

	if is_attacking:
		attack_timer -= delta

		if not damage_inflicted_this_strike and attack_timer <= 0.72:
			deal_damage_frame()

		if attack_timer <= INPUT_WINDOW_DELAY:
			can_attack = true
			if has_buffered_attack and combo_step < 3:
				has_buffered_attack = false
				trigger_attack()

		if attack_timer <= 0.0:
			reset_combo()

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("click") and is_on_floor():
		if can_attack:
			trigger_attack()
		elif is_attacking and not has_buffered_attack and combo_step < 3:
			has_buffered_attack = true

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO

	if input_dir != Vector2.ZERO and camera:
		var cam_basis := camera.global_transform.basis
		var cam_forward := -cam_basis.z
		var cam_right := cam_basis.x
		cam_forward.y = 0
		cam_right.y = 0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()
		direction = (cam_right * input_dir.x + cam_forward * -input_dir.y).normalized()

	if is_attacking:
		if lunge_timer > 0.0:
			lunge_timer -= delta
			current_lunge_velocity = current_lunge_velocity.lerp(Vector3.ZERO, LUNGE_DAMPING * delta)
			if current_lunge_velocity.length() < 0.5:
				current_lunge_velocity = Vector3.ZERO
			velocity.x = current_lunge_velocity.x
			velocity.z = current_lunge_velocity.z
		else:
			current_lunge_velocity = Vector3.ZERO
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	else:
		current_lunge_velocity = Vector3.ZERO
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	rotate_to_mouse()

	if animation_tree:
		var horizontal_velocity := Vector2(velocity.x, velocity.z)
		var moving := horizontal_velocity.length() > 0.2
		var in_air := not is_on_floor()
		animation_tree.set("parameters/conditions/is_jumping", in_air)
		animation_tree.set("parameters/conditions/is_moving", moving and not in_air)
		animation_tree.set("parameters/conditions/is_idle", not moving and not in_air)


func trigger_attack() -> void:
	combo_step += 1
	if combo_step > 3:
		reset_combo()
		return

	is_attacking = true
	can_attack = false
	attack_timer = ATTACK_DURATION
	lunge_timer = LUNGE_DURATION
	damage_inflicted_this_strike = false
	animation_tree.set("parameters/conditions/attack_ended", false)

	if knight_mesh:
		var forward_direction := knight_mesh.global_transform.basis.z.normalized()
		current_lunge_velocity = forward_direction * LUNGE_FORCE

	update_tree_conditions()


func update_tree_conditions() -> void:
	if not animation_tree:
		return
	animation_tree.set("parameters/conditions/start_attack", combo_step == 1)
	animation_tree.set("parameters/conditions/shoot_attack_2", combo_step == 2)
	animation_tree.set("parameters/conditions/shoot_attack_3", combo_step == 3)


func reset_combo() -> void:
	combo_step = 0
	is_attacking = false
	can_attack = true
	has_buffered_attack = false
	current_lunge_velocity = Vector3.ZERO
	lunge_timer = 0.0
	damage_inflicted_this_strike = false

	if animation_tree:
		animation_tree.set("parameters/conditions/start_attack", false)
		animation_tree.set("parameters/conditions/shoot_attack_2", false)
		animation_tree.set("parameters/conditions/shoot_attack_3", false)
		animation_tree.set("parameters/conditions/attack_ended", true)


func rotate_to_mouse() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not knight_mesh:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	if ray_direction.y == 0:
		return
	var t := (global_position.y - ray_origin.y) / ray_direction.y
	var target_point := ray_origin + ray_direction * t
	target_point.y = global_position.y

	if global_position.distance_to(target_point) > 0.1:
		var look_target := target_point
		if FLIP_ROTATION:
			look_target = global_position - (target_point - global_position)
		var target_transform := knight_mesh.global_transform.looking_at(look_target, Vector3.UP)
		knight_mesh.global_transform.basis = knight_mesh.global_transform.basis.slerp(
			target_transform.basis,
			ROTATION_SPEED * get_physics_process_delta_time()
		).orthonormalized()


func deal_damage_frame() -> void:
	damage_inflicted_this_strike = true
	if attack_area:
		for body in attack_area.get_overlapping_bodies():
			if body.has_method("take_damage"):
				# Combo step 3 deals bonus damage
				var damage_to_deal: float = 50.0 if combo_step == 3 else 35.0
				body.take_damage(damage_to_deal)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	if hud:
		hud.update_health(current_health)
	if current_health <= 0:
		die()


func die() -> void:
	is_dead = true
	queue_free()
	get_tree().change_scene_to_file("res://menu_game_over.tscn")

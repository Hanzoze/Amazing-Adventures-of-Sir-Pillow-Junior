extends CharacterBody3D

signal enemy_died

@export var SPEED: float = 5.0
@export var ROTATION_SPEED: float = 10.0
@export var FLIP_ROTATION: bool = true

@export var max_health: float = 100.0
var current_health: float = max_health
var is_dead: bool = false

const ANIM_MOVE: String = "Demon_Crawl/mixamo_com"
const ANIM_IDLE: String = "Demon_TPose/mixamo_com"
const ANIM_DEATH: String = "Death"
const ANIM_ATTACK: String = "Demon_attack1/mixamo_com"

const ATTACK_COOLDOWN: float = 1.2
const ATTACK_DAMAGE: float = 10

# Seconds before animation end when damage is applied
@export var DAMAGE_WINDOW_BEFORE_END: float = 0.1

var attack_cooldown_timer: float = 0.0
var attack_elapsed_timer: float = 0.0
var is_attacking: bool = false
var damage_inflicted_this_strike: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var enemy_attack_area: Area3D = $Armature/EnemyAttackArea

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: CharacterBody3D = null

func _ready() -> void:
	player = get_tree().current_scene.get_node_or_null("Player")
	if animation_player and animation_player.has_animation(ANIM_IDLE):
		_play_animation(ANIM_IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if is_attacking:
		attack_elapsed_timer += delta
		var anim_length = animation_player.current_animation_length
		var damage_trigger_time = anim_length - DAMAGE_WINDOW_BEFORE_END

		if not damage_inflicted_this_strike and attack_elapsed_timer >= damage_trigger_time:
			deal_damage_to_player()

		if attack_elapsed_timer >= anim_length:
			is_attacking = false
			attack_elapsed_timer = 0.0

		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	if player and is_instance_valid(player):
		if "is_dead" in player and player.is_dead:
			stop_and_idle()
			return

		var direction = (player.global_position - global_position)
		direction.y = 0
		direction = direction.normalized()

		var target_look = global_position + direction
		if FLIP_ROTATION:
			target_look = global_position - direction
		var target_transform = global_transform.looking_at(target_look, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(
			target_transform.basis, ROTATION_SPEED * delta
		).orthonormalized()

		if enemy_attack_area and attack_cooldown_timer <= 0.0:
			var bodies = enemy_attack_area.get_overlapping_bodies()
			if player in bodies:
				start_attack_sequence()
				return

		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		_play_animation(ANIM_MOVE)
	else:
		stop_and_idle()

	move_and_slide()

func start_attack_sequence() -> void:
	if not animation_player or not animation_player.has_animation(ANIM_ATTACK):
		return
	is_attacking = true
	damage_inflicted_this_strike = false
	attack_elapsed_timer = 0.0
	attack_cooldown_timer = ATTACK_COOLDOWN
	_play_animation(ANIM_ATTACK)

func deal_damage_to_player() -> void:
	damage_inflicted_this_strike = true
	if enemy_attack_area:
		for body in enemy_attack_area.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(ATTACK_DAMAGE)

func stop_and_idle() -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED)
	velocity.z = move_toward(velocity.z, 0, SPEED)
	_play_animation(ANIM_IDLE)

func _play_animation(anim_name: String) -> void:
	if not animation_player:
		return
	if animation_player.current_animation == anim_name:
		return
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	if current_health <= 0:
		die()
	else:
		if not is_attacking and animation_player.has_animation("Hit"):
			animation_player.play("Hit")

func die() -> void:
	if is_dead:
		return
	is_dead = true
	enemy_died.emit()
	velocity = Vector3.ZERO

	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)

	if animation_player and animation_player.has_animation(ANIM_DEATH):
		_play_animation(ANIM_DEATH)
		await animation_player.animation_finished
		queue_free()
	else:
		queue_free()

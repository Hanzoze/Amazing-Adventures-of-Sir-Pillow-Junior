extends CharacterBody3D

signal enemy_died

@export var SPEED: float = 5.0
@export var ROTATION_SPEED: float = 10.0
@export var FLIP_ROTATION: bool = true

@export var max_health: float = 100.0
var current_health: float = max_health
var is_dead: bool = false

# Названия анимаций
const ANIM_MOVE: String = "Demon_Crawl/mixamo_com"
const ANIM_IDLE: String = "Demon_TPose/mixamo_com"
const ANIM_DEATH: String = "Death"
const ANIM_ATTACK: String = "Demon_attack1/mixamo_com"

# Настройки боевой логики
const ATTACK_COOLDOWN: float = 1.2
const ATTACK_DAMAGE: float = 10

# ИЗМЕНЕНО: Сколько секунд ДО КОНЦА анимации должно остаться, чтобы прошёл урон
# 0.1 — это практически самый финал удара. Можешь поставить 0.05 для максимальной точности.
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
	_check_animation_availability()
	
	# Убрали несуществующую функцию, оставив только прямую проверку плеера
	if animation_player and animation_player.has_animation(ANIM_IDLE):
		_play_animation(ANIM_IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# 1. ОБРАБОТКА ТЕКУЩЕЙ АТАКИ
	if is_attacking:
		attack_elapsed_timer += delta
		
		# Получаем чистую длину анимации напрямую из плеера (без хардкода!)
		var anim_length = animation_player.current_animation_length
		
		# Вычисляем динамический порог нанесения урона (например: 0.97 - 0.1 = 0.87 сек)
		var damage_trigger_time = anim_length - DAMAGE_WINDOW_BEFORE_END

		# Наносим урон строго под конец анимации
		if not damage_inflicted_this_strike and attack_elapsed_timer >= damage_trigger_time:
			print("[ДЕМОН] Таймер дошёл до финальной фазы (", attack_elapsed_timer, " из ", anim_length, " сек). Наносим урон!")
			deal_damage_to_player()

		# Завершаем атаку, когда таймер полностью дошёл до конца трека
		if attack_elapsed_timer >= anim_length:
			print("[ДЕМОН] Атака полностью завершена.")
			is_attacking = false
			attack_elapsed_timer = 0.0

		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	# 2. ЛОГИКА ПРЕСЛЕДОВАНИЯ И АТАКИ
	if player and is_instance_valid(player):
		if "is_dead" in player and player.is_dead:
			stop_and_idle()
			return

		var direction = (player.global_position - global_position)
		direction.y = 0
		direction = direction.normalized()

		# Поворот на игрока
		var target_look = global_position + direction
		if FLIP_ROTATION:
			target_look = global_position - direction
		var target_transform = global_transform.looking_at(target_look, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(
			target_transform.basis, ROTATION_SPEED * delta
		).orthonormalized()

		# Атака — только если игрок физически внутри EnemyAttackArea
		if enemy_attack_area and attack_cooldown_timer <= 0.0:
			var bodies = enemy_attack_area.get_overlapping_bodies()
			if player in bodies:
				print("[ДЕМОН] Игрок в зоне! Атакуем.")
				start_attack_sequence()
				return

		# Демон всегда идёт к игроку
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		_play_animation(ANIM_MOVE)
	else:
		stop_and_idle()

	move_and_slide()

func start_attack_sequence() -> void:
	if not animation_player:
		print("[ДЕМОН] ОШИБКА: AnimationPlayer не найден!")
		return
	if not animation_player.has_animation(ANIM_ATTACK):
		print("[ДЕМОН] ОШИБКА: Анимация '", ANIM_ATTACK, "' не найдена!")
		return

	print("[ДЕМОН] Инициативная атака!")
	is_attacking = true
	damage_inflicted_this_strike = false
	attack_elapsed_timer = 0.0
	attack_cooldown_timer = ATTACK_COOLDOWN
	_play_animation(ANIM_ATTACK)

func deal_damage_to_player() -> void:
	damage_inflicted_this_strike = true
	if enemy_attack_area:
		var targets = enemy_attack_area.get_overlapping_bodies()
		for body in targets:
			# Сюда физически не сможет попасть никто, кроме Player
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
	else:
		print("[ДЕМОН] Анимация не найдена: ", anim_name)

func _check_animation_availability() -> void:
	if not animation_player:
		return
	print("[ДЕМОН] Доступны анимации: ", animation_player.get_animation_list())

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	print("[ДЕМОН] Получил урон. Осталось HP: ", current_health)

	if current_health <= 0:
		die()
	else:
		if not is_attacking and animation_player.has_animation("Hit"):
			animation_player.play("Hit")

func die() -> void:
	if is_dead: 
		return
		
	is_dead = true
	
	# Отправляем сигнал менеджеру волн (он сам обновит HUD и уменьшит счетчик волны)
	enemy_died.emit()
	
	velocity = Vector3.ZERO
	print("[ДЕМОН] Начинает анимацию смерти.")

	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)

	if animation_player and animation_player.has_animation(ANIM_DEATH):
		_play_animation(ANIM_DEATH)
		await animation_player.animation_finished
		queue_free()
	else:
		queue_free()

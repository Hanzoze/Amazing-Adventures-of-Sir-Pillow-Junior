extends CanvasLayer

var health_bar: ProgressBar

func _ready() -> void:
	health_bar = $HealthBar
	$EnemiesCounterLabel.text = str(0)

func init_health(max_hp: float) -> void:
	if health_bar:
		health_bar.init_health(max_hp)

func update_health(new_hp: float) -> void:
	if health_bar:
		health_bar.health = new_hp

func _process(delta: float) -> void:
	pass

extends Control


func _ready():
	$ScoreLabel.text = str(Global.enemies_killed)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menu_title.tscn")

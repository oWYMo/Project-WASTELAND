extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("🏥 Zona final activada")
		Global.is_final_scene_active = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		Global.is_final_scene_active = false

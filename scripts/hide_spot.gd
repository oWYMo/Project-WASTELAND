extends Area2D

func _ready():
	print("HideSpot listo")

func _on_body_entered(body):
	print("Algo entró:", body.name)

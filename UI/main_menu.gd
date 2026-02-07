extends Control

@export var world_scene_path: String = "res://scenes/world.tscn"

func _ready():
	set_process_input(true)

func _input(event):
	#Si presiona ESC se sale del juego salir del juego
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if event is InputEventMouseButton and event.pressed:
		start_game()
	#Si presiona cualquier tecla (y no es ESC)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			return
		
		start_game()

func start_game():
	get_tree().change_scene_to_file(world_scene_path)

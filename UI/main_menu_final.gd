extends Control

# Este script es para la pantalla final (main_menu_final)
# Al presionar cualquier cosa, el juego se cierra.

func _ready():
	# Nos aseguramos de que el nodo pueda procesar la entrada
	set_process_input(true)

func _input(event):
	# Verificamos si el evento es presionar una tecla, un botón del mouse o del control
	var is_input = event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	
	# Si se presionó algo y no es un "eco" (tecla mantenida)
	if is_input and event.is_pressed() and not event.is_echo():
		exit_game()

func exit_game():
	# Cerramos el juego completamente
	get_tree().quit()

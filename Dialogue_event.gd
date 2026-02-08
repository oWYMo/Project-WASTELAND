extends Area2D

@export var dialogue_resource : DialogueResource
@export var start_node : String = "start"
@export var one_shot : bool = true
@export var require_interaction : bool = true
@export var pause_game_during_dialogue : bool = true
@export var block_movement_during_dialogue : bool = true

@onready var exclamation: AnimatedSprite2D = $Exclamation
@export var is_final_dialogue : bool = false # Activa esto solo en el último evento
@export_file("*.tscn") var next_scene_path : String = "res://UI/main_menu_final.tscn"
var activated := false
var player_inside := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if exclamation:
		exclamation.visible = false


func _process(_delta):
	if require_interaction:
		if player_inside and Input.is_action_just_pressed("take_item") and not activated:
			_trigger_dialogue()


func _on_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true
		
		if require_interaction and not activated:
			_show_icon()
		
		if not require_interaction and not activated:
			_trigger_dialogue()


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false
		_hide_icon()


func _trigger_dialogue():
	if block_movement_during_dialogue:
		Global.is_dialogue_active = true
	Global.chose_run = false
	DialogueManager.show_dialogue_balloon(dialogue_resource, start_node)
	# ⏳ Esperar a que el diálogo termine
	await DialogueManager.dialogue_ended
	if block_movement_during_dialogue:
		Global.is_dialogue_active = false
	if one_shot:
		activated = true
	_hide_icon()
		# Caso 1: Es el diálogo final
	if is_final_dialogue:
		get_tree().change_scene_to_file(next_scene_path)
		return # Salimos para que no ejecute lo demás

	# Caso 2: El jugador eligió "Run" en el penúltimo diálogo
	if Global.chose_run:
		await get_tree().create_timer(3.0).timeout # Espera un segundo antes de cambiar
		get_tree().change_scene_to_file(next_scene_path)



	
func _show_icon():
	if exclamation:
		exclamation.visible = true
		exclamation.play()


func _hide_icon():
	if exclamation:
		exclamation.visible = false
		exclamation.stop()

extends Area2D

@export var dialogue_resource : DialogueResource
@export var start_node : String = "start"
@export var one_shot : bool = true
@export var require_interaction : bool = true
@export var pause_game_during_dialogue : bool = true
@export var block_movement_during_dialogue : bool = true

@onready var exclamation: AnimatedSprite2D = $Exclamation

var activated := false
var player_inside := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if exclamation:
		exclamation.visible = false


func _process(_delta):
	if require_interaction:
		if player_inside and Input.is_action_just_pressed("interact") and not activated:
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
	
	DialogueManager.show_dialogue_balloon(dialogue_resource, start_node)

	if one_shot:
		activated = true
	
	_hide_icon()


# 🔥 Esta función detecta cuando el diálogo ya no está en pantalla
func _wait_for_dialogue_to_close():
	while DialogueManager.is_dialogue_active():
		await get_tree().process_frame
		
func _show_icon():
	if exclamation:
		exclamation.visible = true
		exclamation.play()


func _hide_icon():
	if exclamation:
		exclamation.visible = false
		exclamation.stop()

extends Node2D


func _ready():
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_ended(_resource):
	Global.is_dialogue_active = false

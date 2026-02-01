extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var speed: float = 100
var last_direction = "down"

func _physics_process(delta):
	get_input()
	move_and_slide()

func get_input():
	var input_direction = Input.get_vector("move_left","move_right","move_up","move_down")
	
	if input_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		update_animation("idle")
	
	if abs(input_direction.x) > abs(input_direction.y):
		# Movimiento Horizontal
		if input_direction.x > 0:
			last_direction = "right"
		elif input_direction.x < 0:
			last_direction = "left"
	else :
		# Movimiento Vertical
		if input_direction.y > 0:
			last_direction = "down"
		elif input_direction.y < 0:
			last_direction = "up"
	velocity = input_direction * speed
	update_animation("run")

func update_animation(state):
	animated_sprite_2d.play(state + "_" + last_direction)

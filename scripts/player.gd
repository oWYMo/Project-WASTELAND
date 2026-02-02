extends CharacterBody2D

### Items y detección #########################################################
var boxes: int = 3
var used_box: bool = false
var keys: int = 0
var potions: int = 0
var item_nearby: Area2D = null
var item_type: String = ""

### Vida y daño ###############################################################
var life: int = 10
var max_life: int = 10

### Movimiento ################################################################
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var speed: float = 100
var base_speed: float = 100
var last_direction = "down"

### Physics Process ###########################################################
func _physics_process(delta):
	handle_box_input()
	handle_item_pickup()
	handle_potion_use()
	get_input()
	move_and_slide()

### Input del jugador #########################################################
func get_input():
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		update_animation("idle")
		return
	
	if abs(input_direction.x) > abs(input_direction.y):
		if input_direction.x > 0:
			last_direction = "right"
		elif input_direction.x < 0:
			last_direction = "left"
	else:
		if input_direction.y > 0:
			last_direction = "down"
		elif input_direction.y < 0:
			last_direction = "up"
	
	update_animation("run")
	velocity = input_direction * speed

### Manejo de cajas ###########################################################
func handle_box_input():
	if Input.is_action_just_pressed("use_box") and boxes > 0:
		toggle_box()

func toggle_box():
	if used_box:
		used_box = false
		speed = base_speed
		boxes -= 1
		print("Caja quitada. Cajas restantes: ", boxes, " | used_box: ", used_box)
	else:
		used_box = true
		speed = base_speed / 2
		print("Caja puesta. | used_box: ", used_box)

### Recoger items #############################################################
func handle_item_pickup():
	if item_nearby != null and Input.is_action_just_pressed("take_item"):
		match item_type:
			"key":
				keys += 1
				print("Llaves recogidas: ", keys)
			"box":
				boxes += 1
				print("Cajas recogidas: ", boxes)
			"potion":
				potions += 1
				print("Pociones recogidas: ", potions)
		
		item_nearby.queue_free()
		item_nearby = null
		item_type = ""

### Usar pociones #############################################################
func handle_potion_use():
	if Input.is_action_just_pressed("use_poti") and potions > 0:
		use_potion()

func use_potion():
	if life < max_life:
		potions -= 1
		life = min(life + 3, max_life)
		print("Poción usada. Vida: ", life, " | Pociones restantes: ", potions)
	else:
		print("Vida completa, no necesitas curación")

### Actualizar animación ######################################################
func update_animation(state):
	if life <= 0:
		animated_sprite_2d.play("use_dead")
		_on_animated_sprite_2d_animation_finished()
		return
	
	if used_box:
		animated_sprite_2d.play("use_box")
	else:
		animated_sprite_2d.play(state + "_" + last_direction)

### Señales de daño ###########################################################
func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Si tiene la caja puesta, no recibe daño
	if used_box:
		print("La caja te protege del daño")
		return
	
	life -= 1
	print("Vida restante: ", life)

func _on_animated_sprite_2d_animation_finished() -> void:
	if life <= 0:
		queue_free()

### Señales de detección de items #############################################
func _on_huntbox_for_items_area_entered(area: Area2D) -> void:
	item_nearby = area
	
	if area.is_in_group("keys"):
		item_type = "key"
	elif area.is_in_group("boxes"):
		item_type = "box"
	elif area.is_in_group("potions"):
		item_type = "potion"
	
	print("Item cercano: ", item_type)

func _on_huntbox_for_items_area_exited(area: Area2D) -> void:
	if item_nearby == area:
		item_nearby = null
		item_type = ""
		print("El item se alejó")
		
		
# ===== NUEVO: Sistema de daño mejorado =====
func take_damage(amount: int) -> void:
	if used_box:
		print("🛡️ ¡Estás a salvo en la caja! Daño bloqueado.")
		return
	
	life -= amount
	print("💔 Recibiste ", amount, " de daño. Vida restante: ", life)
	
	if life <= 0:
		die()

func die() -> void:
	print("💀 ¡Has muerto!")
	animated_sprite_2d.play("use_dead")
	set_process(false)  # Detener lógica del jugador
	# Opcional: Reiniciar nivel o mostrar pantalla de game over
	await animated_sprite_2d.animation_finished
	queue_free()

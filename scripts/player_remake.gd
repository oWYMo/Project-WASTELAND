extends CharacterBody2D

### Items y detección #########################################################
@export var boxes: int = 3
@export var keys: int = 0
@export var potions: int = 0
var used_box: bool = false
var item_nearby: Area2D = null
var item_type: String = ""

### Vida y daño ###############################################################
@export var life: int = 10
@export var max_life: int = 10
var is_immune: bool = false  # Inmunidad activa
@export var immunity_duration: float = 1.0  # Duración de la inmunidad
@export var enemy_layer: int = 2  # El número de layer donde están los enemigos
var enemies_touching: Array = []  # Array de enemigos que están tocando

### Movimiento ################################################################
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var speed: float = 100
var base_speed: float = 100
var last_direction = "down"

### Physics Process ###########################################################
func _physics_process(_delta):
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
		print("Caja puesta. Modo stealth activado | used_box: ", used_box)

### Recoger items #############################################################
func handle_item_pickup():
	# No puede recoger items mientras está en la caja
	if used_box:
		return
	
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
	# No puede usar pociones mientras está en la caja
	if used_box:
		return
	
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
		return  # No actualizar animación si está muerto
	
	if used_box:
		animated_sprite_2d.play("use_box")
	else:
		animated_sprite_2d.play(state + "_" + last_direction)

### Sistema de daño mejorado ##################################################
func _on_huntbox_enemy_area_entered(area: Area2D) -> void:
	# Detectar si está en el layer de enemigos
	if area.collision_layer & (1 << (enemy_layer - 1)):
		if not area in enemies_touching:
			enemies_touching.append(area)
			print("⚔️ Enemigo entró en contacto")
			# Hacer daño inmediato al entrar SOLO si no es inmune
			if not is_immune:
				take_damage(1)

func _on_huntbox_enemy_area_exited(area: Area2D) -> void:
	# Remover enemigo de la lista cuando se aleja
	if area in enemies_touching:
		enemies_touching.erase(area)
		print("🏃 Enemigo se alejó")

func take_damage(amount: int) -> void:
	if is_immune or life <= 0:
		return
	
	life -= amount
	print("💔 Recibiste ", amount, " de daño. Vida restante: ", life)
	
	if life <= 0:
		die()
		return
	
	# Activar inmunidad
	is_immune = true
	print("🛡️ Inmunidad activada por ", immunity_duration, " segundo(s)")
	
	# Después de la inmunidad, verificar si sigue habiendo enemigos
	await get_tree().create_timer(immunity_duration).timeout
	is_immune = false
	print("⚔️ Inmunidad terminada")
	
	# Si todavía hay enemigos tocando, volver a hacer daño
	if enemies_touching.size() > 0:
		take_damage(1)

func die() -> void:
	print("💀 ¡Has muerto!")
	animated_sprite_2d.play("use_dead")
	set_physics_process(false)  # Detener toda la lógica del jugador
	await animated_sprite_2d.animation_finished
	queue_free()

### Señales de detección de items #############################################
func _on_huntbox_item_area_entered(area: Area2D) -> void:
	item_nearby = area
	
	if area.is_in_group("keys"):
		item_type = "key"
	elif area.is_in_group("boxes"):
		item_type = "box"
	elif area.is_in_group("potions"):
		item_type = "potion"
	
	print("Item cercano: ", item_type)

func _on_huntbox_item_area_exited(area: Area2D) -> void:
	if item_nearby == area:
		item_nearby = null
		item_type = ""
		print("El item se alejó")

### Función pública para que los enemigos chequen detección ##################
func is_detectable() -> bool:
	# Los enemigos deben llamar esta función para saber si pueden detectarte
	return not used_box

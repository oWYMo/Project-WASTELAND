extends CharacterBody2D

################################################################################
# DIALOGOS
################################################################################
@onready var box_dialogue = preload("res://docs/dialogues/box_dialogue.dialogue")
@onready var key_dialogue = preload("res://docs/dialogues/key_dialogue.dialogue")
@onready var potion_dialogue = preload("res://docs/dialogues/potion_dialogue.dialogue")
@onready var bell_dialogue = preload("res://docs/dialogues/bell_dialogue.dialogue")

################################################################################
# VARIABLES DE ITEMS Y DETECCIÓN
################################################################################
@export var boxes: int = 3
@export var keys: int = 0
@export var potions: int = 0

var used_box: bool = false
var item_nearby: Area2D = null
var item_type: String = ""
var hide_spot_nearby: Area2D = null
var is_hidden_in_spot: bool = false
var door_nearby: Area2D = null


################################################################################
# VARIABLES DE VIDA Y DAÑO
################################################################################
@export var life: int = 12
@export var max_life: int = 12
@export var immunity_duration: float = 1.0  # Segundos de inmunidad después de recibir daño
@export var knockback_distance: float = 15.0  # Distancia que se empuja al jugador al recibir daño (evita quedar pegado)
@export var enemy_layer: int = 2  # Layer de colisión donde están los enemigos

var is_immune: bool = false  # Si el jugador está en inmunidad temporal
var damage_timer: Timer = null  # Timer que verifica si hay enemigos tocando

# Barra de vida: 3 corazones (Healt_bar), 4 de daño por corazón perdido
var heart_sprites: Array[AnimatedSprite2D] = []
var active_hearts: int = 3  # Cuántos corazones están visibles (0–3)
var damage_since_last_heart: int = 0
@onready var box_count_label: Label = $Box_bar/BoxUI/BoxCount
################################################################################
# VARIABLES DE MOVIMIENTO
################################################################################
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 100
var base_speed: float = 100
var last_direction: String = "down"

################################################################################
# INICIALIZACIÓN
################################################################################
func _ready():
	#Crear y configurar el timer de daño
	damage_timer = Timer.new()
	damage_timer.wait_time = immunity_duration  # Revisa cada X segundos
	damage_timer.one_shot = false  # Se repite continuamente
	damage_timer.timeout.connect(_on_damage_timer_timeout) 
	add_child(damage_timer)

	#Se duplican los corazones
	var healt_bar = $Healt_bar
	var heart1 = healt_bar.get_node("Heart1")
	heart_sprites = [heart1]
	var heart_scale_multiplier := 2  #TAÑON
	heart1.scale *= heart_scale_multiplier
	var viewport_size = get_viewport_rect().size
	var heart_positions = [
		Vector2(viewport_size.x - 180, 35),
		Vector2(viewport_size.x - 120, 35),
		Vector2(viewport_size.x - 60, 35)
	]
	heart1.position = heart_positions[0]
	for i in range(2):
		var clone = heart1.duplicate() as AnimatedSprite2D
		healt_bar.add_child(clone)
		clone.position = heart_positions[i + 1]
		clone.scale = heart1.scale
		heart_sprites.append(clone)
	for heart in heart_sprites:
		heart.frame = 0
		heart.stop()
	var box_ui = $Box_bar/BoxUI
	box_ui.anchor_left = 0
	box_ui.anchor_top = 0
	box_ui.anchor_right = 0
	box_ui.anchor_bottom = 0
	box_ui.offset_left = 80
	box_ui.offset_top = 35
	update_box_ui()

################################################################################
# PROCESO PRINCIPAL (CADA FRAME)
################################################################################
func _physics_process(_delta):
	handle_box_input()      # Manejar entrar/salir de la caja
	handle_item_pickup()    # Manejar recoger items
	handle_potion_use()     # Manejar usar pociones
	get_input()             # Obtener input del jugador y mover
	move_and_slide()        # Aplicar el movimiento

################################################################################
# SISTEMA DE MOVIMIENTO
################################################################################
func get_input():
	if is_hidden_in_spot:
		velocity = Vector2.ZERO
		return
	# Obtener dirección del input (WASD o flechas)
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Si no hay input, detener y mostrar idle
	if input_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		update_animation("idle")
		return
	
	# Determinar última dirección basado en el input dominante
	if abs(input_direction.x) > abs(input_direction.y):
		# Movimiento horizontal es dominante
		if input_direction.x > 0:
			last_direction = "right"
		elif input_direction.x < 0:
			last_direction = "left"
	else:
		# Movimiento vertical es dominante
		if input_direction.y > 0:
			last_direction = "down"
		elif input_direction.y < 0:
			last_direction = "up"
	
	# Actualizar animación y velocidad
	update_animation("run")
	velocity = input_direction * speed

func update_animation(state):
	if is_hidden_in_spot:
		return
	if life <= 0:
		return  # No actualizar animación si está muerto
	
	if used_box:
		# Mostrar animación de caja
		animated_sprite_2d.play("use_box")
	else:
		# Mostrar animación según estado y dirección (ej: "run_down", "idle_up")
		animated_sprite_2d.play(state + "_" + last_direction)

################################################################################
# SISTEMA DE CAJAS (STEALTH)
################################################################################
func handle_box_input():
	#ESCONDERSE EN COSAS RAMDON
	# 🔹 PRIORIDAD: ESCONDITE
	if Input.is_action_just_pressed("take_item") and hide_spot_nearby and not is_hidden_in_spot:
		enter_hide_spot()
		return
	
	# 🔹 SALIR DEL ESCONDITE
	if is_hidden_in_spot:
		var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_direction != Vector2.ZERO:
			exit_hide_spot(input_direction)
		return
	
	if Input.is_action_just_pressed("use_box") and boxes > 0:
		toggle_box()

func toggle_box():
	if used_box:
		# Salir de la caja
		used_box = false
		speed = base_speed  # Restaurar velocidad normal
		boxes -= 1  # Consumir una caja
		update_box_ui()
		print("Caja quitada. Cajas restantes: ", boxes)
	else:
		# Entrar en la caja
		used_box = true
		speed = base_speed / 2  # Reducir velocidad a la mitad
		print("Caja puesta. Modo stealth activado")

func is_detectable() -> bool:
	# Los enemigos llaman esta función para saber si pueden ver al jugador
	return not used_box

func update_box_ui():
	box_count_label.text = "x" + str(boxes)

################################################################################
# SISTEMA DE ITEMS
################################################################################
func handle_item_pickup():

	# No puede recoger items mientras está en la caja
	if used_box:
		return
	
	# Usar llave en puerta
	if door_nearby != null and keys > 0 and Input.is_action_just_pressed("use_key"):
		if door_nearby.open():
			keys -= 1
			print("Llave usada en la puerta. Llaves restantes: ", keys)
		return

	# Recoger objetos
	if Input.is_action_just_pressed("take_item"):

		var areas = $huntbox_item.get_overlapping_areas()

		for area in areas:

			# Verificamos que no sea null (seguridad extra)
			if area == null:
				continue

			if area.is_in_group("boxes"):

				DialogueManager.show_dialogue_balloon(box_dialogue, "start")

				boxes += 1
				update_box_ui()

			elif area.is_in_group("keys"):

				DialogueManager.show_dialogue_balloon(key_dialogue, "start")

				keys += 1

			elif area.is_in_group("potions"):

				DialogueManager.show_dialogue_balloon(potion_dialogue, "start")

				potions += 1

			elif area.is_in_group("bell"):

				DialogueManager.show_dialogue_balloon(bell_dialogue, "start")

			else:
				continue  # Si no pertenece a ningún grupo válido, lo ignoramos

			# Eliminamos el objeto después de recogerlo
			area.queue_free()
			break



func _on_huntbox_item_area_entered(area: Area2D) -> void:
	print("Entró algo al huntbox:", area.name)
	print("Grupos del area:", area.get_groups())
	# Prioridad: escondites
	if area.is_in_group("hide_spots"):
		hide_spot_nearby = area
		return
	# Puerta (zona desbloqueable con llave)
	if area.is_in_group("door"):
		door_nearby = area
		return
	# Detectar qué tipo de item está cerca
	item_nearby = area
	
	if area.is_in_group("keys"):
		item_type = "key"
	elif area.is_in_group("boxes"):
		item_type = "box"
	elif area.is_in_group("potions"):
		item_type = "potion"
	
	print("Item cercano: ", item_type)

func _on_huntbox_item_area_exited(area: Area2D) -> void:
	if area == hide_spot_nearby:
		hide_spot_nearby = null
		return
	if area == door_nearby:
		door_nearby = null
		return
	
	# El item se alejó del rango
	if item_nearby == area:
		item_nearby = null
		item_type = ""
		print("El item se alejó")

################################################################################
# SISTEMA DE POCIONES
################################################################################
func handle_potion_use():
	# No puede usar pociones mientras está en la caja
	if used_box:
		return
	
	if Input.is_action_just_pressed("use_poti") and potions > 0:
		heal()

## Cura 4 de vida y muestra un corazón de nuevo. No hace nada si life >= max_life (p. ej. 12).
func heal() -> void:
	if life >= max_life:
		print("Vida completa, no necesitas curación")
		return
	if potions <= 0:
		return
	potions -= 1
	life = min(life + 4, max_life)
	# Mostrar de nuevo un corazón (frame 0, sin animación = "Heart")
	if active_hearts < heart_sprites.size():
		var heart = heart_sprites[active_hearts]
		heart.visible = true
		heart.frame = 0
		heart.stop()
		active_hearts += 1
	print("Poción usada. Vida: ", life, " | Pociones restantes: ", potions)

################################################################################
# SISTEMA DE DAÑO Y MUERTE
################################################################################

# PASO 1: Enemigo entra en contacto
func _on_huntbox_enemy_area_entered(area: Area2D) -> void:
	# Verificar si el área pertenece a un enemigo (revisando su collision layer)
	if area.collision_layer & (1 << (enemy_layer - 1)):
		print("⚔️ Enemigo detectado en área: ", area.name)
		
		# Hacer daño inmediato si no está inmune (posición del enemigo para knockback)
		if not is_immune:
			take_damage(area.global_position)
		
		# Iniciar el timer de verificación continua
		if damage_timer.is_stopped():
			damage_timer.start()
			print("⏰ Timer de daño iniciado")

# PASO 2: Enemigo sale del contacto
func _on_huntbox_enemy_area_exited(area: Area2D) -> void:
	# Verificar que sea un enemigo
	if area.collision_layer & (1 << (enemy_layer - 1)):
		print("🏃 Enemigo salió del área: ", area.name)
		
		# Esperar un frame para que las áreas se actualicen
		await get_tree().process_frame
		
		# Revisar si todavía hay otros enemigos tocando
		var areas_in_huntbox = $huntbox_enemy.get_overlapping_areas()
		var enemy_still_present = false
		
		for overlap_area in areas_in_huntbox:
			if overlap_area.collision_layer & (1 << (enemy_layer - 1)):
				enemy_still_present = true
				print("   ⚠️ Todavía hay enemigo: ", overlap_area.name)
				break
		
		# Si no quedan enemigos, detener el timer
		if not enemy_still_present:
			damage_timer.stop()
			print("✅ No quedan enemigos, timer detenido")

# PASO 3: Verificación periódica del timer
func _on_damage_timer_timeout():
	# Obtener todas las áreas que están tocando al jugador
	var areas_in_huntbox = $huntbox_enemy.get_overlapping_areas()
	var enemy_present = false
	
	# Revisar si alguna de esas áreas es un enemigo
	for area in areas_in_huntbox:
		if area.collision_layer & (1 << (enemy_layer - 1)):
			enemy_present = true
			print("♻️ Timer detectó enemigo: ", area.name)
			break
	
	# Si hay enemigo y no está inmune, hacer daño (con knockback para no quedar pegado)
	if enemy_present and not is_immune:
		var enemy_area: Area2D = null
		for a in areas_in_huntbox:
			if a.collision_layer & (1 << (enemy_layer - 1)):
				enemy_area = a
				break
		take_damage(enemy_area.global_position if enemy_area else Vector2.ZERO)
	elif not enemy_present:
		# Si no hay enemigo, detener el timer
		print("✅ Timer: No hay enemigos, deteniendo timer")
		damage_timer.stop()

# PASO 4: Aplicar daño (source_position = posición del enemigo para knockback y no quedar pegado)
func take_damage(source_position: Vector2 = Vector2.ZERO) -> void:
	if is_immune or life <= 0:
		return
	
	# Empujar al jugador lejos del enemigo para evitar quedar pegado
	if source_position != Vector2.ZERO:
		var knockback_dir = (global_position - source_position).normalized()
		global_position += knockback_dir * knockback_distance
	
	life -= 4
	damage_since_last_heart += 4
	print("💔 Recibiste 4 de daño. Vida restante: ", life)

	# Cada 4 de daño: animación Damage_Heart en un corazón y luego se oculta
	if damage_since_last_heart >= 4 and active_hearts > 0:
		damage_since_last_heart = 0
		active_hearts -= 1
		var heart = heart_sprites[active_hearts]
		heart.sprite_frames.set_animation_loop("Damage_Heart", false)
		heart.animation_finished.connect(_on_damage_heart_finished.bind(heart), CONNECT_ONE_SHOT)
		heart.play("Damage_Heart")
	
	if life <= 0:
		die()
		return
	
	# Activar inmunidad
	is_immune = true
	print("🛡️ Inmunidad activada por ", immunity_duration, " segundo(s)")
	
	# Reiniciar timer para sincronizar
	damage_timer.start()
	
	# Esperar inmunidad
	await get_tree().create_timer(immunity_duration).timeout
	is_immune = false
	print("⚔️ Inmunidad terminada - Listo para recibir daño")


func _on_damage_heart_finished(heart: AnimatedSprite2D) -> void:
	heart.sprite_frames.set_animation_loop("Damage_Heart", true)  # Restaurar loop para la escena
	heart.visible = false
	heart.frame = 0
	heart.stop()

func die() -> void:
	print("💀 ¡Has muerto!")
	damage_timer.stop()  # Detener el timer de daño
	animated_sprite_2d.play("use_dead")  # Mostrar animación de muerte
	set_physics_process(false)  # Detener toda la lógica del jugador
	await animated_sprite_2d.animation_finished  # Esperar a que termine la animación
	queue_free()  # Eliminar al jugador de la escena

################################################################################
#Sistema de ESCONDITES
################################################################################
func enter_hide_spot():
	if not hide_spot_nearby:
		return
	
	# Buscar enemigo oculto dentro del hide_spot
	for child in hide_spot_nearby.get_children():
		if child.is_in_group("hidden_enemy"):
			# Si hay enemigo escondido → despertarlo
			child.wake_up()
			print("⚠️ Intentaste esconderte... pero no estabas solo.")
			return
	
	#Si no hay enemigo → esconderse normal
	var shape = hide_spot_nearby.get_node_or_null("CollisionShape2D")
	if shape:
		global_position = shape.global_position
	else:
		global_position = hide_spot_nearby.global_position
	
	is_hidden_in_spot = true
	used_box = true
	velocity = Vector2.ZERO
	animated_sprite_2d.visible = false
	
	print("El jugador se escondió")

func exit_hide_spot(direction: Vector2):
	is_hidden_in_spot = false
	used_box = false
	animated_sprite_2d.visible = true
	
	# Salir un poco hacia la dirección presionada
	global_position += direction.normalized() * 20
	
	print("Saliste de la chingadera")

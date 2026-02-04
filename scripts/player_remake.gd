extends CharacterBody2D

################################################################################
# VARIABLES DE ITEMS Y DETECCIÓN
################################################################################
@export var boxes: int = 3
@export var keys: int = 0
@export var potions: int = 0

var used_box: bool = false
var item_nearby: Area2D = null
var item_type: String = ""

################################################################################
# VARIABLES DE VIDA Y DAÑO
################################################################################
@export var life: int = 10
@export var max_life: int = 10
@export var immunity_duration: float = 1.0  # Segundos de inmunidad después de recibir daño
@export var enemy_layer: int = 2  # Layer de colisión donde están los enemigos

var is_immune: bool = false  # Si el jugador está en inmunidad temporal
var damage_timer: Timer = null  # Timer que verifica si hay enemigos tocando

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
	# Crear y configurar el timer de daño
	damage_timer = Timer.new()
	damage_timer.wait_time = immunity_duration  # Revisa cada X segundos
	damage_timer.one_shot = false  # Se repite continuamente
	damage_timer.timeout.connect(_on_damage_timer_timeout)  # Conectar señal
	add_child(damage_timer)

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
	if Input.is_action_just_pressed("use_box") and boxes > 0:
		toggle_box()

func toggle_box():
	if used_box:
		# Salir de la caja
		used_box = false
		speed = base_speed  # Restaurar velocidad normal
		boxes -= 1  # Consumir una caja
		print("Caja quitada. Cajas restantes: ", boxes)
	else:
		# Entrar en la caja
		used_box = true
		speed = base_speed / 2  # Reducir velocidad a la mitad
		print("Caja puesta. Modo stealth activado")

func is_detectable() -> bool:
	# Los enemigos llaman esta función para saber si pueden ver al jugador
	return not used_box

################################################################################
# SISTEMA DE ITEMS
################################################################################
func handle_item_pickup():
	# No puede recoger items mientras está en la caja
	if used_box:
		return
	
	if item_nearby != null and Input.is_action_just_pressed("take_item"):
		# Recoger item según su tipo
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
		
		# Eliminar el item del mundo
		item_nearby.queue_free()
		item_nearby = null
		item_type = ""

func _on_huntbox_item_area_entered(area: Area2D) -> void:
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
		use_potion()

func use_potion():
	if life < max_life:
		potions -= 1
		life = min(life + 3, max_life)  # Curar 3 de vida sin exceder el máximo
		print("Poción usada. Vida: ", life, " | Pociones restantes: ", potions)
	else:
		print("Vida completa, no necesitas curación")

################################################################################
# SISTEMA DE DAÑO Y MUERTE
################################################################################

# PASO 1: Enemigo entra en contacto
func _on_huntbox_enemy_area_entered(area: Area2D) -> void:
	# Verificar si el área pertenece a un enemigo (revisando su collision layer)
	if area.collision_layer & (1 << (enemy_layer - 1)):
		print("⚔️ Enemigo detectado en área: ", area.name)
		
		# Hacer daño inmediato si no está inmune
		if not is_immune:
			take_damage()
		
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
	
	# Si hay enemigo y no está inmune, hacer daño
	if enemy_present and not is_immune:
		print("♻️ Timer: Enemigo presente, aplicando daño")
		take_damage()
	elif not enemy_present:
		# Si no hay enemigo, detener el timer
		print("✅ Timer: No hay enemigos, deteniendo timer")
		damage_timer.stop()

# PASO 4: Aplicar daño
func take_damage() -> void:
	if is_immune or life <= 0:
		return
	
	life -= 1
	print("💔 Recibiste 1 de daño. Vida restante: ", life)
	
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

func die() -> void:
	print("💀 ¡Has muerto!")
	damage_timer.stop()  # Detener el timer de daño
	animated_sprite_2d.play("use_dead")  # Mostrar animación de muerte
	set_physics_process(false)  # Detener toda la lógica del jugador
	await animated_sprite_2d.animation_finished  # Esperar a que termine la animación
	queue_free()  # Eliminar al jugador de la escena

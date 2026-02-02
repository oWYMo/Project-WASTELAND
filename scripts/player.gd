extends CharacterBody2D

### Items y detección #########################################################
var boxes: int = 3  # Cantidad de cajas disponibles en el inventario
var used_box: bool = false  # Indica si actualmente el jugador tiene una caja puesta
var keys: int = 0  # Cantidad de llaves en el inventario
var item_nearby: Area2D = null  # Guarda referencia al item cercano (null = no hay item cerca)

### Vida y daño ###############################################################
var life: int = 10  # Puntos de vida del jugador

### Movimiento ################################################################
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D  # Referencia al nodo de animación
var speed: float = 100  # Velocidad actual del jugador
var base_speed: float = 100  # Velocidad base sin modificadores (para restaurar después)
var last_direction = "down"  # Última dirección en la que se movió el jugador

### Physics Process ###########################################################
func _physics_process(delta):
	# Se ejecuta cada frame de física (60 veces por segundo normalmente)
	handle_box_input()  # Revisa si el jugador presionó la tecla para usar/quitar caja
	handle_item_pickup()  # Revisa si el jugador presionó la tecla para recoger item
	get_input()  # Obtiene el input de movimiento del jugador
	move_and_slide()  # Mueve al personaje según la velocidad calculada

### Input del jugador #########################################################
func get_input():
	# Obtiene la dirección del input como un vector normalizado
	# "move_left", "move_right", "move_up", "move_down" son las acciones definidas en Input Map
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Si no hay input (el jugador no está presionando ninguna tecla de movimiento)
	if input_direction == Vector2.ZERO:
		velocity = Vector2.ZERO  # Detiene el movimiento
		update_animation("idle")  # Cambia a animación de idle (parado)
		return  # Sale de la función
	
	# Determina la dirección basándose en qué componente del vector es mayor
	if abs(input_direction.x) > abs(input_direction.y):
		# Si el movimiento horizontal es mayor que el vertical
		if input_direction.x > 0:
			last_direction = "right"  # Se mueve a la derecha
		elif input_direction.x < 0:
			last_direction = "left"  # Se mueve a la izquierda
	else:
		# Si el movimiento vertical es mayor o igual que el horizontal
		if input_direction.y > 0:
			last_direction = "down"  # Se mueve hacia abajo
		elif input_direction.y < 0:
			last_direction = "up"  # Se mueve hacia arriba
	
	update_animation("run")  # Cambia a animación de correr
	velocity = input_direction * speed  # Calcula la velocidad multiplicando dirección por velocidad

### Manejo de cajas ###########################################################
func handle_box_input():
	# Revisa si se presionó la tecla para usar caja Y si hay cajas disponibles
	if Input.is_action_just_pressed("use_box") and boxes > 0:
		toggle_box()  # Activa/desactiva la caja

func toggle_box():
	# Alterna entre ponerse y quitarse la caja
	if used_box:
		# Si ya tiene la caja puesta, se la quita
		used_box = false  # Marca que ya no tiene caja puesta
		speed = base_speed  # Restaura la velocidad normal
		boxes -= 1  # Descuenta una caja del inventario (solo cuando se quita)
		print("Caja quitada. Cajas restantes: ", boxes, " | used_box: ", used_box)
	else:
		# Si no tiene caja puesta, se la pone
		used_box = true  # Marca que ahora tiene caja puesta
		speed = base_speed / 2  # Reduce la velocidad a la mitad
		print("Caja puesta. | used_box: ", used_box)

### Recoger items #############################################################
func handle_item_pickup():
	# Revisa si hay un item cerca Y si se presionó la tecla para recogerlo
	if item_nearby != null and Input.is_action_just_pressed("take_item"):
		keys += 1  # Incrementa el contador de llaves
		print("Actualmente tienes: ", keys, " llaves")
		item_nearby.queue_free()  # Elimina el item de la escena
		item_nearby = null  # Limpia la referencia (ya no hay item cerca)

### Actualizar animación ######################################################
func update_animation(state):
	# Actualiza la animación según el estado del jugador
	
	# Prioridad 1: Si está muerto, solo muestra animación de muerte
	if life <= 0:
		animated_sprite_2d.play("use_dead")
		_on_animated_sprite_2d_animation_finished()
		return  # Sale para no ejecutar otras animaciones
	
	# Prioridad 2: Si tiene caja puesta, muestra animación de caja
	if used_box:
		animated_sprite_2d.play("use_box")
	else:
		# Prioridad 3: Animación normal según estado (idle/run) y dirección
		# Ejemplo: "run_down", "idle_left", etc.
		animated_sprite_2d.play(state + "_" + last_direction)

### Señales de daño ###########################################################
func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Se ejecuta cuando algo entra al área de daño del jugador
	life -= 1  # Reduce la vida en 1
	print("Vida restante: ", life)

func _on_animated_sprite_2d_animation_finished() -> void:
	# Se ejecuta cuando una animación termina de reproducirse
	if life <= 0:
		queue_free()  # Elimina al jugador de la escena si murió

### Señales de detección de items #############################################
func _on_huntbox_for_items_area_entered(area: Area2D) -> void:
	# Se ejecuta cuando un item entra al rango de detección del jugador
	item_nearby = area  # Guarda la referencia del item que está cerca
	print("Hay un item cerca")

func _on_huntbox_for_items_area_exited(area: Area2D) -> void:
	# Se ejecuta cuando el item sale del rango de detección del jugador
	if item_nearby == area:  # Verifica que sea el mismo item que teníamos guardado
		item_nearby = null  # Limpia la referencia (ya no hay item cerca)
		print("El item se alejó")

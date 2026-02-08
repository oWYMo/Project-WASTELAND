extends CharacterBody2D

@export var speed: float = 100.0
@export var patrol_speed: float = 50.0
@export var vision_range: float = 200.0  # Rango de visión inicial
@export var patrol_duration: float = 2.0  # Tiempo caminando en una dirección
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@export var start_hidden: bool = false

var is_hidden_enemy: bool = false
var player
var is_chasing: bool = false
var is_patrolling: bool = false
var patrol_target: Vector2
var last_known_position: Vector2
var patrol_timer: float = 0.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	call_deferred("actor_setup")
	if start_hidden:
		setup_hidden_enemy()

func setup_hidden_enemy():
	is_hidden_enemy = true
	visible = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	if has_node("hitbox"):
		$hitbox.monitoring = false
		$hitbox.monitorable = false


func wake_up():
	if not is_hidden_enemy:
		return
	
	print("💀 Algo salió del escondite... el chamuco w")
	
	is_hidden_enemy = false
	visible = true
	set_physics_process(true)
	
	if has_node("hitbox"):
		$hitbox.monitoring = true
		$hitbox.monitorable = true
	
	#Empieza persiguiendo directamente
	is_chasing = true
	is_patrolling = false

func actor_setup():
	await get_tree().physics_frame
	start_patrolling()

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	check_player_visibility()
	
	if is_chasing:
		chase_player()
	elif is_patrolling:
		patrol(delta)
	if Global.is_dialogue_active:
		velocity = Vector2.ZERO
		return

func check_player_visibility() -> void:
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Si NO está persiguiendo, verificar si entra en rango de visión
	if not is_chasing:
		if distance_to_player <= vision_range and player.is_detectable():
			print("👁️ ¡Jugador detectado!")
			is_chasing = true
			is_patrolling = false
	# Si YA está persiguiendo, solo dejar de perseguir si se esconde en la caja
	else:
		if not player.is_detectable():
			print("❓ Jugador se escondió en la caja, patrullando...")
			last_known_position = player.global_position
			is_chasing = false
			start_patrolling()

func chase_player() -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
	
	var next_position = navigation_agent_2d.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	velocity = direction * speed
	move_and_slide()

func patrol(delta: float) -> void:
	patrol_timer += delta
	
	# Cambiar de dirección cada X segundos o al llegar al destino
	if patrol_timer >= patrol_duration or global_position.distance_to(patrol_target) < 10.0:
		set_random_patrol_point()
		patrol_timer = 0.0
	
	if navigation_agent_2d.is_navigation_finished():
		return
	
	var next_position = navigation_agent_2d.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	velocity = direction * patrol_speed
	move_and_slide()

func start_patrolling() -> void:
	is_patrolling = true
	patrol_timer = 0.0
	set_random_patrol_point()

func set_random_patrol_point() -> void:
	# Generar punto aleatorio cerca de la última posición conocida
	var random_offset = Vector2(
		randf_range(-150, 150),
		randf_range(-150, 150)
	)
	
	if last_known_position != Vector2.ZERO:
		patrol_target = last_known_position + random_offset
	else:
		patrol_target = global_position + random_offset
	
	navigation_agent_2d.target_position = patrol_target
	print("🚶 Nuevo punto de patrullaje: ", patrol_target)

func _on_timer_timeout() -> void:
	if player and is_chasing:
		# Actualizar posición mientras persigue (sin importar distancia)
		navigation_agent_2d.target_position = player.global_position

extends CharacterBody2D

@export var speed: float = 90.0
@export var chase_update_rate: float = 0.3
@export var damage: int = 1
@export var attack_pause_time: float = 1.0
@export var vision_range := 150.0
@export var vision_angle := 180.0 # grados
@export var lost_sight_time := 0.5
var last_seen_timer := 0.0
var player_detected := false



@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var chase_timer: Timer = $Timer
@onready var attack_area: Area2D = $AttackArea
@onready var damage_timer: Timer = $DamageCooldown
@onready var vision_ray: RayCast2D = $VisionRay



var player: CharacterBody2D
var is_chasing := false
var can_damage := true
var can_move := true


func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("No se encontró el jugador")
		return

	#Navigation
	navigation_agent_2d.path_desired_distance = 4.0
	navigation_agent_2d.target_desired_distance = 4.0
	navigation_agent_2d.max_speed = speed

	#Chase timer
	chase_timer.wait_time = chase_update_rate
	chase_timer.one_shot = false
	chase_timer.timeout.connect(_on_timer_timeout)

	#Damage / pause timer
	damage_timer.wait_time = attack_pause_time
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)

	#Attack area
	attack_area.area_entered.connect(_on_attack_area_entered)



# ===================== CHASE =====================

func start_chasing():
	is_chasing = true
	navigation_agent_2d.target_position = player.global_position
	chase_timer.start()

func stop_chasing():
	is_chasing = false
	velocity = Vector2.ZERO
	chase_timer.stop()

func _physics_process(delta):
	if player == null:
		return

	#lo ve → refresca memoria
	if can_see_player():
		player_detected = true
		last_seen_timer = lost_sight_time
	else:
		last_seen_timer -= delta

	#Caja solo funciona si NO está en visión
	if player.used_box and !can_see_player():
		if last_seen_timer <= 0:
			stop_chasing()
			return

	#Sigue persiguiendo mientras tenga memoria
	if player_detected and last_seen_timer > 0:
		if !is_chasing:
			start_chasing()
	else:
		player_detected = false
		stop_chasing()
		return

	#Pausa por ataque
	if !can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	#Movimiento normal
	if navigation_agent_2d.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var next_position = navigation_agent_2d.get_next_path_position()
		var direction = (next_position - global_position).normalized()
		velocity = direction * speed

	move_and_slide()

func _on_timer_timeout():
	if player and !player.used_box:
		navigation_agent_2d.target_position = player.global_position


# ===================== ATAQUE =====================

func _on_attack_area_entered(area: Area2D):
	var body = area.get_parent()

	if body.is_in_group("player") and can_damage and !body.used_box:
		body.take_damage(damage)

		#Pausa al atacar
		can_damage = false
		can_move = false
		damage_timer.start()


func _on_damage_timer_timeout():
	can_damage = true
	can_move = true

func can_see_player() -> bool:
	if player == null or vision_ray == null:
		return false

	var to_player := player.global_position - global_position

	if to_player.length() > vision_range:
		return false

	var forward := Vector2.RIGHT.rotated(global_rotation)
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))

	if abs(angle) > vision_angle * 0.5:
		return false

	vision_ray.target_position = to_player
	vision_ray.force_raycast_update()

	if !vision_ray.is_colliding():
		return false

	var collider = vision_ray.get_collider()
	return collider.is_in_group("player")

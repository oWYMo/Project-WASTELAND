extends CharacterBody2D

# ===================== ESTADOS =====================
enum EnemyState { PATROL, CHASE, SEARCH }

# ===================== CONFIGURACIÓN GENERAL =====================
@export var speed := 40.0
@export var damage := 5
@export var attack_pause_time := 0.5

# ===================== PATRULLA =====================
@export var patrol_radius := 70.0
@export var wait_time_patrol := 1.0

# ===================== BÚSQUEDA =====================
@export var search_radius := 120.0
@export var search_time := 3.0

# ===================== VISIÓN =====================
@export var vision_range := 250.0
@export var vision_angle := 180.0
@export var lost_sight_time := 1.5

# ===================== NODOS =====================
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var vision_ray: RayCast2D = $VisionRay
@onready var attack_area: Area2D = $AttackArea
@onready var damage_timer: Timer = $DamageCooldown
@onready var wait_timer: Timer = Timer.new()
@onready var nav_map := navigation_agent.get_navigation_map()

# ===================== VARIABLES =====================
var player: CharacterBody2D
var state := EnemyState.PATROL

var last_seen_position := Vector2.ZERO
var lost_timer := 0.0
var search_timer := 0.0
var stuck_timer := 0.0

var can_move := true
var can_damage := true
var waiting := false

func get_random_nav_point(center: Vector2, radius: float) -> Vector2:
	for i in range(10):
		var offset = Vector2(
			randf_range(-radius, radius),
			randf_range(-radius, radius)
		)
		var candidate = center + offset
		var closest = NavigationServer2D.map_get_closest_point(nav_map, candidate)

		if closest.distance_to(candidate) < 20:
			return closest

	return global_position

func _on_wait_timer_timeout():
	waiting = false
	set_random_patrol_target()

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("No se encontró el jugador")
		return

	wait_timer.one_shot = true
	wait_timer.timeout.connect(_on_wait_timer_timeout)
	add_child(wait_timer)

	navigation_agent.max_speed = speed
	navigation_agent.avoidance_enabled = true

	attack_area.area_entered.connect(_on_attack_area_entered)
	damage_timer.timeout.connect(_on_damage_timer_timeout)

	enter_patrol_state()

func _physics_process(delta):
	match state:
		EnemyState.PATROL:
			process_patrol(delta)
		EnemyState.CHASE:
			process_chase(delta)
		EnemyState.SEARCH:
			process_search(delta)

	move_and_slide()

func enter_patrol_state():
	state = EnemyState.PATROL
	waiting = false
	set_random_patrol_target()

func process_patrol(delta):
	if can_see_player():
		enter_chase_state()
		return

	if navigation_agent.is_navigation_finished():
		if not waiting:
			waiting = true
			wait_timer.start(wait_time_patrol)
		return

	move_towards_target(delta)

func set_random_patrol_target():
	navigation_agent.target_position = get_random_nav_point(global_position, patrol_radius)

func enter_chase_state():
	state = EnemyState.CHASE
	lost_timer = lost_sight_time

func process_chase(delta):
	if can_see_player():
		last_seen_position = player.global_position
		lost_timer = lost_sight_time
		navigation_agent.target_position = last_seen_position
	else:
		lost_timer -= delta
		if lost_timer <= 0:
			enter_search_state()
			return

	move_towards_target(delta)

func enter_search_state():
	state = EnemyState.SEARCH
	search_timer = search_time
	navigation_agent.target_position = get_random_nav_point(last_seen_position, search_radius)

func process_search(delta):
	search_timer -= delta

	if can_see_player():
		enter_chase_state()
		return

	if search_timer <= 0:
		enter_patrol_state()
		return

	if navigation_agent.is_navigation_finished():
		navigation_agent.target_position = get_random_nav_point(last_seen_position, search_radius)

	move_towards_target(delta)

func move_towards_target(delta):
	if !can_move:
		velocity = Vector2.ZERO
		return

	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_pos = navigation_agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * speed

	if velocity.length() < 1:
		stuck_timer += delta
		if stuck_timer > 0.5:
			navigation_agent.target_position = global_position
	else:
		stuck_timer = 0

func can_see_player() -> bool:
	if player.used_box:
		return false

	var to_player = player.global_position - global_position
	if to_player.length() > vision_range:
		return false

	var forward = Vector2.RIGHT.rotated(global_rotation)
	var angle = rad_to_deg(forward.angle_to(to_player.normalized()))
	if abs(angle) > vision_angle * 0.5:
		return false

	vision_ray.target_position = to_player
	vision_ray.force_raycast_update()

	if !vision_ray.is_colliding():
		return false

	return vision_ray.get_collider() == player

func _on_attack_area_entered(area):
	var body = area.get_parent()
	if body.is_in_group("player") and can_damage and !body.used_box:
		body.take_damage(damage)
		can_damage = false
		can_move = false
		damage_timer.start()

func _on_damage_timer_timeout():
	can_damage = true
	can_move = true

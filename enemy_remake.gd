extends CharacterBody2D

enum EnemyState { PATROL, CHASE, SEARCH }

@export var speed: float = 40.0
@export var damage: int = 5
@export var attack_pause_time: float = 0.5

@export var patrol_radius: float = 70.0
@export var wait_time_patrol: float = 1.0

@export var search_radius: float = 120.0
@export var search_time: float = 3.0

@export var vision_range: float = 250.0
@export var vision_angle: float = 180.0
@export var lost_sight_time: float = 1.5

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var vision_ray: RayCast2D = $RayCast2D
@onready var damage_timer: Timer = $Timer
@onready var hitbox_area: Area2D = $hitbox

var player: CharacterBody2D
var state: int = EnemyState.PATROL

var last_seen_position: Vector2
var last_path_update_position: Vector2
var repath_distance: float = 12.0

var lost_timer: float = 0.0
var search_timer: float = 0.0
var stuck_timer: float = 0.0

var can_move := true
var can_damage := true
var waiting := false

var wait_timer: Timer

# ================= READY =================
func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("No se encontró el jugador")
		return

	wait_timer = Timer.new()
	wait_timer.one_shot = true
	wait_timer.timeout.connect(_on_wait_timer_timeout)
	add_child(wait_timer)

	navigation_agent.max_speed = speed
	navigation_agent.avoidance_enabled = true
	navigation_agent.radius = 4

	hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	damage_timer.timeout.connect(_on_damage_timer_timeout)

	vision_ray.enabled = true
	vision_ray.exclude_parent = true

	await wait_for_navigation_ready()
	enter_patrol_state()

# 🔥 Espera a que NavigationServer termine de sincronizar
func wait_for_navigation_ready():
	var map = navigation_agent.get_navigation_map()
	while NavigationServer2D.map_get_iteration_id(map) == 0:
		await get_tree().process_frame

# ================= LOOP =================
func _physics_process(delta):
	match state:
		EnemyState.PATROL: process_patrol(delta)
		EnemyState.CHASE: process_chase(delta)
		EnemyState.SEARCH: process_search(delta)

	move_and_slide()

# ================= ESTADOS =================
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

func enter_chase_state():
	state = EnemyState.CHASE
	lost_timer = lost_sight_time
	last_path_update_position = Vector2.ZERO

func process_chase(delta):
	if can_see_player():
		last_seen_position = player.global_position
		lost_timer = lost_sight_time

		if last_seen_position.distance_to(last_path_update_position) > repath_distance:
			navigation_agent.target_position = get_safe_nav_position(last_seen_position)
			last_path_update_position = last_seen_position
	else:
		lost_timer -= delta
		if lost_timer <= 0:
			enter_search_state()
			return

	move_towards_target(delta)

func enter_search_state():
	state = EnemyState.SEARCH
	search_timer = search_time
	navigation_agent.target_position = get_safe_nav_position(last_seen_position)

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

# ================= MOVIMIENTO =================
func move_towards_target(delta):
	if not can_move or navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	velocity = direction * speed

	if velocity.length() < 1:
		stuck_timer += delta
		if stuck_timer > 0.5:
			navigation_agent.target_position = global_position
	else:
		stuck_timer = 0

# ================= VISIÓN =================
func can_see_player() -> bool:
	if player == null:
		return false

	if player.has_method("is_detectable") and not player.is_detectable():
		return false

	var to_player = player.global_position - global_position
	if to_player.length() > vision_range:
		return false

	var forward = Vector2.RIGHT.rotated(global_rotation)
	if abs(rad_to_deg(forward.angle_to(to_player.normalized()))) > vision_angle * 0.5:
		return false

	vision_ray.target_position = to_player
	vision_ray.force_raycast_update()

	return vision_ray.is_colliding() and vision_ray.get_collider() == player

# ================= NAV UTILS =================
func get_safe_nav_position(pos: Vector2) -> Vector2:
	var map = navigation_agent.get_navigation_map()
	return NavigationServer2D.map_get_closest_point(map, pos)

func set_random_patrol_target():
	navigation_agent.target_position = get_random_nav_point(global_position, patrol_radius)

func get_random_nav_point(center: Vector2, radius: float) -> Vector2:
	for i in range(10):
		var offset = Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		var candidate = center + offset
		var closest = get_safe_nav_position(candidate)
		if closest.distance_to(candidate) < 20:
			return closest
	return get_safe_nav_position(global_position)

# ================= SEÑALES =================
func _on_wait_timer_timeout():
	waiting = false
	set_random_patrol_target()

func _on_hitbox_area_entered(area: Area2D):
	var body = area.get_parent()
	if body == null or not body.is_in_group("player"):
		return
	if body.has_method("is_detectable") and not body.is_detectable():
		return

	if can_damage:
		body.take_damage(damage)
		can_damage = false
		can_move = false
		damage_timer.start(attack_pause_time)

func _on_damage_timer_timeout():
	can_damage = true
	can_move = true

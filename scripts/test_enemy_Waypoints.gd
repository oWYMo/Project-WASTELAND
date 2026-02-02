extends CharacterBody2D

@export var speed: float = 90.0
@export var chase_update_rate: float = 0.3
@export var damage: int = 1
@export var attack_pause_time: float = 1.0
@export var vision_range := 150.0
@export var vision_angle := 60.0 # grados
@export var lost_sight_time := 0.5



@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var chase_timer: Timer = $Timer
@onready var attack_area: Area2D = $AttackArea
@onready var damage_timer: Timer = $DamageCooldown

var player: CharacterBody2D
var is_chasing := false
var can_damage := true
var can_move := true


func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("No se encontró el jugador")
		return

	# Navigation
	navigation_agent_2d.path_desired_distance = 4.0
	navigation_agent_2d.target_desired_distance = 4.0
	navigation_agent_2d.max_speed = speed

	# Chase timer
	chase_timer.wait_time = chase_update_rate
	chase_timer.one_shot = false
	chase_timer.timeout.connect(_on_timer_timeout)

	# Damage / pause timer
	damage_timer.wait_time = attack_pause_time
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)

	# Attack area
	attack_area.area_entered.connect(_on_attack_area_entered)

	start_chasing()


# ===================== CHASE =====================

func start_chasing():
	is_chasing = true
	navigation_agent_2d.target_position = player.global_position
	chase_timer.start()


func stop_chasing():
	is_chasing = false
	velocity = Vector2.ZERO
	chase_timer.stop()


func _physics_process(_delta):
	if player == null:
		return

	# 🛑 Si el jugador está en la caja → no lo ve
	if player.used_box and !can_see_player():
		stop_chasing()
		return
	if can_see_player():
		start_chasing()
	if !can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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

		# ⏸️ Pausa al atacar
		can_damage = false
		can_move = false
		damage_timer.start()


func _on_damage_timer_timeout():
	can_damage = true
	can_move = true

func can_see_player() -> bool:
	if player == null:
		return false

	# Dirección al jugador
	var to_player = (player.global_position - global_position)
	if to_player.length() > vision_range:
		return false

	# Ángulo de visión
	var forward = Vector2.RIGHT.rotated(global_rotation)
	var angle = rad_to_deg(forward.angle_to(to_player.normalized()))

	if abs(angle) > vision_angle * 0.5:
		return false

	# Raycast (línea de visión)
	$VisionRay.target_position = to_player
	$VisionRay.force_raycast_update()

	if !$VisionRay.is_colliding():
		return false

	var collider = $VisionRay.get_collider()
	return collider.is_in_group("player")

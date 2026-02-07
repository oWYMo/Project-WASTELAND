extends Area2D

##Puerta que se abre con llave. Al abrirse, reproduce una animación y luego
##elimina todos los cuerpos (obstáculos) que estén dentro de su CollisionShape2D.

var is_open: bool = false
var is_opening: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("door")
	#para que el jugador detecte esta Area2D, debe estar en layer 3 (item) -> collision_layer = 4
	#para que get_overlapping_bodies() detecte obstáculos, collision_mask debe incluir su layer (ej. 8 = structure)
	animated_sprite.animation_finished.connect(_on_animation_finished)


## Lo llama el jugador cuando tiene llave y pulsa use_key (por defecto R) en rango.
## Devuelve true si la puerta se abrió (se consumió una llave), false si ya estaba abierta.
func open() -> bool:
	if is_open or is_opening:
		return false
	
	is_opening = true
	# Reproducir una sola vez (no loop) para que animation_finished se dispare
	animated_sprite.sprite_frames.set_animation_loop("door_open", false)
	animated_sprite.play("door_open")
	return true


func _on_animation_finished() -> void:
	if not is_opening:
		return
	
	is_opening = false
	is_open = true
	
	# Eliminar todos los cuerpos (obstáculos) dentro del área
	var bodies = get_overlapping_bodies()
	for body in bodies:
		# No eliminar al jugador ni a enemigos si pasan por el área
		if body.is_in_group("player") or body.is_in_group("enemy"):
			continue
		body.queue_free()
	
	# Opcional: dejar la animación en el último frame (puerta abierta)
	animated_sprite.sprite_frames.set_animation_loop("door_open", true)

extends CharacterBody2D


const SPEED = 200

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# TODO add animation for go up and go down
func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector("go_left", "go_right", "go_up", "go_down")
	velocity = direction * SPEED
	
	# flip the Sprite
	if direction.x > 0:
		animated_sprite.flip_h = false
	elif direction.x < 0:
		animated_sprite.flip_h = true

	animated_sprite.play("idle")

	move_and_slide() # moves the body based on velocity

extends Area2D

# adds signal so you can emit it when u collect a coin  and add it to the counter
signal collected 


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _on_body_entered(body: Node2D) -> void:
	# only react to the player
	if not body is CharacterBody2D:
		return

	# disable monitoring so it can't be triggered again mid-animation
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)

	collected.emit()
	animation_player.play("pickup")

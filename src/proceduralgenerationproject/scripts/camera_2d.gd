extends Camera2D

# Zoom settings
@export var zoom_step: float = 0.1
@export var min_zoom: float = 1.5
@export var max_zoom: float = 6.0
@export var trackpad_zoom_sensitivity: float = 0.02
@export var invert_trackpad_zoom: bool = false

# Pan/Follow settings
@export var pan_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var follow_key: Key = KEY_R
@export var follow_target: NodePath  # Set to player in inspector
@export var follow_speed: float = 5.0
@export var follow_offset: Vector2 = Vector2(0, -48)
@export var look_ahead_strength: float = 0.25
@export var look_ahead_max: float = 96.0

# Camera modes
var _follow_enabled: bool = true
var _is_panning: bool = false
var _target: Node2D = null
var _look_ahead: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Keep zoom uniform (x == y) and inside limits.
	var z: float = clampf(zoom.x, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	
	# Find follow target
	if follow_target:
		_target = get_node_or_null(follow_target)
	else:
		# Fallback: try to find player as sibling or in parent
		_target = get_tree().root.find_child("Player", true, false)


func _process(delta: float) -> void:
	# Follow player when not panning
	if _follow_enabled and _target != null:
		_update_look_ahead(delta)
		var target_pos = _target.global_position + follow_offset + _look_ahead
		global_position = global_position.lerp(target_pos, follow_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == follow_key:
			_follow_enabled = true
			_is_panning = false
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event

		# Enter pan mode on button press; keep it until follow_key is pressed.
		if mb.button_index == pan_button:
			if mb.pressed:
				_follow_enabled = false
				_is_panning = true
			else:
				_is_panning = false
			return

		# Zoom: mouse wheel
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x - zoom_step)
			return

		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x + zoom_step)
			return

	if event is InputEventMouseMotion and _is_panning:
		var mm: InputEventMouseMotion = event
		# Pan camera by dragging (moves camera opposite to mouse for natural feel)
		global_position -= mm.relative / zoom.x

	# Trackpad pinch gesture (common on macOS laptops)
	if event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		if mg.factor > 0.0:
			_set_zoom(zoom.x / mg.factor)
		return

	# Trackpad two-finger gesture fallback for devices that emit pan gesture.
	if event is InputEventPanGesture:
		var pg: InputEventPanGesture = event
		var sign_dir: float = -1.0 if invert_trackpad_zoom else 1.0
		_set_zoom(zoom.x + (pg.delta.y * trackpad_zoom_sensitivity * sign_dir))
		return


func _set_zoom(value: float) -> void:
	var z: float = clampf(value, min_zoom, max_zoom)
	zoom = Vector2(z, z)


func _update_look_ahead(delta: float) -> void:
	var desired: Vector2 = Vector2.ZERO

	if _target is CharacterBody2D:
		var body: CharacterBody2D = _target
		desired = body.velocity * look_ahead_strength

	if desired.length() > look_ahead_max:
		desired = desired.normalized() * look_ahead_max

	_look_ahead = _look_ahead.lerp(desired, minf(1.0, follow_speed * delta))

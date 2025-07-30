extends CharacterBody3D
class_name Player

const WALK_SPEED = 5.0
const RUN_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const CROUCH_SPEED = 2.5
const PRONE_SPEED = 1.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_sensitivity = 0.002
var current_speed = WALK_SPEED

enum StanceState { STANDING, CROUCHING, PRONE }
var current_stance = StanceState.STANDING
var is_running = false

var standing_height = 1.8
var crouching_height = 0.9
var prone_height = 0.4

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var collision_shape = $CollisionShape3D
@onready var ground_check = $GroundCheck
@onready var hand_position = $HandPosition
@onready var weapon_detector = $WeaponDetector

var current_weapon = null

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	setup_collision_shape()
	setup_rays()
	setup_weapon_detector()

func setup_collision_shape():
	var shape = CapsuleShape3D.new()
	shape.height = standing_height
	shape.radius = 0.4
	collision_shape.shape = shape

func setup_rays():
	ground_check.position = Vector3.ZERO
	ground_check.target_position = Vector3(0, -0.1, 0)
	ground_check.enabled = true

func setup_weapon_detector():
	var detector_shape = SphereShape3D.new()
	detector_shape.radius = 1.5
	weapon_detector.get_child(0).shape = detector_shape
	weapon_detector.body_entered.connect(_on_weapon_entered)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		handle_mouse_look(event)
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func handle_mouse_look(event):
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	
	rotate_y(-event.relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	handle_stance_input()
	handle_movement(delta)
	move_and_slide()

func handle_stance_input():
	if Input.is_action_just_pressed("crouch"):
		if current_stance == StanceState.STANDING:
			set_stance(StanceState.CROUCHING)
		elif current_stance == StanceState.CROUCHING:
			if can_stand_up():
				set_stance(StanceState.STANDING)
	
	if Input.is_action_just_pressed("prone"):
		if current_stance == StanceState.CROUCHING:
			set_stance(StanceState.PRONE)
		elif current_stance == StanceState.PRONE:
			set_stance(StanceState.CROUCHING)
	
	is_running = Input.is_action_pressed("run") and current_stance == StanceState.STANDING

func can_stand_up() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0),
		global_position + Vector3(0, standing_height, 0)
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func set_stance(new_stance: StanceState):
	current_stance = new_stance
	
	var target_height: float
	var camera_height: float
	
	match current_stance:
		StanceState.STANDING:
			target_height = standing_height
			camera_height = 1.6
			current_speed = RUN_SPEED if is_running else WALK_SPEED
		StanceState.CROUCHING:
			target_height = crouching_height
			camera_height = 0.7
			current_speed = CROUCH_SPEED
		StanceState.PRONE:
			target_height = prone_height
			camera_height = 0.2
			current_speed = PRONE_SPEED
	
	var shape = collision_shape.shape as CapsuleShape3D
	var tween = create_tween()
	tween.parallel().tween_property(shape, "height", target_height, 0.3)
	tween.parallel().tween_property(camera_pivot, "position:y", camera_height, 0.3)

func handle_movement(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor() and current_stance == StanceState.STANDING:
		velocity.y = JUMP_VELOCITY
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		var speed = current_speed
		if is_running and current_stance == StanceState.STANDING:
			speed = RUN_SPEED
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 3)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 3)

func _on_weapon_entered(body):
	if body.has_method("can_pickup") and body.can_pickup():
		pickup_weapon(body)

func pickup_weapon(weapon):
	if current_weapon:
		drop_current_weapon()
	
	current_weapon = weapon
	weapon.pickup(hand_position)

func drop_current_weapon():
	if current_weapon:
		current_weapon.drop(global_position + transform.basis.z * -1)
		current_weapon = null

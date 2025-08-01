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
@onready var fps_camera = $CameraPivot/Camera3D
@onready var tps_camera = $TPSCamera
@onready var collision_shape = $CollisionShape3D
@onready var ground_check = $GroundCheck
@onready var hand_position = $HandPosition
@onready var weapon_detector = $WeaponDetector
@onready var ui = $UI
@onready var ammo_label = $UI/AmmoLabel

var current_weapon = null
var is_first_person = true

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	setup_collision_shape()
	setup_rays()
	setup_weapon_detector()
	setup_cameras()
	setup_ui()

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

func setup_cameras():
	fps_camera.current = true
	tps_camera.current = false

func setup_ui():
	if not ammo_label:
		ammo_label = Label.new()
		ammo_label.name = "AmmoLabel"
		ui.add_child(ammo_label)
		ammo_label.position = Vector2(50, 50)
		ammo_label.add_theme_font_size_override("font_size", 24)
		ammo_label.add_theme_color_override("font_color", Color.WHITE)
	update_ammo_display()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		handle_mouse_look(event)
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.is_action_just_pressed("switch_camera"):
		switch_camera()
	
	if Input.is_action_just_pressed("shoot"):
		shoot_weapon()
	
	if Input.is_action_just_pressed("reload"):
		reload_weapon()
	
	if Input.is_action_just_pressed("drop_weapon"):
		drop_current_weapon()

func handle_mouse_look(event):
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	
	if is_first_person:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
	else:
		rotate_y(-event.relative.x * mouse_sensitivity)
		tps_camera.rotate_x(-event.relative.y * mouse_sensitivity)
		tps_camera.rotation.x = clamp(tps_camera.rotation.x, -PI/3, PI/6)

func switch_camera():
	is_first_person = !is_first_person
	
	if is_first_person:
		fps_camera.current = true
		tps_camera.current = false
	else:
		tps_camera.current = true
		fps_camera.current = false

func shoot_weapon():
	if not current_weapon:
		return
	
	var camera = fps_camera if is_first_person else tps_camera
	var shoot_direction = -camera.global_transform.basis.z
	
	if current_weapon.shoot(shoot_direction):
		update_ammo_display()

func reload_weapon():
	if current_weapon:
		current_weapon.reload()
		update_ammo_display()

func update_ammo_display():
	if current_weapon:
		ammo_label.text = "Ammo: " + current_weapon.get_ammo_text()
		ammo_label.visible = true
	else:
		ammo_label.visible = false

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
	var tps_height: float
	
	match current_stance:
		StanceState.STANDING:
			target_height = standing_height
			camera_height = 1.6
			tps_height = 1.8
			current_speed = RUN_SPEED if is_running else WALK_SPEED
		StanceState.CROUCHING:
			target_height = crouching_height
			camera_height = 0.7
			tps_height = 1.0
			current_speed = CROUCH_SPEED
		StanceState.PRONE:
			target_height = prone_height
			camera_height = 0.2
			tps_height = 0.5
			current_speed = PRONE_SPEED
	
	var shape = collision_shape.shape as CapsuleShape3D
	var tween = create_tween()
	tween.parallel().tween_property(shape, "height", target_height, 0.3)
	tween.parallel().tween_property(camera_pivot, "position:y", camera_height, 0.3)
	tween.parallel().tween_property(tps_camera, "position:y", tps_height, 0.3)

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
	update_ammo_display()

func drop_current_weapon():
	if current_weapon:
		var drop_distance = 2.0
		var forward_direction = -transform.basis.z
		var drop_position = global_position + forward_direction * drop_distance
		current_weapon.drop(drop_position, forward_direction)
		current_weapon = null
		update_ammo_display()

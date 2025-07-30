extends RigidBody3D
class_name Weapon

@export var weapon_name = "Pistol"
@export var max_ammo = 9
@export var damage = 25
@export var fire_rate = 0.5
@export var bullet_speed = 50.0
@export var muzzle_flash_scene: PackedScene

var current_ammo: int
var is_held = false
var can_shoot = true
var muzzle_point: Node3D

func _ready():
	add_to_group("weapons")
	current_ammo = max_ammo
	setup_muzzle_point()

func setup_muzzle_point():
	muzzle_point = Node3D.new()
	muzzle_point.name = "MuzzlePoint"
	add_child(muzzle_point)
	muzzle_point.position = Vector3(0, 0, -0.8)

func can_pickup() -> bool:
	return not is_held

func pickup(hand_position: Node3D):
	is_held = true
	freeze = true
	set_collision_layer_value(1, false)
	reparent(hand_position)
	position = Vector3.ZERO
	rotation = Vector3.ZERO

func drop(drop_position: Vector3, throw_direction: Vector3 = Vector3.ZERO):
	is_held = false
	freeze = false
	set_collision_layer_value(1, true)
	reparent(get_tree().current_scene)
	global_position = drop_position
	
	if throw_direction != Vector3.ZERO:
		var throw_force = throw_direction * 8.0 + Vector3.UP * 3.0
		apply_impulse(throw_force)
	else:
		var throw_force = Vector3(randf_range(-5, 5), 3, randf_range(-5, 5))
		apply_impulse(throw_force)

func shoot(shoot_direction: Vector3):
	if not can_shoot or current_ammo <= 0 or not is_held:
		return false
	
	current_ammo -= 1
	can_shoot = false
	
	var muzzle_world_pos = muzzle_point.global_position
	spawn_bullet(muzzle_world_pos, shoot_direction)
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = fire_rate
	timer.one_shot = true
	timer.timeout.connect(func(): can_shoot = true; timer.queue_free())
	timer.start()
	
	return true

func spawn_bullet(origin: Vector3, direction: Vector3):
	var bullet = preload("res://Scenes/bullet.tscn").instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = origin
	bullet.setup(direction, bullet_speed, damage)

func reload():
	current_ammo = max_ammo

func get_ammo_text() -> String:
	return str(current_ammo) + "/" + str(max_ammo)

func get_muzzle_position() -> Vector3:
	if muzzle_point:
		return muzzle_point.global_position
	return global_position

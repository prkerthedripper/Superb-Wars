extends RigidBody3D
class_name Bullet

var damage: int
var speed: float
var direction: Vector3
var lifetime = 5.0

@onready var collision_shape = $CollisionShape3D
@onready var mesh_instance = $MeshInstance3D

func _ready():
	setup_bullet_appearance()
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(destroy_bullet)
	timer.start()
	
	body_entered.connect(_on_body_entered)

func setup_bullet_appearance():
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.02
	sphere_mesh.height = 0.04
	mesh_instance.mesh = sphere_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	mesh_instance.material_override = material
	
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.02
	collision_shape.shape = sphere_shape

func setup(dir: Vector3, bullet_speed: float, bullet_damage: int):
	direction = dir.normalized()
	speed = bullet_speed
	damage = bullet_damage
	
	linear_velocity = direction * speed
	look_at(global_position + direction, Vector3.UP)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	destroy_bullet()

func destroy_bullet():
	queue_free()

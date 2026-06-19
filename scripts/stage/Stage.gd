class_name Stage
extends Node3D

## Builds the arena environment in code: floor, back wall, boundary posts, lighting and
## a simple environment. Purely visual - gameplay bounds live in Arena.

func build() -> void:
	var half := Arena.STAGE_HALF_WIDTH

	_add_floor(half)
	_add_wall(half)
	_add_posts(half)
	_add_lighting()
	_add_environment()

func _add_floor(half: float) -> void:
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half * 2.0 + 4.0, 0.4, 6.0)
	floor.mesh = mesh
	floor.position = Vector3(0, -0.2, 0)
	floor.material_override = _mat(Color(0.16, 0.17, 0.22), 0.9)
	add_child(floor)

	var stripe := MeshInstance3D.new()
	var smesh := BoxMesh.new()
	smesh.size = Vector3(half * 2.0, 0.02, 2.2)
	stripe.mesh = smesh
	stripe.position = Vector3(0, 0.01, 0)
	stripe.material_override = _mat(Color(0.22, 0.24, 0.32), 0.9)
	add_child(stripe)

func _add_wall(half: float) -> void:
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half * 2.0 + 4.0, 7.0, 0.5)
	wall.mesh = mesh
	wall.position = Vector3(0, 3.0, -1.6)
	wall.material_override = _mat(Color(0.12, 0.13, 0.18), 1.0)
	add_child(wall)

func _add_posts(half: float) -> void:
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.2, 4.0, 1.0)
		post.mesh = mesh
		post.position = Vector3(sx * (half + 0.3), 2.0, -0.6)
		post.material_override = _mat(Color(0.9, 0.45, 0.2), 0.6)
		add_child(post)

func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 130, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)

func _add_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat

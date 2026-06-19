extends SceneTree

# Dev tool: import inventory for the licensed FBX models/animations.
# Prints Maskman's node tree + size, and every animation clip in each KB_*.fbx.
# Run: godot --headless --script res://tools/inspect_models.gd

func _find(node: Node, klass: String) -> Node:
	if node.is_class(klass):
		return node
	for c in node.get_children():
		var r := _find(c, klass)
		if r:
			return r
	return null

func _tree(node: Node, depth: int) -> void:
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")")
	for c in node.get_children():
		_tree(c, depth + 1)

func _aabb(node: Node) -> AABB:
	var box := AABB()
	var started := false
	for child in node.get_children():
		if child is VisualInstance3D:
			var a: AABB = (child as VisualInstance3D).get_aabb()
			if not started:
				box = a
				started = true
			else:
				box = box.merge(a)
		var sub := _aabb(child)
		if sub.size != Vector3.ZERO:
			box = box.merge(sub) if started else sub
			started = true
	return box

func _report_model(path: String) -> void:
	print("\n==== ", path, " ====")
	var ps = load(path)
	if ps == null:
		print("  (failed to load)"); return
	var inst = ps.instantiate()
	get_root().add_child(inst)
	_tree(inst, 1)
	var skel := _find(inst, "Skeleton3D") as Skeleton3D
	if skel:
		print("  bones: ", skel.get_bone_count())
	# True world-space AABB (mesh AABBs transformed by their global transform).
	var box := AABB()
	var started := false
	var meshes: Array = []
	_all_meshes(inst, meshes)
	for m in meshes:
		var mi: MeshInstance3D = m
		var wb: AABB = mi.global_transform * mi.get_aabb()
		box = wb if not started else box.merge(wb)
		started = true
	print("  world AABB size (x,y,z): ", box.size, "  -> tallest axis: ",
		("Y standing" if box.size.y >= box.size.x and box.size.y >= box.size.z else "NOT Y (needs rotation)"))
	inst.free()

func _all_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_all_meshes(c, out)

func _test_rotation(path: String, euler: Vector3) -> void:
	var ps = load(path)
	var inst = ps.instantiate()
	get_root().add_child(inst)
	(inst as Node3D).rotation_degrees = euler
	var box := AABB()
	var started := false
	var meshes: Array = []
	_all_meshes(inst, meshes)
	for m in meshes:
		var mi: MeshInstance3D = m
		var wb: AABB = mi.global_transform * mi.get_aabb()
		box = wb if not started else box.merge(wb)
		started = true
	var tall := "X" if (box.size.x >= box.size.y and box.size.x >= box.size.z) else ("Y" if box.size.y >= box.size.z else "Z")
	print("  euler ", euler, " -> size ", box.size, " tallest=", tall)
	inst.free()

func _report_anims(path: String) -> void:
	var ps = load(path)
	if ps == null:
		print(path, ": (failed)"); return
	var inst = ps.instantiate()
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	if ap:
		var libs := ap.get_animation_library_list()
		var list := ap.get_animation_list()
		print(path.get_file(), " | root=", ap.root_node, " | libs=", libs, " | clips(", list.size(), "): ", ", ".join(list))
	else:
		print(path.get_file(), ": (no AnimationPlayer)")
	inst.free()

func _initialize() -> void:
	_report_model("res://assets/models/maskman.fbx")
	print("\n---- rotation candidates (want Y tallest ~1.84) ----")
	for cand in [Vector3(0,0,0), Vector3(-90,0,0), Vector3(90,0,0), Vector3(-90,-90,0), Vector3(-90,90,0)]:
		_test_rotation("res://assets/models/maskman.fbx", cand)
	print("\n---- animation clips ----")
	var dir := DirAccess.open("res://assets/models/anims")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".fbx"):
				_report_anims("res://assets/models/anims/" + f)
	quit()

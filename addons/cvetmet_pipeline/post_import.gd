@tool
extends EditorScenePostImportPlugin
## Обработка моделей из art_src/blender после импорта .glb:
##  - всем мешам ставится общий материал res://assets/materials/palette.tres;
##  - меши col_* становятся выпуклыми CollisionShape3D (сам меш удаляется);
##  - пустышки grip_* становятся Marker3D (точки хвата для IK рук).
## Работает только для файлов из res://assets/models/.

const MODELS_DIR: String = "res://assets/models/"
const PALETTE_MATERIAL: String = "res://assets/materials/palette.tres"


func _post_process(scene: Node) -> void:
	var material: Material = load(PALETTE_MATERIAL)
	_walk(scene, scene, material)


func _walk(node: Node, root: Node, material: Material) -> void:
	for child: Node in node.get_children():
		_walk(child, root, material)
	if node == root:
		return
	var node_name: String = node.name
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if node_name.begins_with("col_"):
			var shape := CollisionShape3D.new()
			shape.shape = mi.mesh.create_convex_shape(true, false)
			_replace(mi, shape, root)
		elif material != null and mi.mesh != null:
			for i: int in mi.mesh.get_surface_count():
				mi.mesh.surface_set_material(i, material)
	elif node_name.begins_with("grip_"):
		_replace(node as Node3D, Marker3D.new(), root)


func _replace(old: Node3D, new: Node3D, root: Node) -> void:
	new.name = old.name
	new.transform = old.transform
	var parent: Node = old.get_parent()
	parent.add_child(new)
	parent.move_child(new, old.get_index())
	new.owner = root
	parent.remove_child(old)
	old.queue_free()

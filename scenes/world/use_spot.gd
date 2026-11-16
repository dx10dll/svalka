class_name UseSpot
extends StaticBody3D
## Простая «кнопка в мире»: коробка, на которую жмут E. Что написать в подсказке
## и что сделать — задаётся двумя функциями.

## () -> String: готовая подсказка («E — купить …»); пустая строка — нажать нельзя
var hint: Callable
## (player: PlayerController) -> void
var on_use: Callable


static func make(size: Vector3, color: Color, hint_fn: Callable, use_fn: Callable) -> UseSpot:
	var spot := UseSpot.new()
	spot.hint = hint_fn
	spot.on_use = use_fn
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	spot.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material_override = mat
	spot.add_child(mesh)
	return spot


func interaction_at(_point: Vector3) -> Dictionary:
	var text: String = hint.call()
	return {"text": text, "action": &"use"} if not text.is_empty() else {}


func interact(player: PlayerController, _action: StringName) -> void:
	on_use.call(player)

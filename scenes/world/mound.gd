class_name Mound
extends StaticBody3D
## Насыпь поперёк дороги: въезд, площадка, съезд. Проверка для гружёной машины —
## перегруженная буханка на неё не въедет без толкачей. Ось насыпи — Z.

## Длина каждого ската, длина площадки наверху, высота и ширина, м
var ramp: float = 8.0
var top: float = 2.0
var height: float = 1.4
var width: float = 6.0
var color := Color(0.15, 0.13, 0.11)


func build() -> void:
	var half: float = width * 0.5
	var z0: float = -(ramp + top * 0.5)
	var z1: float = -top * 0.5
	# профиль: четыре точки по низу и верху, с двух бортов
	var profile: Array[Vector2] = [Vector2(z0, 0.0), Vector2(z1, height), Vector2(-z1, height), Vector2(-z0, 0.0)]
	var points := PackedVector3Array()
	for x: float in [-half, half]:
		for p: Vector2 in profile:
			points.append(Vector3(x, p.y, p.x))
		points.append(Vector3(x, -0.3, z0))
		points.append(Vector3(x, -0.3, -z0))
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	shape.shape = hull
	add_child(shape)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 3:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		_quad(st, Vector3(-half, a.y, a.x), Vector3(half, a.y, a.x), Vector3(half, b.y, b.x), Vector3(-half, b.y, b.x))
	for x: float in [-half, half]:
		# борта: трапеция из двух треугольников и прямоугольника
		var flip: bool = x > 0.0
		_tri(st, Vector3(x, 0, z0), Vector3(x, height, z1), Vector3(x, 0, z1), flip)
		_tri(st, Vector3(x, 0, z1), Vector3(x, height, z1), Vector3(x, height, -z1), flip)
		_tri(st, Vector3(x, 0, z1), Vector3(x, height, -z1), Vector3(x, 0, -z1), flip)
		_tri(st, Vector3(x, 0, -z1), Vector3(x, height, -z1), Vector3(x, 0, -z0), flip)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)


## Уклон скатов, градусы.
func slope_deg() -> float:
	return rad_to_deg(atan2(height, ramp))


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, c, b, false)
	_tri(st, a, d, c, false)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, flip: bool) -> void:
	st.add_vertex(a)
	st.add_vertex(c if flip else b)
	st.add_vertex(b if flip else c)

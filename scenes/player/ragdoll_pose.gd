class_name RagdollPose
extends SkeletonModifier3D
## Переносит позы тел рэгдолла на кости скелета. Сила смешивания — influence:
## 1 — скелет целиком следует физике, 0 — анимации (плавное вставание).

var ragdoll: Ragdoll


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or ragdoll == null:
		return
	var inv: Transform3D = sk.global_transform.affine_inverse()
	# порядок как в таблице: родители раньше детей
	for part: Dictionary in Ragdoll.PARTS:
		var body: RigidBody3D = ragdoll.bodies[part["bone"]]
		var bone: int = body.get_meta(&"bone")
		var xf: Transform3D = body.get_global_transform_interpolated() if ragdoll.active else body.global_transform
		sk.set_bone_global_pose(bone, (inv * xf).orthonormalized())

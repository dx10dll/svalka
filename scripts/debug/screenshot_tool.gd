extends Node
## Снимок экрана для отчётов: запускает игру, ждёт N кадров, сохраняет PNG и выходит.
## Пример:
##   godot --path . res://scenes/debug/playground_stage1.tscn -- \
##       --shot=shot.png --shot-frames=120 --shot-cam=3,2.5,4,25,-12
## --shot-cam: x,y,z камеры, поворот по горизонтали и вертикали в градусах.
## Без аргумента --shot ничего не делает.

var _path: String = ""
var _frames_left: int = 90


func _ready() -> void:
	var cam_spec: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-frames="):
			_frames_left = int(arg.trim_prefix("--shot-frames="))
		elif arg.begins_with("--shot-cam="):
			cam_spec = arg.trim_prefix("--shot-cam=")
	if _path.is_empty():
		set_process(false)
		return
	if not cam_spec.is_empty():
		_place_camera.call_deferred(cam_spec)


func _place_camera(spec: String) -> void:
	var p: PackedFloat64Array = spec.split_floats(",")
	if p.size() < 5:
		push_error("--shot-cam ждёт 5 чисел: x,y,z,yaw,pitch")
		return
	await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_tree().current_scene.add_child(cam)
	cam.global_position = Vector3(p[0], p[1], p[2])
	cam.rotation = Vector3(deg_to_rad(p[4]), deg_to_rad(p[3]), 0.0)
	cam.make_current()
	# удерживаем камеру текущей: игрок может забрать её себе
	set_meta(&"cam", cam)


func _process(_delta: float) -> void:
	if has_meta(&"cam"):
		(get_meta(&"cam") as Camera3D).make_current()
	_frames_left -= 1
	if _frames_left > 0:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(_path)
	print("Снимок: %s (%s)" % [_path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)

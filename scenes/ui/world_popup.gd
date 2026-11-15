class_name WorldPopup
extends Label3D
## Всплывающая надпись в мире: «−1 200 ₽» над разбитым телевизором.
## Всплывает, держится и растворяется; всегда повёрнута к камере и видна сквозь предметы.

const RISE: float = 0.7
const LIFETIME: float = 1.6


static func spawn(parent: Node, at: Vector3, message: String, color: Color) -> WorldPopup:
	var popup := WorldPopup.new()
	popup.text = message
	popup.modulate = color
	parent.add_child(popup)
	popup.global_position = at
	popup._start()
	return popup


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0011
	font_size = 44
	outline_size = 10
	outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	render_priority = 10


func _start() -> void:
	scale = Vector3.ONE * 0.6
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# выскакивает с перелётом, потом плывёт вверх
	tween.tween_property(self, ^"scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"position:y", position.y + RISE, LIFETIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"modulate:a", 0.0, 0.5).set_delay(LIFETIME - 0.5)
	tween.chain().tween_callback(queue_free)

class_name ImpactSound
extends Node
## Звук ударов для любого физического тела без своего скрипта (ящики, мусор).
## Вешается ребёнком на RigidBody3D.

## Имя звука из assets/audio/sfx
@export var sound: StringName = &"wood"
## Удары слабее этого не слышны, м/с
@export var min_impact: float = 1.2

var _body: RigidBody3D
var _prev_velocity := Vector3.ZERO


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	assert(_body != null, "ImpactSound должен быть ребёнком RigidBody3D")
	_body.contact_monitor = true
	_body.max_contacts_reported = maxi(_body.max_contacts_reported, 2)
	_body.body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	_prev_velocity = _body.linear_velocity


func _on_body_entered(_other: Node) -> void:
	var impact: float = (_prev_velocity - _body.linear_velocity).length()
	if impact >= min_impact:
		Audio.play_impact(sound, _body.global_position, impact)

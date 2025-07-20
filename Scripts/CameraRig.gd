extends Node3D
class_name CameraRig

@export var target: Node3D
@export var offset: Vector3 = Vector3(-10, 10, -10)

func _process(_delta):
	if target:
		global_position = target.global_position + offset

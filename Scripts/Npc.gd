extends CharacterBody3D

signal clicked(id)

@export var id: int = 0

func _ready() -> void:
	$Area3D.connect("input_event", Callable(self, "_on_area_input"))

func _on_area_input(camra, event, click_position, click_normal, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", id)

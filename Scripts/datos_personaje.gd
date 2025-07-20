extends Node
class_name Stats

@export var unitName      : String = ""
@export var level         : int    = 1
@export var exp           : float  = 0.0
@export var unitclass     : int    = 0
@export var unitSubClass  : int    = 0
@export var life          : int    = 0
@export var def           : int    = 0
@export var hot_def       : int    = 0
@export var shake_def     : int    = 0
@export var cold_def      : int    = 0
@export var light_def     : int    = 0
@export var id_map        : int    = 0
@export var x_pos         : float  = 0.0
@export var z_pos         : float  = 0.0

func set_unit_name(value: String) -> void:
	unitName = value

func set_level(value: int) -> void:
	level = max(value, 1)

func set_exp(value: float) -> void:
	exp = clamp(value, 0.0, INF)

func set_unit_class(value: int) -> void:
	unitclass = value

func set_unit_sub_class(value: int) -> void:
	unitSubClass = value

func set_life(value: int) -> void:
	life = max(value, 0)

func set_def(value: int) -> void:
	def = max(value, 0)

func set_hot_def(value: int) -> void:
	hot_def = max(value, 0)

func set_shake_def(value: int) -> void:
	shake_def = max(value, 0)

func set_cold_def(value: int) -> void:
	cold_def = max(value, 0)

func set_light_def(value: int) -> void:
	light_def = max(value, 0)

func set_id_map(value: int) -> void:
	id_map = value

func set_x_pos(value: float) -> void:
	x_pos = value

func set_z_pos(value: float) -> void:
	z_pos = value

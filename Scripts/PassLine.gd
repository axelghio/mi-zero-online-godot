extends LineEdit
class_name PassLine

@export var eye_open   : Texture2D
@export var eye_closed : Texture2D

# Texturas ya redimensionadas
var eye_open_small   : Texture2D
var eye_closed_small : Texture2D

func _ready() -> void:
	# 1) Creamos las versiones 24×24
	eye_open_small   = _scale_to(eye_open,   24, 24)
	eye_closed_small = _scale_to(eye_closed, 24, 24)

	# 2) Arrancamos en modo oculto con ojo cerrado
	secret     = true
	right_icon = eye_closed_small

	# 3) Conectamos el clic
	connect("gui_input", Callable(self, "_on_gui_input"))

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		var icon_w = right_icon.get_size().x
		if event.position.x >= size.x - icon_w:
			secret = not secret
			right_icon = eye_closed_small if secret else eye_open_small
			accept_event()

# Función privada para escalar texturas
func _scale_to(orig: Texture2D, w: int, h: int) -> Texture2D:
	var img = orig.get_image()
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

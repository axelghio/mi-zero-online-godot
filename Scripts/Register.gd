extends Control

signal show_login
signal register_pressed(username: String, pass_hash: String)

@onready var user_line    : LineEdit  = $PanelBox/Box/UserLine
@onready var pass1_line   : PassLine  = $PanelBox/Box/PassLine
@onready var pass2_line   : PassLine  = $PanelBox/Box/PassLine2
@onready var btn_register : Button    = $PanelBox/Box/BtnRow/BtnRegister
@onready var btn_back     : Button    = $PanelBox/Box/BtnRow/BtnBack
@onready var lbl_error    : Label     = $PanelBox/Box/ErrorLabel

func _ready() -> void:
	# Conectar botón y respuesta del servidor
	btn_register.pressed.connect(_on_register_pressed)
	btn_back.pressed.connect(func(): emit_signal("show_login"))
	Net.connect("register_response", Callable(self, "_on_register_response"))
	lbl_error.text = ""

func _on_register_pressed() -> void:
	var u  = user_line.text.strip_edges()
	var p1 = pass1_line.text
	var p2 = pass2_line.text

	if u == "":
		_show_error("Usuario vacío")
		return

	if p1.length() < 6:
		_show_error("La contraseña debe tener al menos 6 caracteres")
		return

	if p1 != p2:
		_show_error("Las contraseñas no coinciden")
		return

	# Calcular hash SHA256
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(p1.to_utf8_buffer())
	var pass_hash = ctx.finish().hex_encode()

	# Emitir señal para que Main.gd maneje el registro
	emit_signal("register_pressed", u, pass_hash)

func _on_register_response(success: bool, message: String) -> void:
	if success:
		# Registro exitoso: volver a la pantalla de login
		emit_signal("show_login")
	else:
		_show_error(message)

func _show_error(msg: String) -> void:
	lbl_error.text = msg

# Opcional: obtener el último usuario ingresado
func get_last_registered_user() -> String:
	return user_line.text.strip_edges()

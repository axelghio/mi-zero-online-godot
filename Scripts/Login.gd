extends Control

signal login_pressed(username: String, pass_hash: String)
signal show_register
signal login_success

var _last_user_id: int = -1
@onready var user_line    : LineEdit = $PanelBox/Box/UserLine
@onready var pass_line    : PassLine  = $PanelBox/Box/PassLine
@onready var btn_login    : Button    = $PanelBox/Box/BtnLogin
@onready var btn_register : Button    = $PanelBox/Box/BtnRow/BtnRegister
@onready var btn_recover  : Button    = $PanelBox/Box/BtnRow/BtnRecover
@onready var lbl_error    : Label     = $PanelBox/Box/ErrorLabel

func _ready() -> void:
	btn_login.pressed.connect(_on_login_pressed)
	btn_register.pressed.connect(func(): emit_signal("show_register"))
	btn_recover.pressed.connect(_on_recover_pressed)
	lbl_error.text = ""

func _on_login_pressed() -> void:
	var u = user_line.text.strip_edges()
	var p = pass_line.text
	if u == "":
		_show_error("Debe ingresar un usuario")
		return
	if p == "":
		_show_error("Debe ingresar una contraseña")
		return

	# calcula el hash
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(p.to_utf8_buffer())
	var pass_hash = ctx.finish().hex_encode()

	# emitimos a Main.gd
	emit_signal("login_pressed", u, pass_hash)

func _on_login_response(success: bool, user_id: int) -> void:
	_last_user_id = user_id
	if success:
		emit_signal("login_success")
	else:
		if user_id == -2:
			_show_error("Este usuario ya está conectado.")
		else:
			_show_error("Usuario o contraseña incorrectos.")

func _on_recover_pressed() -> void:
	_show_error("Funcionalidad de recuperación no implementada")

func _show_error(msg: String) -> void:
	lbl_error.text = msg

func get_last_login_user_id() -> int:
	return _last_user_id

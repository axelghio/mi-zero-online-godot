extends CharacterBody3D
class_name Movement

# ─────────────────────────  ajustes propios  ────────────────────────────────
@export var base_speed      : float = 5.0
@export var dash_multiplier : float = 4.0
@export var dash_duration   : float = 0.2
@export var dash_cooldown   : float = 1.0

@export var send_rate_hz    : int   = 20        # ► cuántas veces/s envío mi transform

@onready var nav_agent := $NavAgent

# ── Estado interno para sincronización ────────────────────────────────────
var _authority_id      : int            # Peer ID que controla esta instancia
var _send_accum        : float = 0.0    # contador para enviar cada 1/Hz
var _net_pos           : Vector3        # última posición recibida
var _net_rot           : Basis          # última rotación recibida
var _last_sent_pos     : Vector3        # almacena la posición de la última transmisión

# ── Estado dash ───────────────────────────────────────────────────────────
var dash_active         : bool  = false
var dash_duration_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
# ────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Guardamos quién es el peer dueño de esta instancia
	_authority_id = get_multiplayer_authority()

	if is_multiplayer_authority():
		# Jugador local: activo inputs y NavAgent
		print("Authority, peer ID:", _authority_id)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		nav_agent.enabled = true
		_last_sent_pos = global_position
	else:
		# Réplica remota: desactivo NavAgent y preparo interpolación
		nav_agent.enabled = false
		_net_pos = global_position
		_net_rot = global_transform.basis
		# Conecto la señal de Net para recibir updates
		Net.connect("apply_transform", Callable(self, "_on_network_transform"))


func _unhandled_input(ev: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if ev is InputEventMouseButton \
	and ev.button_index == MOUSE_BUTTON_LEFT \
	and ev.pressed and not ev.is_echo():
		_on_click(ev.position)


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		# — lógica local de movimiento —
		_update_dash_timers(delta)
		_process_movement(delta)
		move_and_slide()

		# — SYNC: enviamos solo si realmente nos movemos y según la tasa —
		if velocity.length() > 0.0:
			_send_accum += delta
			if _send_accum >= 1.0 / send_rate_hz:
				_send_accum = 0.0
				if global_position.distance_to(_last_sent_pos) > 0.01:
					_last_sent_pos = global_position
					# enviamos por RPC no fiable al servidor (peer 1)
					Net.rpc_unreliable_id(
						1,                  # peer 1 = servidor
						"relay_transform",  # @rpc("any_peer","unreliable") en Net.gd
						_authority_id,
						global_position,
						global_transform.basis
					)
					print("→ Envío transform", global_position)
	else:
		# — SYNC: interpolo posición/rotación recibidas —
		global_position = global_position.lerp(_net_pos, 0.18)
		var tgt := global_transform
		tgt.basis = _net_rot
		global_transform = global_transform.interpolate_with(tgt, 0.18)


func _update_dash_timers(delta: float) -> void:
	if dash_active:
		dash_duration_timer -= delta
		if dash_duration_timer <= 0.0:
			dash_active = false
			dash_cooldown_timer = dash_cooldown
	elif dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta


func _process_movement(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var next_pos = nav_agent.get_next_path_position()
	var dir      = (next_pos - global_position).normalized()
	var speed    = base_speed * (dash_multiplier if dash_active else 1.0)
	velocity.x   = dir.x * speed
	velocity.z   = dir.z * speed


func _on_click(screen_pos: Vector2) -> void:
	var cam  = get_viewport().get_camera_3d()
	var from = cam.project_ray_origin(screen_pos)
	var to   = from + cam.project_ray_normal(screen_pos) * 1000.0
	var res  = get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to)
	)
	if not res:
		return
	nav_agent.set_target_position(res.position)


# ── HANDLER de la señal de Net ─────────────────────────────────────────────
func _on_network_transform(player_id: int, pos: Vector3, rot: Basis) -> void:
	# Cada réplica aplica solo si coincide con su peer ID
	if player_id != _authority_id:
		return
	_net_pos = pos
	_net_rot = rot
	print("← Recibí transform", pos)

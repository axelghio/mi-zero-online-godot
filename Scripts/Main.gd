extends Node

const MAP_SCENES = {
	1: preload("res://Scenes/StarShip.tscn"),
	2: preload("res://Scenes/StarShip2.tscn"),
}

@export var server_ip   : String = "127.0.0.1"
@export var server_port : int    = 9000

@onready var world_root    : Node    = $WorldRoot
@onready var players_node  : Node    = $Players
@onready var login_ui      : Control = $UI/LoginUI
@onready var register_ui   : Control = $UI/RegisterUI
@onready var npcs_root     : Node    = $npcs_root
@onready var cam_rig       : CameraRig = $CameraRig

var _ready_for_rpc   : bool = false
var _current_user_id : int  = -1
var _current_map_id: int = 0
var _current_map_node: Node = null

func _ready() -> void:
	# 1) Configurar cliente ENet
	var mp   = SceneMultiplayer.new()
	var enet = ENetMultiplayerPeer.new()
	var err  = enet.create_client(server_ip, server_port)
	if err != OK:
		push_error("❌ No se pudo conectar al servidor: %s" % err)
		return
	mp.multiplayer_peer = enet
	get_tree().set_multiplayer(mp)
	# 2) Conectar handshake
	mp.connected_to_server.connect(Callable(self, "_on_connected_ok"))
	mp.connection_failed.connect(Callable(self, "_on_connected_fail"))

	# 3) Estado inicial: solo LoginUI visible
	world_root.visible    = false
	players_node.visible  = false
	login_ui.visible      = true
	register_ui.visible   = false

	# 4) Señales UI
	login_ui.connect("login_pressed",   Callable(self, "_on_login_pressed"))
	login_ui.connect("show_register",   Callable(self, "_on_show_register"))
	register_ui.connect("register_pressed", Callable(self, "_on_register_pressed"))
	register_ui.connect("show_login",      Callable(self, "_on_show_login"))

	# 5) Señales Net  
	Net.connect("login_response",       Callable(self, "_on_login_response"))
	Net.connect("register_response",    Callable(self, "_on_register_response"))
	Net.connect("set_current_map",      Callable(self, "_on_set_current_map"))
	Net.connect("spawn_npc",            Callable(self, "_on_spawn_npc"))
	Net.connect("spawn_player",         Callable(self, "_on_spawn_player"))
	Net.connect("despawn_player",       Callable(self, "_on_despawn_player"))
	Net.connect("apply_char_stats",     Callable(self, "_on_apply_char_stats"))
func _on_connected_ok() -> void:
	print("✅ Handshake completado. Ya puedes hacer login.")
	_ready_for_rpc = true

func _on_connected_fail() -> void:
	push_error("❌ Falló handshake con el servidor")

func _on_show_register() -> void:
	login_ui.visible    = false
	register_ui.visible = true

func _on_show_login() -> void:
	register_ui.visible = false
	login_ui.visible    = true

func _on_close_login() -> void:
	login_ui.visible    = false

# ——— Login ———————————————————————————————————————————————

func _on_login_pressed(username: String, pass_hash: String) -> void:
	var err_lbl = login_ui.get_node("PanelBox/Box/ErrorLabel") as Label
	err_lbl.text = ""
	if not _ready_for_rpc:
		err_lbl.text = "⏳ Esperando conexión..."
		return
	Net.rpc_id(1, "rpc_login", username, pass_hash)

func _on_login_response(success: bool, user_id: int) -> void:
	var err_lbl = login_ui.get_node("PanelBox/Box/ErrorLabel") as Label
	if success:
		_current_user_id = user_id
		_on_close_login()
		world_root.visible   = true
		players_node.visible = true
		Net.rpc_id(1, "rpc_request_spawn_char", _current_user_id)
	else:
		if user_id == -2:
			err_lbl.text = "Este usuario ya está conectado."
		else:
			err_lbl.text = "Usuario o contraseña incorrectos."

# ——— Register ————————————————————————————————————————————

func _on_register_pressed(username: String, pass_hash: String) -> void:
	var err_lbl = register_ui.get_node("PanelBox/Box/ErrorLabel") as Label
	err_lbl.text = ""
	if not _ready_for_rpc:
		err_lbl.text = "⏳ Esperando conexión..."
		return
	Net.rpc_id(1, "rpc_register", username, pass_hash)

func _on_register_response(success: bool, message: String) -> void:
	if success:
		_on_show_login()
	else:
		var err_lbl = register_ui.get_node("PanelBox/Box/ErrorLabel") as Label
		err_lbl.text = message

# ——— Mapa & NPCs ————————————————————————————————————————

func _on_set_current_map(map_id: int) -> void:
	if _current_map_node:
		_current_map_node.queue_free()
		_clear_peers()
		_clear_npcs()
	_current_map_id = map_id
	var scene_res = MAP_SCENES.get(map_id, 1)
	if scene_res == null:
		push_error("Main: no existe escena para map_id=%d" % map_id)
		return
	_current_map_node = scene_res.instantiate()
	world_root.add_child(_current_map_node)
	Net.rpc_id(1, "rpc_request_npcs", map_id)
	
func _on_spawn_npc(npc_id: int, map_id: int, pos: Vector3, npc_name: String) -> void:
	if map_id != _current_map_id:
		return
	var npc_scene = preload("res://Scenes/NPC.tscn")
	var npc = npc_scene.instantiate()
	npc.position = pos
	npc.name = "NPC_%d" % npc_id
	npc.set("npc_name", npc_name)
	npcs_root.add_child(npc)

func _on_spawn_player(list_of_spawns: Array) -> void:
	# Si soy el servidor, salgo inmediatamente
	if multiplayer.is_server():
		return
	
	for spawn_info in list_of_spawns:
		var peer_id = spawn_info.id as int
		var node_name = "Peer_%d" % peer_id

		if players_node.has_node(node_name):
			continue

		var xf      = spawn_info.xf as Transform3D
		var ply_scene = preload("res://Scenes/player.tscn")
		var ply = ply_scene.instantiate()
		ply.name = "Peer_%d" % peer_id
		ply.global_transform = xf
		players_node.add_child(ply)
		ply.set_multiplayer_authority(peer_id)
		print("✔ Instanciado jugador Peer_%d" % peer_id)
		if peer_id == multiplayer.get_unique_id():
			cam_rig.target = ply
			print("🎯 Cámara asignada a mi jugador")
	print("✅ rpc_spawn_player ha terminado.")

func _on_despawn_player(peer_id: int) -> void:
	var node_name = "Peer_%d" % peer_id
	if players_node.has_node(node_name):
		players_node.get_node(node_name).queue_free()

func _clear_node(parent: Node):
	for c in parent.get_children():
		c.queue_free()

func _on_apply_char_stats(peer_id: int, stats_char_db: Array) -> void:
	if stats_char_db.size() > 0:
		print("No llegaron stats del personaje")
		return
	print("llegaron stats del personaje")
	var stats_dict := stats_char_db[0] as Dictionary
	var players_parent := $Players
	var player_name := "Peer_%d" % peer_id
	if not players_parent.has_node(player_name):
		push_error("No existe ningún Player con id %d" % peer_id)
		return
	print("Encontre personaje")
	var player := players_parent.get_node(player_name)
	var stats_node: Stats
	if player.has_node("Stats"):
		stats_node = player.get_node("Stats") as Stats
		print("Asignando a %s " % str(player))
	else:
		stats_node = Stats.new()
		stats_node.name = "Stats"
		player.add_child(stats_node)
	stats_node.unitName     = stats_dict["unitName"]
	stats_node.level        = stats_dict["level"]
	stats_node.exp          = stats_dict["exp"]
	stats_node.life         = stats_dict["life"]
	stats_node.def          = stats_dict["def"]
	stats_node.hot_def      = stats_dict["hot_def"]
	stats_node.shake_def    = stats_dict["shake_def"]
	stats_node.cold_def     = stats_dict["cold_def"]
	stats_node.light_def    = stats_dict["light_def"]
	stats_node.id_map       = stats_dict["id_map"]
	stats_node.x_pos        = stats_dict["x_pos"]
	stats_node.z_pos        = stats_dict["z_pos"]
	print("Se asignaron las stats")

func _clear_peers() -> void:
	for child in players_node.get_children():
		if child.name.begins_with("Peer_"):
			child.queue_free()

func _clear_npcs() -> void:
	for child in npcs_root.get_children():
		child.queue_free()

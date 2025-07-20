extends Node
class_name GameManager

@export var player_scene : PackedScene
@export var npc_scene    : PackedScene
@export var players_root : Node
@export var npcs_root    : Node
@export var cam_rig      : CameraRig
var _ready_for_rpc := false

func _ready() -> void:
	var mp = get_tree().get_multiplayer()
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	mp.connected_to_server.connect(_on_connected_ok)
	mp.connection_failed.connect(_on_connected_fail)

func _on_connected_ok() -> void:
	print("✅ ENet handshake completado. Puedes hacer login ahora.")
	_ready_for_rpc = true

func _on_connected_fail() -> void:
	push_error("❌ No se pudo conectar al servidor")

func _on_peer_connected(id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	var node_name = "Peer_%d" % id
	if players_root.has_node(node_name):
		players_root.get_node(node_name).queue_free()

func _on_npc_clicked(npc_id: int) -> void:
	print("Interactuando con NPC:", npc_id)

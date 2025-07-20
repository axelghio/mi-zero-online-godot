extends Node

var server_node: Node = null
signal login_response(success: bool, user_id: int)
signal register_response(success: bool, message: String)
signal set_current_map(map_id: int)
signal spawn_player(list_of_spawns: Array)
signal despawn_player(peer_id: int)
signal spawn_npc(npc_id: int, map_id: int, pos: Vector3, npc_name: String)
signal apply_transform(player_id: int, pos: Vector3, rot: Basis)
signal apply_char_stats(peer_id: int, stats_char_db: Array)

@rpc("any_peer", "reliable")
func rpc_login(username: String, pass_hash: String) -> void:
	if server_node:
		server_node.rpc_login(username, pass_hash)
	else:
		push_error("Net: server_node no asignado")

@rpc("any_peer", "reliable")
func rpc_register(username: String, pass_hash: String) -> void:
	if server_node:
		server_node.rpc_register(username, pass_hash)
	else:
		push_error("Net: server_node no asignado")

@rpc("any_peer", "reliable")
func rpc_request_spawn_char(user_id: int) -> void:
	if server_node:
		server_node.rpc_request_spawn_char(user_id)
	else:
		push_error("Net: server_node no asignado")

@rpc("any_peer", "reliable")
func rpc_request_npcs(map_id: int) -> void:
	if server_node:
		server_node.rpc_request_npcs(map_id)
	else:
		push_error("Net: server_node no asignado")

@rpc("call_remote", "reliable")
func rpc_login_response(success: bool, user_id: int) -> void:
	emit_signal("login_response", success, user_id)

@rpc("call_remote", "reliable")
func rpc_register_response(success: bool, message: String) -> void:
	emit_signal("register_response", success, message)

@rpc("call_remote", "reliable")
func rpc_set_current_map(map_id: int) -> void:
	emit_signal("set_current_map", map_id)

@rpc("call_remote", "reliable")
func rpc_spawn_player(list_of_spawns: Array) -> void:
	emit_signal("spawn_player", list_of_spawns)

@rpc("call_remote", "reliable")
func rpc_despawn_player(peer_id: int) -> void:
	emit_signal("despawn_player", peer_id)

@rpc("call_remote", "reliable")
func rpc_spawn_npc(npc_id: int, map_id: int, pos: Vector3, npc_name: String) -> void:
	emit_signal("spawn_npc", npc_id, map_id, pos, npc_name)

@rpc("any_peer", "unreliable")
func relay_transform(player_id: int, pos: Vector3, rot: Basis) -> void:
	if not multiplayer.is_server():
		return
	rpc("rpc_apply_transform", player_id, pos, rot)

@rpc("call_remote", "unreliable")
func rpc_apply_transform(player_id: int, pos: Vector3, rot: Basis) -> void:
	emit_signal("apply_transform", player_id, pos, rot)

@rpc("call_remote", "reliable")
func rpc_character_load(peer_id: int, stats_char_db: Array) -> void:
	print("llegaron las stats rpc_character_load")
	emit_signal("apply_char_stats", peer_id, stats_char_db)
	print("se enviaron las stats rpc_character_load")

func _next_spawn_transform() -> Transform3D:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var t = Transform3D.IDENTITY
	t.origin = Vector3(rng.randf_range(-5,5), 0.5, rng.randf_range(-5,5))
	return t

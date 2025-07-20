# Server.gd
extends Node3D

const SERVER_SCENE_NAME : String = "ServerRoot"
const SERVER_PORT       : int    = 9000
const MAX_CLIENTS       : int    = 8
const DEFAULT_MAP_ID    : int    = 1
var db := SQLite.new()
var user_sessions := {}
var players := {}
@onready var sm := SceneMultiplayer.new()

func _ready() -> void:
	Net.server_node = self
	db.path = "user://Server.db"
	if not db.open_db():
		Console.log("❌ ERROR abriendo la DB")
		return
	Console.log("✅ DB lista")
	db.query("PRAGMA foreign_keys = ON;")
	db.query("""
	CREATE TABLE IF NOT EXISTS users (
		id        INTEGER PRIMARY KEY AUTOINCREMENT,
		username  TEXT UNIQUE,
		password  TEXT
	);
	""")
	db.query("""
	CREATE TABLE IF NOT EXISTS maps (
		id           INTEGER PRIMARY KEY AUTOINCREMENT,
		name         TEXT UNIQUE,
		x_pos        FLOAT NOT NULL,
		z_pos        FLOAT NOT NULL,
		req_lv_min   INTEGER NOT NULL,
		req_lv_max   INTEGER NOT NULL
	);
	""")
	db.query("""
	INSERT OR IGNORE INTO maps (
		id, name, x_pos, z_pos, req_lv_min, req_lv_max
	) VALUES (
		1, 'Default Spawn', 0.0, 0.0, 1, 170
	);
	""")
	db.query("""
	CREATE TABLE IF NOT EXISTS character (
		id          INTEGER PRIMARY KEY AUTOINCREMENT,
		id_user     INTEGER UNIQUE,
		name        TEXT,
		level       INTEGER DEFAULT 1,
		exp         REAL    DEFAULT 0,
		life        INTEGER DEFAULT 100,
		def         INTEGER DEFAULT 10,
		hot_def     INTEGER DEFAULT 0,
		shake_def   INTEGER DEFAULT 0,
		cold_def    INTEGER DEFAULT 0,
		light_def   INTEGER DEFAULT 0,
		id_map      INTEGER NOT NULL,
		x_pos       FLOAT   NOT NULL,
		z_pos       FLOAT   NOT NULL,
		FOREIGN KEY(id_user) REFERENCES users(id) ON DELETE CASCADE,
		FOREIGN KEY(id_map)  REFERENCES maps(id) ON DELETE CASCADE
	);
	""")
	db.query("""
	CREATE TABLE IF NOT EXISTS items (
		id              INTEGER PRIMARY KEY AUTOINCREMENT,
		id_action       INTEGER,
		name            TEXT,
		level           INTEGER DEFAULT 1,
		price           INTEGER DEFAULT 100,
		durability      INTEGER DEFAULT 1,
		max_ene         INTEGER DEFAULT 0,
		max_pow         INTEGER DEFAULT 0,
		charge_pow      INTEGER DEFAULT 0,
		amount          INTEGER DEFAULT 1,
		equip_level     INTEGER DEFAULT 0,
		min_atk         INTEGER DEFAULT 0,
		max_atk         INTEGER DEFAULT 0,
		hot_atk         INTEGER DEFAULT 0,
		shake_atk       INTEGER DEFAULT 0,
		sting_atk       INTEGER DEFAULT 0,
		decay_atk       INTEGER DEFAULT 0,
		defence_max     INTEGER DEFAULT 0,
		defence_percent INTEGER DEFAULT 0,
		hot_def         INTEGER DEFAULT 0,
		shake_def       INTEGER DEFAULT 0,
		cold_def        INTEGER DEFAULT 0,
		light_def       INTEGER DEFAULT 0,
		emoney          INTEGER DEFAULT 1000
	);
	""")
	db.query("""
	CREATE TABLE IF NOT EXISTS equipment (
		id           INTEGER PRIMARY KEY AUTOINCREMENT,
		id_char      INTEGER,
		id_item      INTEGER,
		equip_level  INTEGER DEFAULT 0,
		tier         INTEGER DEFAULT 0,
		FOREIGN KEY(id_char) REFERENCES character(id) ON DELETE CASCADE,
		FOREIGN KEY(id_item) REFERENCES items(id)
	);
	""")
	db.query("""
	CREATE TABLE IF NOT EXISTS quests_def (
		id               INTEGER PRIMARY KEY AUTOINCREMENT,
		title            TEXT,
		description      TEXT,
		level_required   INTEGER DEFAULT 1,
		is_repeatable    BOOLEAN DEFAULT 0,
		reward_item_id   INTEGER NULL,
		FOREIGN KEY(reward_item_id) REFERENCES items(id)
	);
	""")
	db.query("""
	CREATE TABLE IF NOT EXISTS npcs (
		id           INTEGER PRIMARY KEY AUTOINCREMENT,
		name         TEXT    UNIQUE,
		type         INTEGER,
		id_map       INTEGER NOT NULL,
		x_pos        FLOAT   NOT NULL,
		z_pos        FLOAT   NOT NULL,
		id_quest     INTEGER NULL,
		FOREIGN KEY(id_quest) REFERENCES quests_def(id) ON DELETE CASCADE,
		FOREIGN KEY(id_map)   REFERENCES maps(id)       ON DELETE CASCADE
	);
	""")
	db.query("""
	CREATE TABLE IF NOT EXISTS player_quests (
		player_id    INTEGER,
		quest_id     INTEGER,
		status       TEXT,
		progress     INTEGER DEFAULT 0,
		started_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
		completed_at DATETIME NULL,
		PRIMARY KEY(player_id, quest_id),
		FOREIGN KEY(player_id) REFERENCES users(id),
		FOREIGN KEY(quest_id)  REFERENCES quests_def(id)
	);
	""")
	Console.log("✅ Tablas creadas correctamente.")
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(SERVER_PORT, MAX_CLIENTS)
	if err != OK:
		Console.log("❌ No se pudo crear ENet host (err=%d)" % err)
		return
	sm.multiplayer_peer = peer
	get_tree().set_multiplayer(sm)
	Console.log("🎧 Servidor ENet escuchando en UDP:%d" % SERVER_PORT)
	sm.peer_connected.connect(_on_peer_connected)
	sm.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int) -> void:
	Console.log("➕ Peer conectado: %d" % id)

func _on_peer_disconnected(id: int) -> void:
	for user_id in user_sessions.keys():
		if user_sessions[user_id] == id:
			user_sessions.erase(user_id)
			break
	Net.rpc("rpc_despawn_player", id)
	if players.has(id):
		players.erase(id)
	Console.log("➖ Peer desconectado: %d" % id)

@rpc("any_peer","reliable")
func rpc_register(username: String, pass_hash: String) -> void:
	if not multiplayer.is_server():
		return
	var safe_user = username.replace("'", "''")
	var safe_pass = pass_hash.replace("'", "''")
	var ok        = db.insert_row("users", {"username": safe_user, "password": safe_pass})
	var peer_id   = multiplayer.get_remote_sender_id()
	if ok:
		var new_char = {
			"name":username, "level":1, "exp":0.0, "life":100, "def":10,
			"hot_def":0, "shake_def":0, "cold_def":0, "light_def":0,
			"id_map":DEFAULT_MAP_ID, "x_pos":0.0, "z_pos":0.0
		}
		var new_char_ok = db.insert_row("character", new_char)
		if new_char_ok:
			Console.log("✅ Nuevo character creado correctamente.")
		Net.rpc_id(peer_id, "rpc_register_response", true, "")
		Console.log("✅ Registro OK: %s" % safe_user)
	else:
		Net.rpc_id(peer_id, "rpc_register_response", false, "Usuario ya existe")
		Console.log("❌ Registro FALLIDO: %s" % safe_user)

@rpc("any_peer","reliable")
func rpc_login(username: String, pass_hash: String) -> void:
	if not multiplayer.is_server():
		return
	var safe_user = username.replace("'", "''")
	var safe_pass = pass_hash.replace("'", "''")
	var rows      = db.select_rows(
		"users",
		"username = '%s' AND password = '%s'" % [safe_user, safe_pass],
		["id"]
	)
	var peer_id = multiplayer.get_remote_sender_id()
	if rows.size() == 0:
		Net.rpc_id(peer_id, "rpc_login_response", false, -1)
		Console.log("❌ Login fallido: credenciales")
		return
	var row     = rows[0]
	var user_id = (row if typeof(row) == TYPE_INT else row.get("id", -1))
	if user_sessions.has(user_id):
		Net.rpc_id(peer_id, "rpc_login_response", false, -2)
		Console.log("❌ Login fallido: ya conectado")
		return
	user_sessions[user_id] = peer_id
	Net.rpc_id(peer_id, "rpc_login_response", true, user_id)
	Console.log("✅ Login OK: %s (id=%d)" % [safe_user, user_id])

@rpc("call_remote","reliable")
func rpc_request_spawn_char(user_id: int) -> void:
	if not multiplayer.is_server():
		return

	var peer_id = multiplayer.get_remote_sender_id()
	var cols_Char = [
		"name", "level", "exp", "life", "def", "hot_def",
		"shake_def", "cold_def", "light_def", "id_map",
		"x_pos", "z_pos"
	]
	var rows = db.select_rows("character", "id_user = %d" % user_id, cols_Char)
	var xf: Transform3D
	var stats_char_db : Array = []
	var map_id : int
	if rows.size() > 0:
		var r = rows[0]
		stats_char_db.append({
			"unitName":    r.get("name", ""),
			"level":       r.get("level", 1),
			"exp":         r.get("exp", 0.0),
			"life":        r.get("life", 100),
			"def":         r.get("def", 10),
			"hot_def":     r.get("hot_def", 0),
			"shake_def":   r.get("shake_def", 0),
			"cold_def":    r.get("cold_def", 0),
			"light_def":   r.get("light_def", 0),
			"id_map":      r.get("id_map", DEFAULT_MAP_ID),
			"x_pos":       r.get("x_pos", 0.0),
			"z_pos":       r.get("z_pos", 0.0)
		})
		if stats_char_db.size() > 0:
			var stats = stats_char_db[0]
			map_id = stats["id_map"]
			xf = Transform3D(Basis(), Vector3(stats["x_pos"], 0.5, stats["z_pos"]))
			players[peer_id] = {
				"xf": xf,
				"map": map_id
			}
	Net.rpc_id(peer_id, "rpc_set_current_map", map_id)
	print("llamemos a rpc_character_load")
	Net.rpc("rpc_character_load", peer_id, stats_char_db)
	print("ya lo llamamos a rpc_character_load")
	var list_of_spawns := []
	for id in players.keys():
		var info = players[id]
		if info["map"] == map_id:
			list_of_spawns.append({
				"id":  id,
				"xf":  info["xf"],
			})
	Net.rpc("rpc_spawn_player", list_of_spawns)
	Console.log("📦 Spawn peer %d en %s" % [peer_id, xf.origin])

@rpc("any_peer","reliable")
func rpc_request_npcs(map_id: int) -> void:
	if not multiplayer.is_server():
		return
	var rows = db.select_rows("npcs", "id_map = %d" % map_id, ["id","x_pos","z_pos","name"])
	for r in rows:
		var npc_id : int  = int(r["id"])
		var pos : Vector3 = Vector3(r["x_pos"], 0.7, r["z_pos"])
		var npc_name : String = str(r["name"])
		Net.rpc("rpc_spawn_npc", npc_id, map_id, pos, npc_name)

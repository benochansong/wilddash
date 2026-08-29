extends Node

signal session_changed(active: bool, hosting: bool)
signal roster_changed(players: Dictionary)
signal connection_status_changed(message: String)
signal host_left

const DEFAULT_PORT := 24567
const MAX_HUMAN_PLAYERS := 8

var session_active := false
var hosting := false
var party_game_active := false
var players: Dictionary = {}
var _pending_name := "PLAYER"
var _pending_animal: StringName = &"dog"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_party(display_name: String, animal_id: StringName, port := DEFAULT_PORT) -> Error:
	leave_party(false)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_HUMAN_PLAYERS - 1)
	if error != OK:
		connection_status_changed.emit("HOST FAILED: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	session_active = true
	hosting = true
	party_game_active = false
	_pending_name = _sanitize_name(display_name)
	_pending_animal = _sanitize_animal(animal_id)
	players.clear()
	players[1] = _player_state(1, _pending_name, _pending_animal, false)
	_broadcast_roster()
	session_changed.emit(true, true)
	connection_status_changed.emit("PARTY CREATED · PORT %d" % port)
	return OK

func join_party(address: String, display_name: String, animal_id: StringName, port := DEFAULT_PORT) -> Error:
	leave_party(false)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		connection_status_changed.emit("JOIN FAILED: %s" % error_string(error))
		return error
	_pending_name = _sanitize_name(display_name)
	_pending_animal = _sanitize_animal(animal_id)
	multiplayer.multiplayer_peer = peer
	session_active = true
	hosting = false
	party_game_active = false
	players.clear()
	session_changed.emit(true, false)
	connection_status_changed.emit("CONNECTING TO %s:%d" % [address.strip_edges(), port])
	return OK

func leave_party(emit_signal := true) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_active = false
	hosting = false
	party_game_active = false
	players.clear()
	if emit_signal:
		session_changed.emit(false, false)
		roster_changed.emit({})

func is_party_active() -> bool:
	return session_active

func is_host() -> bool:
	return session_active and hosting

func get_players() -> Dictionary:
	return players.duplicate(true)

func get_local_peer_id() -> int:
	return multiplayer.get_unique_id() if session_active else 1

func get_local_state() -> Dictionary:
	var peer_id := get_local_peer_id()
	if players.has(peer_id):
		return (players[peer_id] as Dictionary).duplicate(true)
	return _player_state(peer_id, _pending_name, _pending_animal, false)

func set_local_name(value: String) -> void:
	_pending_name = _sanitize_name(value)
	if not session_active:
		return
	if hosting:
		_update_host_player_field(1, "display_name", _pending_name)
	else:
		rpc_id(1, "_server_set_name", _pending_name)

func set_local_animal(animal_id: StringName) -> void:
	_pending_animal = _sanitize_animal(animal_id)
	if not session_active:
		return
	if hosting:
		_update_host_player_field(1, "animal_id", String(_pending_animal))
	else:
		rpc_id(1, "_server_set_animal", String(_pending_animal))

func set_local_ready(ready: bool) -> void:
	if not session_active:
		return
	if hosting:
		_update_host_player_field(1, "ready", ready)
	else:
		rpc_id(1, "_server_set_ready", ready)

func can_start_party() -> bool:
	if not hosting or players.size() < 2:
		return false
	for state_value in players.values():
		var state := state_value as Dictionary
		if not bool(state.get("ready", false)):
			return false
	return true

func start_party_grand_prix() -> bool:
	if not can_start_party():
		connection_status_changed.emit("WAITING FOR 2+ READY PLAYERS")
		return false
	party_game_active = true
	rpc("_client_start_grand_prix", players.size())
	return true

func _recommended_ai_count(human_count: int) -> int:
	var target_total := 10 if human_count <= 4 else 12
	return maxi(4, target_total - human_count)

@rpc("authority", "call_local", "reliable")
func _client_start_grand_prix(human_count: int) -> void:
	party_game_active = true
	var local_state := get_local_state()
	var animal := _sanitize_animal(StringName(String(local_state.get("animal_id", "dog"))))
	var ai_count := _recommended_ai_count(human_count)
	GameManager.configure_run(animal, &"wild", {}, ai_count)
	GameManager.start_campaign()
	connection_status_changed.emit("PARTY GRAND PRIX START · HUMANS %d · AI %d" % [human_count, ai_count])

func _on_connected_to_server() -> void:
	var peer_id := multiplayer.get_unique_id()
	connection_status_changed.emit("CONNECTED · PEER %d" % peer_id)
	rpc_id(1, "_server_register_player", _pending_name, String(_pending_animal))

func _on_connection_failed() -> void:
	connection_status_changed.emit("CONNECTION FAILED")
	leave_party()

func _on_server_disconnected() -> void:
	connection_status_changed.emit("HOST LEFT PARTY")
	leave_party()
	host_left.emit()

func _on_peer_connected(peer_id: int) -> void:
	if hosting:
		connection_status_changed.emit("PEER %d CONNECTED" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if not hosting:
		return
	if players.has(peer_id):
		players.erase(peer_id)
		_broadcast_roster()
	connection_status_changed.emit("PEER %d LEFT" % peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _server_register_player(display_name: String, animal_text: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = _player_state(sender, _sanitize_name(display_name), _sanitize_animal(StringName(animal_text)), false)
	_broadcast_roster()

@rpc("any_peer", "call_remote", "reliable")
func _server_set_name(display_name: String) -> void:
	if not multiplayer.is_server():
		return
	_update_host_player_field(multiplayer.get_remote_sender_id(), "display_name", _sanitize_name(display_name))

@rpc("any_peer", "call_remote", "reliable")
func _server_set_animal(animal_text: String) -> void:
	if not multiplayer.is_server():
		return
	_update_host_player_field(multiplayer.get_remote_sender_id(), "animal_id", String(_sanitize_animal(StringName(animal_text))))

@rpc("any_peer", "call_remote", "reliable")
func _server_set_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	_update_host_player_field(multiplayer.get_remote_sender_id(), "ready", ready)

func _update_host_player_field(peer_id: int, field: String, value: Variant) -> void:
	if not players.has(peer_id):
		return
	var state := (players[peer_id] as Dictionary).duplicate(true)
	state[field] = value
	players[peer_id] = state
	_broadcast_roster()

func _broadcast_roster() -> void:
	if not hosting:
		return
	var snapshot: Array = []
	var peer_ids := players.keys()
	peer_ids.sort()
	for peer_id_value in peer_ids:
		snapshot.append((players[peer_id_value] as Dictionary).duplicate(true))
	rpc("_client_receive_roster", snapshot)

@rpc("authority", "call_local", "reliable")
func _client_receive_roster(snapshot: Array) -> void:
	players.clear()
	for value in snapshot:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var state := (value as Dictionary).duplicate(true)
		var peer_id := int(state.get("peer_id", 0))
		if peer_id > 0:
			players[peer_id] = state
	roster_changed.emit(get_players())

func _player_state(peer_id: int, display_name: String, animal_id: StringName, ready: bool) -> Dictionary:
	return {
		"peer_id": peer_id,
		"display_name": _sanitize_name(display_name),
		"animal_id": String(_sanitize_animal(animal_id)),
		"ready": ready,
		"connected": true,
		"finish_rank": 0,
		"score": 0,
	}

func _sanitize_name(value: String) -> String:
	var clean := value.strip_edges()
	if clean.is_empty():
		clean = "PLAYER"
	return clean.substr(0, 16)

func _sanitize_animal(value: StringName) -> StringName:
	return value if WildDashAnimalCatalog.is_playable(value) else &"dog"

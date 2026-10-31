extends Node
## One host, one guest. All gameplay commands are checked and resolved by host.
signal changed
const PROTOCOL: int = 1
const FACTIONS: Array[String] = ["帝国","联盟","混沌"]
var peer: ENetMultiplayerPeer
var status: String = "尚未连接"
var local_faction: String = "帝国"
var room_code: String = ""
var guest_id: int = 0
var bound_port: int = 24560
var match_state: Dictionary = {}
var elapsed: float = 0.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_failed)

func _process(delta: float) -> void:
	if status == "连接中":
		elapsed += delta
		if elapsed > 12: _failed()

func leave() -> void:
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	guest_id = 0
	match_state = {}
	status = "已离开房间"
	changed.emit()

func open_room(host: bool, address: String, port: int, code: String, faction: String) -> Error:
	if code.strip_edges().length() < 4 or code.strip_edges().length() > 16 or faction not in FACTIONS or port < 1024 or port > 65535:
		status = "房间口令需 4–16 字符，端口需 1024–65535。"
		changed.emit()
		return ERR_INVALID_PARAMETER
	leave()
	bound_port = port
	room_code = code.strip_edges()
	local_faction = faction
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port,1) if host else peer.create_client(address.strip_edges(),port)
	if error != OK:
		peer = null
		status = "连接失败：" + error_string(error)
		changed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	elapsed = 0
	status = "等待对手连接" if host else "连接中"
	changed.emit()
	return OK

func _peer_connected(id: int) -> void:
	if multiplayer.is_server():
		guest_id = id
		status = "对手已连接，校验房间口令"
		changed.emit()

func _connected() -> void:
	_join.rpc_id(1,PROTOCOL,room_code,local_faction)

func _failed() -> void:
	leave()
	status = "连接失败或房主离线；请核对地址、UDP 端口与网络。"
	changed.emit()

func _peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and id == guest_id:
		guest_id = 0
		if match_state.get("phase","") == "battle":
			match_state.phase = "ended"
			match_state.winner = 1
			match_state.log.push_front("对手断线，房主获胜。")
		status = "对手已离线；重新创建房间可再战。"
		changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func _join(protocol: int, code: String, faction: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != guest_id: return
	if not match_state.is_empty(): return
	if protocol != PROTOCOL or code != room_code or faction not in FACTIONS:
		_rejected.rpc_id(guest_id,"房间口令或协议版本不匹配。")
		return
	match_state = {"phase":"battle","turn":1,"active":1,"winner":0,"players":{1:_pilot(local_faction),guest_id:_pilot(faction)},"log":["双方接入战区。房主先手，击毁对方旗舰即胜。"],"revision":0}
	status = "对局进行中"
	_publish()

@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	leave()
	status = reason
	changed.emit()

static func _pilot(faction: String) -> Dictionary:
	return {"faction":faction,"hp":60,"shield":12 if faction=="帝国" else 8,"energy":3,"guard":false,"skill":false}

func my_id() -> int:
	return multiplayer.get_unique_id()

func play(action: String) -> void:
	if peer == null or match_state.is_empty(): return
	if multiplayer.is_server():
		resolve(1,action,int(match_state.revision))
	else:
		_command.rpc_id(1,action,int(match_state.revision))

@rpc("any_peer", "call_remote", "reliable")
func _command(action: String, revision: int) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != guest_id: return
	resolve(sender,action,revision)

func resolve(sender: int, action: String, revision: int) -> bool:
	if match_state.get("phase","") != "battle" or int(match_state.active) != sender or revision != int(match_state.revision): return false
	if action not in ["attack","heavy","guard","repair","skill","surrender"]: return false
	var players: Dictionary = match_state.players
	if not players.has(sender) or players.size() != 2: return false
	var other: int = 0
	for id in players:
		if int(id) != sender: other = int(id)
	var me: Dictionary = players[sender]
	var enemy: Dictionary = players[other]
	if action == "heavy" and int(me.energy) < 3: return false
	if action == "repair" and int(me.energy) < 2: return false
	if action == "skill" and me.skill: return false
	var damage: int = 0
	var report: String = str(me.faction)
	match action:
		"attack":
			damage = 10
			report += "主炮齐射"
		"heavy":
			me.energy -= 3
			damage = 19
			report += "发射重型鱼雷"
		"guard":
			me.guard = true
			me.shield = mini(20,int(me.shield)+5)
			report += "展开防御（下次伤害减半）"
		"repair":
			me.energy -= 2
			me.hp = mini(60,int(me.hp)+12)
			report += "紧急维修 +12"
		"skill":
			me.skill = true
			if me.faction == "帝国":
				me.shield = mini(30,int(me.shield)+18)
				report += "帝国壁垒：护盾 +18"
			elif me.faction == "联盟":
				me.hp = mini(60,int(me.hp)+16)
				me.energy = mini(5,int(me.energy)+2)
				report += "联盟补给：维修 +16 / 能量 +2"
			else:
				damage = 23
				report += "混沌过载：爆发 23"
		"surrender":
			me.hp = 0
			report += "投降"
	if damage > 0:
		if enemy.guard:
			damage = ceili(damage/2.0)
			enemy.guard = false
		var absorbed: int = mini(int(enemy.shield),damage)
		enemy.shield -= absorbed
		enemy.hp = maxi(0,int(enemy.hp)-(damage-absorbed))
		report += "，命中 %d（护盾吸收 %d）" % [damage,absorbed]
	match_state.log.push_front(report)
	if match_state.log.size() > 30: match_state.log.resize(30)
	match_state.revision += 1
	if int(enemy.hp) <= 0 or int(me.hp) <= 0:
		match_state.phase = "ended"
		match_state.winner = sender if int(enemy.hp)<=0 else other
	else:
		match_state.active = other
		match_state.turn += 1
		enemy.energy = mini(5,int(enemy.energy)+1)
	_publish()
	return true

func _publish() -> void:
	if peer != null and multiplayer.is_server() and guest_id != 0:
		_snapshot.rpc_id(guest_id,match_state)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _snapshot(snapshot: Dictionary) -> void:
	match_state = snapshot
	status = "对局结束" if match_state.phase == "ended" else "对局进行中"
	changed.emit()

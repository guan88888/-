extends SceneTree
const Network = preload("res://duel_network.gd")
var duel: Node
var host: bool
var scenario: String
var finished: bool = false
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	host = args[0]=="host"
	scenario = args[2]
	duel = Network.new()
	duel.name = "DuelNetwork"
	root.add_child(duel)
	duel.changed.connect(_changed)
	assert(duel.open_room(host,"127.0.0.1",int(args[1]),"WRONG" if not host and scenario=="reject" else "TESTROOM","联盟")==OK)
	await create_timer(10).timeout
	if not finished:
		push_error("failure-path timeout: " + duel.status)
		quit(1)
func _changed() -> void:
	if finished: return
	if scenario == "reject":
		if (not host and "不匹配" in duel.status) or (host and "对手已离线" in duel.status):
			assert(duel.match_state.is_empty())
			finish()
	elif not host and not duel.match_state.is_empty():
		duel.leave()
		finish()
	elif host and duel.match_state.get("phase","")=="ended":
		assert(int(duel.match_state.winner)==1)
		finish()
func finish() -> void:
	finished = true
	print("PASS network " + scenario + " " + ("host" if host else "guest"))
	await create_timer(0.2).timeout
	quit(0)

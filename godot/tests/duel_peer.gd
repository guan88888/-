extends SceneTree
const Network = preload("res://duel_network.gd")
var duel: Node
var role: String
var finished: bool = false
var last_revision: int = -1
var checks: int = 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	role = args[0]
	duel = Network.new()
	duel.name = "DuelNetwork"
	root.add_child(duel)
	duel.changed.connect(_changed)
	var error: Error = duel.open_room(role=="host","127.0.0.1",int(args[1]),"TESTROOM","帝国" if role=="host" else "混沌")
	if error != OK: quit(1); return
	await create_timer(15).timeout
	if not finished:
		push_error("Duel network timeout: " + role + " " + duel.status)
		quit(1)
func _changed() -> void:
	var s: Dictionary = duel.match_state
	if s.is_empty() or finished: return
	if s.phase == "ended":
		finished = true
		print("DUEL_RESULT " + role + " " + JSON.stringify(s))
		await create_timer(0.3).timeout
		quit(0)
		return
	if int(s.active) != duel.my_id() or int(s.revision) == last_revision: return
	last_revision = int(s.revision)
	if role=="host":
		var before: Dictionary = s.duplicate(true)
		assert(not duel.resolve(999,"attack",int(s.revision)))
		assert(not duel.resolve(1,"attack",int(s.revision)-1))
		assert(before==s)
		checks += 3
	var me: Dictionary = s.players[duel.my_id()]
	var action: String = "attack"
	if int(s.turn)<=2: action = "guard"
	elif not me.skill: action = "skill"
	elif int(me.hp)<45 and int(me.energy)>=2 and int(s.turn)<10: action = "repair"
	elif int(me.energy)>=3: action = "heavy"
	duel.play(action)

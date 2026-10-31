extends SceneTree
## Godot --headless --path . --script res://tests/smoke_test.gd
## Optional graphical snapshots: omit --headless, append -- --screenshots.
## All writes use a unique temporary directory, never the player's save slots.
const Rules = preload("res://game_state.gd")
const UI = preload("res://interface.gd")
const Scene = preload("res://Main.tscn")
const Systems = preload("res://campaign_systems.gd")
var failures: int = 0
var checks: int = 0
var save_dir: String
var screenshot_dir: String = "res://artifacts"
var completed_ui_suites: int = 0

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func fresh(faction: String = "帝国", mode: int = 7) -> Rules:
	var g := Rules.new()
	g.new_game(faction,mode,"TITAN146",{"resources":500,"fleets":4,"invasion":0})
	g.state.ap = 20
	for key in Rules.RESOURCES: g.res()[key] = 500
	return g

func _run() -> void:
	save_dir = OS.get_cache_dir().path_join("stargate-tests-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(save_dir)
	if "--tutorial-only" in OS.get_cmdline_user_args():
		await preload("res://tests/tutorial_cases.gd").run(self)
		print("Tutorial: %d checks, %d failures. Test saves: %s" % [checks,failures,save_dir])
		quit(1 if failures else 0)
		return
	_test_generation()
	_test_expansion_and_atomicity()
	_test_fleets()
	_test_specializations_and_cargo()
	_test_combat()
	_test_diplomacy()
	_test_gates_skills_modes()
	_test_saves()
	_test_campaigns()
	_test_rule_regressions()
	_test_campaign_systems()
	await _test_responsive_layout()
	await _test_input_regressions()
	await _test_ui()
	await _test_button_explanations()
	await _test_campaign_ui()
	await _test_music_and_fleet()
	await preload("res://tests/tutorial_cases.gd").run(self)
	expect(completed_ui_suites == 5,"all UI suites reached their final assertion without script errors")
	# Headless process frames can finish before the audio mixer releases its last decoder.
	await create_timer(0.15).timeout
	print("%s: %d checks, %d failures. Test saves: %s" % ["PASS" if failures == 0 else "FAIL",checks,failures,save_dir])
	quit(1 if failures else 0)

func _test_music_and_fleet() -> void:
	root.size = Vector2i(1080,900)
	root.content_scale_size = Vector2i.ZERO
	var ui: UI = Scene.instantiate() as UI
	ui.auto_save = false
	ui.save_directory = save_dir
	ui.music_settings_path = save_dir.path_join("audio-test.cfg")
	root.add_child(ui)
	ui.tutorial_seen = true
	await frames(12)
	expect(ui.music.enabled and is_equal_approx(ui.music.volume,0.35),"music starts at a moderate default volume")
	expect(ui.music.player.playing and ui.music.player.stream.loop,"bundled music plays and loops offline")
	expect(absf(ui.music.player.stream.get_length()-80.0)<0.1,"full original score is 80 seconds")
	var player = ui.music.player
	await click_button(ui,find_button(ui,"音乐设置"))
	expect(is_instance_valid(ui.modal),"music settings opens through actual pointer input")
	audit_descriptions(ui.modal)
	var toggle := ui.modal.find_children("*","CheckBox",true,false)[0] as CheckBox
	await click_at(toggle.get_global_rect().get_center())
	expect(not ui.music.enabled and player.stream_paused,"music toggle pauses playback")
	var slider := ui.modal.find_child("MusicVolume",true,false) as HSlider
	slider.value = 62
	expect(is_equal_approx(ui.music.volume,0.62) and player.stream_paused,"changing volume while off does not start music")
	await click_at(toggle.get_global_rect().get_center())
	expect(ui.music.enabled and not player.stream_paused,"music toggle resumes playback")
	slider.value = 0
	expect(player.stream_paused,"zero volume mutes music")
	slider.value = 28
	expect(not player.stream_paused,"raising enabled volume resumes music")
	root.size = Vector2i(390,844)
	await frames(15)
	expect(fully_inside(ui.modal_panel,ui.get_global_rect()),"music settings fits narrow screen")
	await snapshot("17-mobile-music")
	ui._close_modal()
	root.size = Vector2i(1080,900)
	await frames(15)
	ui._start_campaign()
	await frames(10)
	ui._on_target("planet","p11")
	await frames(10)
	expect(ui.music.player == player and player.playing,"resize and new campaign do not restart or duplicate music")
	var map = ui.map_view
	var fleet: Dictionary = ui.game.fleet(ui.selected_fleet)
	for factor in [0.72,1.0,2.5]:
		map.zoom = factor
		var point: Vector2 = map.fleet_point(fleet)
		expect(map.fleet_radius() >= 16,"fleet stays large at zoom " + str(factor))
		expect(map.hit_at(point+Vector2(0,map.fleet_radius()*0.9)).get("id","") == fleet.id,"enlarged fleet edge is clickable " + str(factor))
		expect(map.hit_at(map.to_screen(ui.game.position_of(fleet))).kind == "planet","larger garrison does not steal planet center clicks " + str(factor))
	map.reset_view()
	ui.scroll.scroll_vertical = 0
	await frames()
	await snapshot("18-large-fleet")
	player.seek(79.9)
	await create_timer(0.45).timeout
	expect(player.playing and player.get_playback_position()<1.5,"playback crosses the end and loops without stopping")
	var restored = UI.Music.new()
	restored.settings_path = ui.music_settings_path
	root.add_child(restored)
	expect(restored.enabled and is_equal_approx(restored.volume,0.28),"audio preferences survive a new player instance")
	expect(restored.set_enabled(false) == OK,"muted preference saves successfully")
	restored.queue_free()
	ui.queue_free()
	await frames()
	var muted = UI.Music.new()
	muted.settings_path = save_dir.path_join("audio-test.cfg")
	root.add_child(muted)
	expect(not muted.enabled and muted.player.stream_paused,"saved off state is silent on next launch")
	muted.queue_free()
	await frames()

func _test_generation() -> void:
	var a := fresh()
	var b := fresh()
	expect(a.state.planets == b.state.planets,"same seed has identical planets")
	b.new_game("帝国",7,"DIFFERENT")
	expect(a.state.planets != b.state.planets,"different seeds change the map")
	expect(a.owned().size() == 2,"empire starts with two planets")
	expect(fresh("联盟").owned().size() == 3,"alliance starts with a bonus planet")
	expect(fresh("混沌").owned().size() == 2,"chaos starts with two planets")
	expect(a.state.planets.size() == 18 and a.state.gates.size() == 34,"complete reference star map")
	expect(a.validate_snapshot(a.state) == "","new snapshot validates")
	var visited: Array[String] = ["p0"]
	var todo: Array[String] = ["p0"]
	while not todo.is_empty():
		for id in a.neighbors(todo.pop_front()):
			if id not in visited:
				visited.append(id)
				todo.append(id)
	expect(visited.size() == 18,"all planets connected")

func _test_campaign_systems() -> void:
	preload("res://tests/campaign_systems_cases.gd").run(self)

func _test_campaign_ui() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1080,900)
	var ui = Scene.instantiate()
	root.add_child(ui)
	ui.tutorial_seen = true
	ui.auto_save = false
	ui.save_directory = save_dir
	await frames()
	ui._start_campaign()
	await frames()
	ui.selected_planet="p1"
	ui.selected_fleet=str(ui.game.stationed("p11","帝国")[0].id)
	ui._schedule_build()
	await frames()
	ui._attack_dialog(ui.selected_fleet,"p1")
	await frames()
	var texts: String = ""
	for label in ui.modal.find_children("*","Label",true,false): texts += label.text
	expect("驻军和防御未识别" in texts and "缺乏实时情报" in texts,"attack UI does not reveal hidden garrison")
	audit_descriptions(ui.modal)
	ui._close_modal()
	await snapshot("12-fog-map")
	ui.game.end_turn()
	ui._schedule_build()
	await frames()
	var before: Dictionary = ui.game.state.duplicate(true)
	ui._show_replay(false)
	await frames()
	expect(is_instance_valid(ui.replay_map) and ui.replay_map.read_only,"replay has its own read-only historical map")
	audit_descriptions(ui.modal)
	await click_button(ui,find_button(ui.modal,"下一个事件"),true)
	expect(ui.replay_index==0,"replay advances one event with mouse")
	ui.replay_map.visual_time=0.5
	ui.replay_map.queue_redraw()
	await snapshot("13-turn-replay")
	expect(before==ui.game.state,"viewing replay never changes game state")
	await click_button(ui,find_button(ui.modal,"跳过回放"),true)
	expect(not is_instance_valid(ui.modal),"skip replay restores controls")
	ui._story_dialog()
	await frames()
	audit_descriptions(ui.modal)
	await snapshot("14-story-choice")
	ui.game.res().credits=0
	before=ui.game.state.duplicate(true)
	await click_button(ui,find_button(ui.modal,"接纳船队"),true)
	expect(before==ui.game.state and is_instance_valid(ui.modal),"unaffordable story preserves event and resources")
	ui.game.res().credits=30
	ui.game.res().fuel=30
	await click_button(ui,find_button(ui.modal,"接纳船队"),true)
	expect(ui.game.state.story.flags.refugees and not is_instance_valid(ui.modal),"story choice works via actual button routing")
	root.size=Vector2i(390,844)
	await frames(10)
	ui._show_replay(false)
	await frames()
	expect(fully_inside(ui.modal_panel,Rect2(Vector2.ZERO,ui.size)),"replay modal fits narrow screen")
	for label in ["上一个事件","下一个事件","自动播放","跳过回放"]:
		var button: Button = find_button(ui.modal,label)
		expect(button.get_global_rect().end.x<=ui.modal_panel.get_global_rect().end.x,"replay control fits narrow width "+label)
	await snapshot("15-mobile-replay")
	root.size=Vector2i(390,600)
	await frames(10)
	expect(fully_inside(ui.modal_panel,Rect2(Vector2.ZERO,ui.size)),"shrinking an open replay keeps modal in window")
	await click_button(ui,find_button(ui.modal,"跳过回放"),true)
	expect(not is_instance_valid(ui.modal),"replay can be skipped after height-only resize")
	ui._close_modal()
	root.size=Vector2i(1080,900)
	await frames(10)
	ui.game.new_game("帝国",8)
	ui.selected_planet=""
	ui.selected_fleet=""
	ui._schedule_build()
	await frames()
	await snapshot("16-expedition")
	audit_descriptions(ui.shell)
	ui.game.planet("p6").owner="帝国"
	ui.game.state.series.convoy_saved=true
	ui.game.check_victory()
	ui._result_dialog()
	await frames()
	audit_descriptions(ui.modal)
	await click_button(ui,find_button(ui.modal,"进入下一章"),true)
	expect(ui.game.state.series.chapter==2 and ui.game.state.phase=="player","chapter continuation button starts next playable theatre")
	ui.queue_free()
	await frames()
	completed_ui_suites += 1

func _test_rule_regressions() -> void:
	var g := fresh()
	var f: Dictionary = g.stationed("p11","帝国")[0]
	expect(g.act("move",{"fleet":f.id,"x":500,"y":420}).ok,"leave garrison for space")
	expect(g.act("move",{"fleet":f.id,"x":550,"y":430}).ok,"a free fleet can move again")
	expect(Vector2(f.x,f.y) == Vector2(550,430),"second space movement reaches destination")
	for spec in [
		["move",{"fleet":f.id,"planet":"missing"}],
		["attack",{"fleet":f.id,"planet":"p12","method":"INVALID"}],
		["policy",{"planet":"p11","policy":"INVALID"}],
		["gate",{"gate":"g25","choice":"INVALID"}],
		["diplomacy",{"faction":"联盟","choice":"INVALID"}],
		["build",{"planet":"p11","building":"INVALID"}]]:
		var before: Dictionary = g.state.duplicate(true)
		expect(not g.act(spec[0],spec[1]).ok,"invalid action choice rejected: " + spec[0])
		expect(g.state == before,"invalid action never spends resources: " + spec[0])
	g = fresh()
	var p: Dictionary = g.planet("p11")
	var defense: int = int(p.defense)
	var income: int = int(p.income)
	expect(g.act("build",{"planet":p.id,"building":"护盾阵列"}).ok,"construct shield")
	var before: Dictionary = g.state.duplicate(true)
	expect(not g.act("build",{"planet":p.id,"building":"护盾阵列"}).ok,"duplicate structure refused")
	expect(g.state == before,"duplicate building cannot stack buffs or spend resources")
	expect(g.act("build",{"planet":p.id,"building":"资源基地"}).ok,"replace shield with resource base")
	expect(int(p.defense) == defense and int(p.income) == income+2,"replacement removes old shield effect")
	expect(g.act("build",{"planet":p.id,"building":"护盾阵列"}).ok,"replace resource base with shield")
	expect(int(p.defense) == defense+2 and int(p.income) == income,"replacement removes old income effect")
	p = g.planet("p12")
	p.building = "资源基地"
	p.income = int(p.income)+2
	income = int(p.income)
	expect(g.act("attack",{"fleet":g.stationed("p11")[0].id,"planet":p.id,"method":"轨道轰炸"}).ok,"bombard resource building")
	expect(int(p.income) == income-2,"destroyed resource base no longer produces income")

func _test_expansion_and_atomicity() -> void:
	var g := fresh()
	var before: Dictionary = g.state.duplicate(true)
	expect(not g.act("expand",{"planet":"p7"}).ok,"cannot expand enemy planet")
	expect(g.state == before,"failed expansion does not mutate")
	expect(not g.act("expand",{"planet":"p0"}).ok,"cannot expand disconnected neutral")
	expect(g.act("expand",{"planet":"p14"}).ok,"expand adjacent neutral")
	expect(g.planet("p14").owner == "帝国" and g.ships("p14") == 1,"expansion changes ownership and garrison")
	var ap: int = int(g.state.ap)
	expect(g.act("reinforce",{"planet":"p11"}).ok,"reinforce friendly planet")
	expect(g.ships("p11") == 5 and int(g.state.ap) == ap-1,"reinforce grants ships and costs action")
	g.state.ap = 0
	before = g.state.duplicate(true)
	expect(not g.act("reinforce",{"planet":"p11"}).ok,"no action refuses reinforcement")
	expect(g.state == before,"insufficient action atomic")
	g.state.ap = 10
	g.res().credits = 0
	before = g.state.duplicate(true)
	expect(not g.act("buy",{"planet":"p11","type":"突击"}).ok,"insufficient money refuses buy")
	expect(g.state == before,"failed purchase atomic")

func _test_fleets() -> void:
	var g := fresh()
	for kind in Rules.TYPES: expect(g.act("buy",{"planet":"p11","type":kind}).ok,"buy " + kind)
	var a: Dictionary = g.stationed("p11","帝国")[0]
	var units: int = int(a.units)
	expect(g.act("split",{"fleet":a.id,"units":2}).ok,"split fleet")
	var b: Dictionary = g.state.fleets.back()
	expect(int(a.units)+int(b.units) == units,"split conserves units")
	var old: Dictionary = g.state.duplicate(true)
	expect(not g.act("split",{"fleet":a.id,"units":int(a.units)}).ok,"split cannot empty fleet")
	expect(old == g.state,"invalid split atomic")
	expect(g.act("support",{"fleet":a.id,"target":b.id}).ok,"temporary support")
	expect(int(b.support)>0 and int(b.support_until) == 2,"support has expiry")
	old = g.state.duplicate(true)
	expect(not g.act("support",{"fleet":a.id,"target":b.id}).ok,"no repeated support")
	expect(old == g.state,"repeated support not charged")
	expect(g.act("upgrade",{"fleet":a.id}).ok,"upgrade fleet")
	expect(g.act("configure",{"fleet":a.id,"name":"测试编队","type":"突击","modules":["主武器","帝国矩阵"],"color":"58d0dc","icon":"菱形"}).ok,"configure legal modules")
	expect(a.name == "测试编队" and a.type == "突击","configuration persisted")
	old = g.state.duplicate(true)
	expect(not g.act("configure",{"fleet":a.id,"modules":["联盟信标"]}).ok,"foreign module rejected")
	expect(g.state == old,"invalid configuration atomic")
	expect(g.act("exchange",{"fleet":a.id,"target":b.id}).ok,"exchange modules")
	expect(b.modules.size() == 2,"module exchange real")
	var total: int = int(a.units)+int(b.units)
	expect(g.act("merge",{"fleet":a.id,"target":b.id}).ok,"merge fleets")
	expect(int(a.units) == total and g.fleet(str(b.id)).is_empty(),"merge conserves units and removes child")
	g.planet("p14").owner = "帝国"
	var quote: Dictionary = g.movement_quote(a,g.planet("p14"))
	expect(quote.valid and quote.gate and quote.fuel == 1,"connected gate is cheap")
	expect(g.act("move",{"fleet":a.id,"planet":"p14"}).ok,"move through gate")
	expect(a.station == "p14" and a.state == "驻守","move updates station")
	expect(g.act("move",{"fleet":a.id,"x":500,"y":420}).ok,"move into free space")
	expect(a.station == "" and a.state == "太空","free fleet independent of planets")
	expect(g.act("explore",{"fleet":a.id}).ok,"explore central resource region")

func _test_combat() -> void:
	var g := fresh()
	var a: Dictionary = g.stationed("p11","帝国")[0]
	a.units = 30
	a.type = "突击"
	expect(g.act("attack",{"fleet":a.id,"planet":"p12","method":"围困"}).ok,"siege")
	expect(int(g.planet("p12").siege) == 3,"siege lasts two rounds")
	expect(g.act("attack",{"fleet":a.id,"planet":"p12","method":"轨道轰炸"}).ok,"bombardment")
	expect(int(g.planet("p12").affinity) == 0,"bombardment harms affinity")
	expect(g.act("attack",{"fleet":a.id,"planet":"p12","method":"直接突袭"}).ok,"direct assault")
	expect(g.planet("p12").owner == "帝国" and a.station == "p12","victory changes planet and station")
	expect(g.act("policy",{"planet":"p12","policy":"重建星球"}).ok,"rebuild after capture")
	expect(int(g.planet("p12").affinity) == 35,"policy improves affinity")
	var b: Dictionary = g.spawn_fleet("联盟","",1,"运输","敌运输船")
	b.x = a.x
	b.y = a.y
	expect(g.act("encounter",{"fleet":a.id,"target":b.id,"choice":"观察和侦察"}).ok,"scout enemy")
	expect(int(b.revealed)>0,"scouting reveals")
	expect(g.act("encounter",{"fleet":a.id,"target":b.id,"choice":"立即开战"}).ok,"fleet combat")
	expect(g.fleet(str(b.id)).is_empty(),"destroyed enemy removed")
	var weak := fresh()
	var f: Dictionary = weak.stationed("p11","帝国")[0]
	f.units = 1
	weak.stationed("p7")[0].units = 50
	weak.act("attack",{"fleet":f.id,"planet":"p7","method":"直接突袭"})
	expect(weak.fleet(str(f.id)).is_empty(),"losing fleet can be destroyed")
	var remote := fresh()
	f = remote.stationed("p11","帝国")[0]
	expect(not remote.act("attack",{"fleet":f.id,"planet":"p4"}).ok,"unqualified long range attack rejected")
	f.type = "突击"
	f.units = 50
	expect(remote.act("attack",{"fleet":f.id,"planet":"p4"}).ok,"qualified long range attack allowed")

func _test_specializations_and_cargo() -> void:
	for direction in Rules.UPGRADES:
		var g := fresh()
		var f: Dictionary = g.stationed("p11","帝国")[0]
		expect(g.act("upgrade",{"fleet":f.id,"direction":direction}).ok,"upgrade specialization " + direction)
		expect(int(f.upgrades.get(direction,0)) == 1,"specialization saved " + direction)
	var g := fresh()
	var f: Dictionary = g.spawn_fleet("帝国","p11",2,"运输","测试运输")
	var materials: int = int(g.res().materials)
	expect(g.act("cargo",{"fleet":f.id,"resource":"materials","amount":5}).ok,"load transport supplies")
	expect(int(g.res().materials) == materials-5 and int(f.cargo.materials) == 5,"loaded supplies leave treasury")
	var before: Dictionary = g.state.duplicate(true)
	expect(not g.act("cargo",{"fleet":f.id,"resource":"materials","amount":5}).ok,"capacity enforced")
	expect(before == g.state,"cargo over-capacity no side effects")
	expect(g.act("cargo",{"fleet":f.id,"resource":"materials","amount":3,"unload":true}).ok,"unload supplies")
	expect(int(g.res().materials) == materials-2 and int(f.cargo.materials) == 2,"unload conserves supplies")
	f.damage = 2
	f.modules = ["维修"]
	var units: int = int(f.units)
	g.end_turn()
	expect(int(f.units) == units+1 and int(f.damage) == 1,"repair restores damaged ships")

func _test_diplomacy() -> void:
	var g := fresh()
	expect(g.act("diplomacy",{"faction":"联盟","choice":"结盟"}).ok,"alliance agreement")
	expect(g.friendly("帝国","联盟"),"alliance changes friendship")
	var f: Dictionary = g.stationed("p11","帝国")[0]
	var before: Dictionary = g.state.duplicate(true)
	expect(not g.act("attack",{"fleet":f.id,"planet":"p12"}).ok,"cannot attack allied planet")
	expect(g.state == before,"allied attack no cost")
	expect(not g.act("diplomacy",{"faction":"混沌","choice":"结盟"}).ok,"one diplomatic action per round")
	g.state.turn = 2
	expect(g.act("diplomacy",{"faction":"联盟","choice":"宣布背叛"}).ok,"betrayal")
	expect(not g.friendly("帝国","联盟") and int(g.state.relations["联盟"]) < 0,"betrayal changes relationship")
	for choice in ["赠送资源","资源交易","交换情报","提出停战","开放星门","保护协议","共同抗敌"]:
		g.state.turn = int(g.state.turn)+1
		g.state.relations["混沌"] = 30
		expect(g.act("diplomacy",{"faction":"混沌","choice":choice}).ok,"diplomacy " + choice)

func _test_gates_skills_modes() -> void:
	var g := fresh()
	var gate: Dictionary = g.adjacency("p11","p14")
	var f: Dictionary = g.stationed("p11","帝国")[0]
	expect(g.act("gate",{"gate":gate.id,"choice":"破坏"}).ok,"destroy gate")
	expect(not g.movement_quote(f,g.planet("p14")).valid,"destroyed gate blocks travel")
	expect(g.act("gate",{"gate":gate.id,"choice":"修复"}).ok,"repair gate")
	expect(g.movement_quote(f,g.planet("p14")).valid,"repair restores travel")
	expect(g.act("skill",{"planet":"p11"}).ok,"empire lock skill")
	expect(not g.act("skill",{"planet":"p11"}).ok,"skill once per turn")
	expect(not g.act("ultimate").ok,"ultimate locked before round 4")
	g.state.turn = 4
	expect(g.act("ultimate").ok,"ultimate unlocked")
	expect(not g.act("ultimate").ok,"ultimate once per campaign")
	for mode in range(8):
		var m := fresh("帝国",mode)
		expect(m.validate_snapshot(m.state) == "","mode %d valid initial state" % mode)
		expect(m.end_turn().ok,"mode %d turn simulation" % mode)
		if mode == 7: expect(m.state.phase == "player","sandbox does not finish")
	var escort := fresh("帝国",3)
	escort.fleet(str(escort.state.escort)).station = escort.state.escort_goal
	escort.check_victory()
	expect(escort.state.winner == "帝国","escort goal victory")
	var survive := fresh("帝国",4)
	survive.state.turn = 10
	survive.check_victory()
	expect(survive.state.winner == "帝国","survival objective")
	var dip := fresh("帝国",5)
	dip.res().reputation = 200
	dip.check_victory()
	expect(dip.state.winner == "帝国","peaceful victory")
	var gates := fresh("帝国",2)
	for i in range(5): gates.state.gates[i].owner = "帝国"
	gates.check_victory()
	expect(gates.state.winner == "帝国","five gate victory")
	var invasion := fresh("帝国",1)
	invasion.state.cores_destroyed = 3
	invasion.check_victory()
	expect(invasion.state.winner == "帝国","invasion victory")

func _test_saves() -> void:
	var g := fresh()
	g.act("expand",{"planet":"p14"})
	g.act("diplomacy",{"faction":"联盟","choice":"结盟"})
	var f: Dictionary = g.stationed("p11","帝国")[0]
	g.act("move",{"fleet":f.id,"x":500,"y":420})
	g.end_turn()
	for slot in ["1","2","3","auto"]:
		expect(g.save_game(slot,save_dir) == "","save slot " + slot)
		var loaded := Rules.new()
		expect(loaded.load_game(slot,save_dir) == "","load slot " + slot)
		for key in ["planets","fleets","gates","resources","relations","pacts","log","events"]:
			expect(loaded.state[key] == JSON.parse_string(JSON.stringify(g.state[key])),"roundtrip " + key)
		var duplicate := Rules.new()
		duplicate.load_game(slot,save_dir)
		loaded.end_turn()
		duplicate.end_turn()
		expect(loaded.state.log == duplicate.state.log,"RNG future deterministic after load")
	var old: Dictionary = g.state.duplicate(true)
	var file := FileAccess.open(save_dir.path_join("campaign_slot_3.json"),FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	expect(g.load_game("3",save_dir) != "","reject corrupt save")
	expect(g.state == old,"bad save does not damage current campaign")
	expect(g.load_game("../bad",save_dir) != "","slot path traversal rejected")
	# Valid JSON can still contain fields that would crash a UI callback.
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data.version = [],
		func(data: Dictionary) -> void: data.turn = {},
		func(data: Dictionary) -> void: data.erase("winner"),
		func(data: Dictionary) -> void: data.rng_state = "broken",
		func(data: Dictionary) -> void: data.resources["帝国"].credits = [],
		func(data: Dictionary) -> void: data.planets[0].x = "broken",
		func(data: Dictionary) -> void: data.fleets[0].units = {},
		func(data: Dictionary) -> void: data.fleets[0].cargo = "broken",
		func(data: Dictionary) -> void: data.fleets[0].modules = ["INVALID"],
		func(data: Dictionary) -> void: data.gates = [],
		func(data: Dictionary) -> void: data.pacts["联盟"].access = [],
		func(data: Dictionary) -> void: data.settings.invasion = []]
	for index in range(mutations.size()):
		var damaged: Dictionary = old.duplicate(true)
		damaged.rng_state = str(g.rng.state)
		mutations[index].call(damaged)
		var broken := FileAccess.open(save_dir.path_join("campaign_slot_3.json"),FileAccess.WRITE)
		broken.store_string(JSON.stringify(damaged))
		broken.close()
		expect(g.load_game("3",save_dir) != "","malformed typed save rejected " + str(index))
		expect(g.state == old,"malformed typed save leaves campaign intact " + str(index))

func _test_campaigns() -> void:
	for mode in range(9):
		for faction in ["帝国","联盟","混沌"]:
			var g := Rules.new()
			g.new_game(faction,mode,"SIM%d" % mode,{"invasion":30,"fleets":5,"resources":100})
			for round_index in range(14):
				if g.state.phase == "finished": break
				var result: Dictionary = g.end_turn()
				expect(result.ok,"AI simulation mode %d faction %s round %d" % [mode,faction,round_index])
				expect(g.validate_snapshot(g.state) == "","simulation maintains valid state: " + g.validate_snapshot(g.state))

func find_button(node: Node, text_value: String) -> Button:
	if node is Button and node.text == text_value: return node as Button
	for child in node.get_children():
		var found: Button = find_button(child,text_value)
		if found != null: return found
	return null

func command_button(node: Node, command: String) -> Button:
	if node is Button and node.get_meta("command","") == command: return node as Button
	for child in node.get_children():
		var result: Button = command_button(child,command)
		if result != null: return result
	return null

func find_label(node: Node, value: String) -> Label:
	if node is Label and node.text == value: return node as Label
	for child in node.get_children():
		var found: Label = find_label(child,value)
		if found != null: return found
	return null

func click_at(pos: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = pos
	root.push_input(move,true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pos
	press.pressed = true
	root.push_input(press,true)
	await frames(2)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = pos
	release.pressed = false
	root.push_input(release,true)
	await frames(3)

func click_button(_ui: UI, button: Button, _in_modal: bool = false) -> void:
	if button == null:
		expect(false,"required button exists for pointer click")
		return
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await frames(3)
	await click_at(button.get_global_rect().get_center())

func window_click(button: Button) -> void:
	var location: Vector2 = root.get_final_transform()*button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = location
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.position = location
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	var release := InputEventMouseButton.new()
	release.position = location
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await frames(4)

func audit_button_hits(scope: Node) -> void:
	for node in scope.find_children("*","Button",true,false):
		var button := node as Button
		if button.disabled or not button.is_visible_in_tree(): continue
		var ancestor: Node = button.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
			ancestor = ancestor.get_parent()
		await frames(3)
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_final_transform()*button.get_global_rect().get_center()
		root.push_input(motion,false)
		var hovered: Control = root.gui_get_hovered_control()
		expect(hovered == button or (hovered != null and button.is_ancestor_of(hovered)),"no overlay intercepts button: " + button.text)

func tap_button(button: Button) -> void:
	var location: Vector2 = root.get_final_transform()*button.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.position = location
	press.index = 0
	press.pressed = true
	Input.parse_input_event(press)
	await frames(3)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = location
	Input.parse_input_event(release)
	await frames(4)

func _test_input_regressions() -> void:
	root.content_scale_size = Vector2i(540,900)
	for resolution in [Vector2i(1080,900),Vector2i(2860,1707),Vector2i(1280,720),Vector2i(540,900),Vector2i(390,844)]:
		root.size = resolution
		var ui: UI = Scene.instantiate() as UI
		ui.auto_save = false
		ui.save_directory = save_dir
		root.add_child(ui)
		ui.tutorial_seen = true
		await frames(15)
		var tag: String = str(resolution)
		for index in [1,2,0]:
			var card: Button = faction_buttons(ui)[index]
			ui.scroll.ensure_control_visible(card)
			await frames()
			await window_click(card)
			expect(ui.faction_index == index,"window-coordinate click selects faction " + str(index) + tag)
		ui.scroll.scroll_vertical = 0
		await frames()
		var mode: OptionButton = ui.find_children("*","OptionButton",true,false)[0] as OptionButton
		ui.scroll.ensure_control_visible(mode)
		await frames()
		await window_click(mode)
		if not is_instance_valid(mode): mode = ui.find_children("*","OptionButton",true,false)[0] as OptionButton
		if not mode.get_popup().visible:
			mode.grab_focus()
			var open_key := InputEventKey.new()
			open_key.keycode = KEY_SPACE
			open_key.pressed = true
			root.push_input(open_key,true)
			open_key.pressed = false
			root.push_input(open_key,true)
			await frames()
		expect(mode.get_popup().visible,"mode dropdown opens " + tag)
		var popup: PopupMenu = mode.get_popup()
		# Check the selection signal binding separately from pointer opening.
		# Native menu-item keyboard/mouse dispatch needs a manual platform test.
		popup.index_pressed.emit(1)
		popup.hide()
		await frames()
		expect(ui.mode_index == 1,"mode selection signal updates setup " + tag)
		ui.mode_index = 0
		ui._schedule_build()
		await frames()
		ui.scroll.scroll_vertical = 0
		await frames()
		var seed_before: String = ui.seed_code
		await window_click(find_button(ui,"换一组"))
		expect(ui.seed_code != seed_before,"shuffle works with real scaling " + tag)
		await window_click(find_button(ui,"新手教学"))
		expect(ui.tutorial_active and ui.screen_state == "game","practice opens using scaled pointer " + tag)
		await tap_button(find_button(ui,"跳过教学"))
		expect(is_instance_valid(ui.modal),"touch opens skip confirmation " + tag)
		ui._close_modal()
		ui.tutorial_active = false
		ui.screen_state = "start"
		ui._schedule_build()
		await frames()
		await window_click(find_button(ui,"读取本地战役"))
		expect(is_instance_valid(ui.modal),"load menu accepts pointer " + tag)
		await window_click(find_button(ui.modal,"关闭"))
		await window_click(find_button(ui,"开启星门"))
		expect(ui.screen_state == "game","start accepts scaled pointer " + tag)
		await frames(10)
		if ui.screen_state != "game":
			ui.queue_free()
			await frames()
			continue
		if resolution.x in [1080,390]: await audit_button_hits(ui.shell)
		for command_name in ["reinforce","dispatch","attack"]:
			await click_button(ui,command_button(ui,command_name))
			expect(ui.command == command_name,"command card accepts click " + command_name + tag)
		await click_button(ui,command_button(ui,"expand"))
		expect(ui.command == "expand","command is selected " + tag)
		expect(fully_inside(ui.map_view,ui.scroll.get_global_rect()),"command selection reveals map " + tag)
		ui.command = "attack"
		ui._on_target("planet","p11")
		await frames()
		expect(ui.selected_fleet != "" and not is_instance_valid(ui.modal),"attack first selects own garrison " + tag)
		ui._configure_dialog()
		await frames()
		var edit: LineEdit = ui.modal.find_children("*","LineEdit",true,false)[0] as LineEdit
		edit.text = "窗口缩放保留配置"
		var previous_modal: Control = ui.modal
		root.size = resolution+Vector2i(0,70)
		await frames(15)
		expect(is_instance_valid(previous_modal) and ui.modal == previous_modal,"resizing preserves the open dialog " + tag)
		if is_instance_valid(edit): expect(edit.text == "窗口缩放保留配置","resizing preserves unsubmitted edit " + tag)
		await click_button(ui,find_button(ui.modal,"保存配置"),true)
		expect(ui.game.fleet(ui.selected_fleet).name == "窗口缩放保留配置","configuration submit remains clickable after resize " + tag)
		ui._split_dialog(ui.selected_fleet)
		await frames()
		var slider: HSlider = ui.modal.find_children("*","HSlider",true,false)[0] as HSlider
		await click_at(slider.get_global_rect().get_center())
		expect(int(slider.value) == 2,"split slider accepts pointer " + tag)
		await click_button(ui,find_button(ui.modal,"确认拆分"),true)
		expect(ui.game.state.fleets.back().units == 2,"split confirmation uses slider value " + tag)
		ui.game.state.ap = 20
		for key in Rules.RESOURCES: ui.game.res()[key] = 500
		await click_button(ui,find_button(ui,"保存当前进度"))
		if is_instance_valid(ui.modal): await click_button(ui,find_button(ui.modal,"确认执行"),true)
		expect(FileAccess.file_exists(ui._save_path("1")),"save UI writes isolated test slot " + tag)
		var saved: Dictionary = ui.game.state.duplicate(true)
		ui.game.res().credits = 1
		await click_button(ui,find_button(ui,"读取存档"))
		await click_button(ui,find_button(ui.modal,"确认执行"),true)
		expect(ui.game.state.planets == JSON.parse_string(JSON.stringify(saved.planets)) and ui.game.res().credits == 500,"save/load buttons restore campaign " + tag)
		var map = ui.map_view
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = map.to_screen(Vector2(500,410))
		touch.pressed = true
		map._gui_input(touch)
		touch.pressed = false
		touch.canceled = true
		map._gui_input(touch)
		expect(not map.down and map.touches.is_empty() and not is_instance_valid(ui.modal),"canceled touch never clicks or sticks " + tag)
		map._begin(Vector2(100,100))
		root.focus_exited.emit()
		expect(not map.down and map.drag_id == "","focus loss cancels dragging " + tag)
		await click_button(ui,find_button(ui,"结束本轮"))
		var turn_before: int = int(ui.game.state.turn)
		await click_button(ui,find_button(ui.modal,"取消"),true)
		expect(ui.game.state.turn == turn_before,"cancel never ends the turn " + tag)
		await click_button(ui,find_button(ui,"结束本轮"))
		await click_button(ui,find_button(ui.modal,"确认执行"),true)
		expect(ui.game.state.turn == turn_before+1,"end turn button performs one turn " + tag)
		await click_button(ui,find_button(ui.modal,"跳过回放"),true)
		await frames()
		if is_instance_valid(ui.modal): await click_button(ui,find_button(ui.modal,"关闭"),true)
		await click_button(ui,find_button(ui,"重开"))
		await click_button(ui,find_button(ui.modal,"确认执行"),true)
		expect(ui.screen_state == "start","restart returns to interactive start " + tag)
		ui.queue_free()
		await frames()
	completed_ui_suites += 1

func frames(count: int = 5) -> void:
	for i in range(count): await process_frame

func audit_descriptions(scope: Node) -> void:
	if scope is Window: return # Native picker/popup internals are provided by Godot.
	if scope is BaseButton:
		expect(scope.has_meta("help_detail") and str(scope.get_meta("help_detail","")).length() >= 10,"button has a specific explanation: " + str(scope.get("text")))
		expect(scope.tooltip_text.length() > str(scope.get("text")).length(),"tooltip explains instead of repeating label: " + str(scope.get("text")))
		if scope.has_node("ActionCaption"):
			expect(scope.get_node("ActionCaption").mouse_filter == Control.MOUSE_FILTER_IGNORE,"caption cannot block pointer input")
	for child in scope.get_children(): audit_descriptions(child)

func _test_button_explanations() -> void:
	root.size = Vector2i(1080,900)
	root.content_scale_size = Vector2i(540,900)
	var ui: UI = Scene.instantiate() as UI
	ui.auto_save = false
	ui.save_directory = save_dir.path_join("help-tests")
	DirAccess.make_dir_recursive_absolute(ui.save_directory)
	root.add_child(ui)
	ui.tutorial_seen = true
	await frames(15)
	audit_descriptions(ui.shell)
	await click_button(ui,find_button(ui,"？ 说明模式"))
	expect(ui.help_mode,"enable help using its visible button")
	await click_button(ui,find_button(ui,"开启星门"))
	expect(is_instance_valid(ui.help_overlay) and ui.screen_state == "start" and ui.game.state.is_empty(),"help click on start does not start campaign")
	await snapshot("09-button-help")
	await click_button(ui,find_button(ui.help_overlay,"收起说明"),true)
	expect(ui.help_mode and not is_instance_valid(ui.help_overlay),"closing explanation keeps inspection mode")
	await tap_button(find_button(ui,"返回操作"))
	expect(not ui.help_mode,"touch can exit explanation mode")
	var start_button: Button = find_button(ui,"开启星门")
	start_button.grab_focus()
	var help_key := InputEventKey.new()
	help_key.keycode = KEY_F1
	help_key.pressed = true
	root.push_input(help_key,true)
	await frames()
	expect(is_instance_valid(ui.help_overlay) and ui.screen_state == "start","F1 explains keyboard-focused control without starting game")
	ui._close_help()
	await click_button(ui,find_button(ui,"开启星门"))
	await frames(10)
	ui.game.state.ap = 20
	for key in Rules.RESOURCES: ui.game.res()[key] = 500
	ui._on_target("planet","p11")
	await frames()
	audit_descriptions(ui.shell)
	for method in ["_configure_dialog","_upgrade_dialog","_diplomacy_dialog","_load_dialog","_end_turn_dialog","_restart_dialog","_original_brief"]:
		ui.call(method)
		await frames()
		audit_descriptions(ui.modal)
		ui._close_modal()
	for method_and_arg in [["_split_dialog",ui.selected_fleet],["_fleet_dialog",ui.selected_fleet],["_policy_dialog","p11"],["_gate_dialog","g25"]]:
		ui.call(method_and_arg[0],method_and_arg[1])
		await frames()
		audit_descriptions(ui.modal)
		ui._close_modal()
	ui._attack_dialog(ui.selected_fleet,"p12")
	await frames()
	audit_descriptions(ui.modal)
	ui._close_modal()
	ui._configure_dialog()
	await frames()
	var edit: LineEdit = ui.modal.find_children("*","LineEdit",true,false)[0] as LineEdit
	edit.text = "说明不清空编辑"
	var underlying_modal: Control = ui.modal
	await click_button(ui,find_button(ui.modal,"？ 说明模式"),true)
	var before: Dictionary = ui.game.state.duplicate(true)
	await click_button(ui,find_button(ui.modal,"保存配置"),true)
	expect(is_instance_valid(ui.help_overlay) and ui.game.state == before,"explanation cannot submit a configuration")
	expect(ui.modal == underlying_modal and edit.text == "说明不清空编辑","explanation preserves underlying modal and draft")
	root.size = Vector2i(390,844)
	await frames(15)
	expect(fully_inside(ui.help_overlay.get_node("ExplanationPanel"),ui.get_global_rect()),"explanation fits narrow window")
	await snapshot("10-mobile-help")
	await click_button(ui,find_button(ui.help_overlay,"收起说明"),true)
	ui._close_modal()
	# Touch inspection of a destructive action must leave the file unchanged.
	ui.game.save_game("1",ui.save_directory)
	var save_before: String = FileAccess.get_file_as_string(ui._save_path("1"))
	var deletion: Button = find_button(ui,"删除槽位")
	ui.scroll.ensure_control_visible(deletion)
	await frames()
	await tap_button(deletion)
	expect(is_instance_valid(ui.help_overlay) and ui.game.state == before,"touch inspection never executes deletion or game action")
	expect(FileAccess.get_file_as_string(ui._save_path("1")) == save_before,"help leaves saved file intact")
	ui._close_help()
	# Disabled controls still have accessible requirements.
	var ultimate: Button
	for node in ui.find_children("*","Button",true,false):
		if node.text.begins_with("银河重整"): ultimate = node as Button
	await click_button(ui,ultimate)
	expect(is_instance_valid(ui.help_overlay),"disabled skill still exposes its explanation")
	ui._close_help()
	# A touch swipe from a button scrolls the page without opening help or acting.
	ui.scroll.ensure_control_visible(deletion)
	await frames()
	var old_scroll: int = ui.scroll.scroll_vertical
	var finger := InputEventScreenTouch.new()
	finger.index = 0
	finger.pressed = true
	finger.position = deletion.get_global_rect().get_center()
	root.push_input(finger,true)
	var swipe := InputEventScreenDrag.new()
	swipe.index = 0
	swipe.position = finger.position-Vector2(0,70)
	swipe.relative = Vector2(0,-70)
	root.push_input(swipe,true)
	finger.pressed = false
	finger.position = swipe.position
	root.push_input(finger,true)
	await frames()
	expect(ui.scroll.scroll_vertical > old_scroll and not is_instance_valid(ui.help_overlay),"help mode supports touch scrolling without activation")
	expect(FileAccess.get_file_as_string(ui._save_path("1")) == save_before,"touch swipe never deletes saved game")
	await tap_button(find_button(ui,"返回操作"))
	expect(not ui.help_mode,"mobile exits help mode after inspection")
	ui._configure_dialog()
	await frames()
	await snapshot("11-new-config")
	ui._close_modal()
	ui.queue_free()
	await frames()
	completed_ui_suites += 1

func snapshot(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	await frames(8)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	root.get_texture().get_image().save_png(screenshot_dir.path_join(name + ".png"))

func fully_inside(control: Control, bounds: Rect2) -> bool:
	var rect: Rect2 = control.get_global_rect()
	return bounds.grow(2).encloses(rect)

func faction_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button and node.has_meta("faction_index"): result.append(node as Button)
	for child in node.get_children(): result.append_array(faction_buttons(child))
	return result

func _test_responsive_layout() -> void:
	# Keep the real project's stretch settings. Matching scale_size to each test
	# window would hide bugs in editor embedding and Retina-sized windows.
	root.content_scale_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var ui: UI = Scene.instantiate() as UI
	ui.auto_save = false
	root.add_child(ui)
	ui.tutorial_seen = true
	for window_size in [Vector2i(1080,900),Vector2i(1280,720),Vector2i(2860,1707),Vector2i(1080,600),Vector2i(540,900),Vector2i(390,844)]:
		root.size = window_size
		await frames(20)
		ui.scroll.scroll_vertical = 0
		await frames()
		var visible: Rect2 = ui.get_global_rect()
		var tag: String = "%dx%d" % [window_size.x,window_size.y]
		expect(ui.page.size.x <= ui.size.x+2,"real stretch has no horizontal overflow " + tag)
		for title in ["开启星门","新手教学","读取本地战役"]:
			expect(fully_inside(find_button(ui,title),visible),"primary action visible without scrolling " + title + " " + tag)
		var cards: Array[Button] = faction_buttons(ui)
		expect(cards.size() == 3,"all faction cards retained " + tag)
		if ui.size.x >= 900:
			expect(ui.page.size.y <= ui.scroll.size.y+2,"desktop start fits first viewport " + tag)
			for card in cards: expect(fully_inside(card,ui.scroll.get_global_rect()),"desktop faction fully visible " + tag)
		else:
			ui.scroll.ensure_control_visible(cards.back())
			await frames()
			expect(fully_inside(cards.back(),ui.scroll.get_global_rect()),"mobile final faction reachable " + tag)
			ui.scroll.scroll_vertical = 0
		await snapshot("layout-start-" + tag)
	# A height-only resize must rebuild too, without losing setup selections.
	root.size = Vector2i(1080,900)
	root.content_scale_size = Vector2i(1080,900)
	await frames(15)
	ui.faction_index = 2
	ui.mode_index = 7
	ui.seed_code = "RESIZE-CHECK"
	ui._schedule_build()
	await frames()
	var previous_shell = ui.shell
	root.size = Vector2i(1080,600)
	root.content_scale_size = Vector2i(1080,600)
	await frames(15)
	expect(not is_instance_valid(previous_shell),"height-only resize rebuilds layout")
	expect(ui.faction_index == 2 and ui.mode_index == 7 and ui.seed_code == "RESIZE-CHECK","resize preserves start selections")
	expect(fully_inside(find_button(ui,"开启星门"),ui.get_global_rect()),"sandbox settings never push start off-screen")
	await snapshot("layout-short-sandbox")
	# Exercise actual faction pointer routing and the persistent footer.
	root.size = Vector2i(1080,900)
	root.content_scale_size = Vector2i(540,900)
	ui.mode_index = 0
	ui._schedule_build()
	await frames(15)
	await click_button(ui,faction_buttons(ui)[1])
	expect(ui.faction_index == 1,"compact faction card accepts pointer input")
	await click_button(ui,find_button(ui,"开启星门"))
	await frames(10)
	var state_before: Dictionary = ui.game.state.duplicate(true)
	for window_size in [Vector2i(1080,900),Vector2i(2860,1707),Vector2i(1280,720),Vector2i(540,900)]:
		root.size = window_size
		await frames(20)
		ui.scroll.scroll_vertical = 0
		await frames()
		var tag: String = "%dx%d" % [window_size.x,window_size.y]
		expect(fully_inside(ui.map_view,ui.get_global_rect()),"entire map control fits initial viewport " + tag)
		var map_bounds := Rect2(Vector2.ZERO,ui.map_view.size)
		for planet in ui.game.state.planets:
			var point: Vector2 = ui.map_view.to_screen(ui.game.position_of(planet))
			expect(map_bounds.has_point(point-Vector2(32,32)) and map_bounds.has_point(point+Vector2(32,65)),"planet and labels remain within map " + tag + " " + str(planet.id))
		expect(ui.game.state == state_before,"resize preserves campaign " + tag)
		await snapshot("layout-map-" + tag)
	ui.queue_free()
	await frames()
	completed_ui_suites += 1

func _test_ui() -> void:
	root.size = Vector2i(1080,900)
	root.content_scale_size = Vector2i(1080,900)
	var ui: UI = Scene.instantiate() as UI
	ui.auto_save = false
	root.add_child(ui)
	ui.tutorial_seen = true
	await frames()
	expect(ui.screen_state == "start","scene opens start page")
	expect(find_button(ui,"开启星门") != null,"start button exists")
	var shuffle: Button = find_button(ui,"换一组")
	expect(shuffle.size.x >= 75,"compact shuffle button retains readable text width")
	await snapshot("01-start")
	ui.scroll.scroll_vertical = 600
	await snapshot("02-factions")
	ui._show_guide(0)
	await frames()
	expect(ui.guide_step == 0 and is_instance_valid(ui.modal),"tutorial opens")
	expect(find_button(ui.modal,"关闭").size.x >= 60,"modal close label remains visible")
	for step in range(13):
		find_button(ui.modal,"下一步").pressed.emit()
		await frames(1)
	expect(ui.guide_step == 13,"all fourteen tutorial steps")
	ui._close_modal()
	await click_button(ui,find_button(ui,"开启星门"))
	await frames(10)
	expect(ui.screen_state == "game" and is_instance_valid(ui.map_view),"enter playable map")
	await snapshot("03-map")
	ui.scroll.scroll_vertical = int(find_label(ui,"战术指令").global_position.y+ui.scroll.scroll_vertical-20)
	await snapshot("04-commands")
	ui.scroll.scroll_vertical = int(find_label(ui,"舰队工坊").global_position.y+ui.scroll.scroll_vertical-20)
	await snapshot("05-workshop")
	ui._on_target("planet","p11")
	await frames()
	expect(ui.selected_fleet != "","selecting own planet selects garrison")
	var map = ui.map_view
	var pos: Vector2 = map.to_screen(Vector2(100,200))
	expect(map.to_world(pos).distance_to(Vector2(100,200)) < 0.01,"map coordinate roundtrip")
	var offset: Vector2 = map.pan
	map._begin(map.to_screen(Vector2(500,425)))
	map._motion(map.pointer+Vector2(25,20))
	map._release(map.pointer)
	expect(map.pan != offset,"empty space drag pans map")
	map.reset_view()
	var old_zoom: float = map.zoom
	map.zoom_by(1.1)
	expect(map.zoom > old_zoom,"map zoom")
	map.reset_view()
	var f: Dictionary = ui.game.fleet(ui.selected_fleet)
	map._begin(map.fleet_point(f))
	map._motion(map.to_screen(Vector2(500,420)))
	map._release(map.pointer)
	await frames()
	expect(is_instance_valid(ui.modal),"fleet drag opens confirmation instead of moving immediately")
	expect(f.station == "p11","drag does not mutate before confirmation")
	ui._close_modal()
	# Route real pointer events through Godot's GUI, including child card controls.
	await click_button(ui,command_button(ui,"expand"))
	expect(ui.command == "expand","pointer click reaches the action card through its labels")
	var planet_pos: Vector2 = ui.map_view.global_position + ui.map_view.to_screen(ui.game.position_of(ui.game.planet("p14")))
	ui.scroll.scroll_vertical += int(planet_pos.y-450)
	await frames()
	planet_pos = ui.map_view.global_position + ui.map_view.to_screen(ui.game.position_of(ui.game.planet("p14")))
	await click_at(planet_pos)
	expect(is_instance_valid(ui.modal),"pointer planet click opens confirmation")
	await click_button(ui,find_button(ui.modal,"确认执行"),true)
	expect(ui.game.planet("p14").owner == "帝国","pointer confirmation actually expands territory")
	ui._close_modal()
	# Touch events: pinch must zoom without selecting or dropping a fleet.
	map = ui.map_view
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(220,210)
	map._gui_input(touch)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(300,210)
	map._gui_input(second)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(360,210)
	var pinch_before: float = map.zoom
	map._gui_input(drag)
	expect(map.zoom > pinch_before,"two-finger pinch zooms map")
	touch.pressed = false
	second.pressed = false
	map._gui_input(touch)
	map._gui_input(second)
	expect(not is_instance_valid(ui.modal),"pinch release does not trigger an action")
	map.reset_view()
	for method in ["_configure_dialog","_diplomacy_dialog","_load_dialog"]:
		ui.call(method)
		await frames()
		expect(is_instance_valid(ui.modal),method + " opens")
		ui._close_modal()
	ui._split_dialog(ui.selected_fleet)
	await frames()
	expect(find_button(ui.modal,"确认拆分") != null,"split slider confirmation")
	ui._close_modal()
	ui._attack_dialog(ui.selected_fleet,"p12")
	await frames()
	expect(find_button(ui.modal,"直接突袭") != null,"all attack choices available")
	ui._close_modal()
	ui._on_target("gate","g23")
	await frames()
	expect(find_button(ui.modal,"修复") != null,"gate interaction menu")
	ui._close_modal()
	# Small viewport checks; no real save slot is touched.
	root.size = Vector2i(540,900)
	root.content_scale_size = Vector2i(540,900)
	await frames(15)
	ui.scroll.scroll_vertical = 0
	await snapshot("06-mobile-map")
	expect(ui.page.size.x <= ui.size.x + 2,"mobile content has no horizontal overflow")
	ui._configure_dialog()
	await frames()
	await snapshot("07-mobile-config")
	expect(ui.modal.get_child(1).size.x <= ui.size.x,"mobile modal fits viewport")
	ui._close_modal()
	ui.screen_state = "start"
	ui._schedule_build()
	await frames(10)
	ui.scroll.scroll_vertical = 0
	await snapshot("08-mobile-start")
	expect(ui.page.size.x <= ui.size.x + 2,"mobile start has no horizontal overflow")
	ui.queue_free()
	await frames()
	completed_ui_suites += 1

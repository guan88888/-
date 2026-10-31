extends SceneTree
const Rules = preload("res://game_state.gd")
const F = preload("res://frontier_systems.gd")
var checks: int = 0
var failures: int = 0
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var g := Rules.new()
	g.new_game("帝国",7,"FRONTIER",{"resources":1000,"invasion":0})
	g.state.ap = 100
	expect(F.validate(g.state)=="","new frontier validates")
	var before: Dictionary = g.state.duplicate(true)
	expect(not F.act(g,"build_ship","unknown").ok and before==g.state,"unknown ship is atomic")
	g.res().credits = 0
	before = g.state.duplicate(true)
	var old_rng: int = g.rng.state
	expect(not F.act(g,"draw","",10).ok and g.state==before and g.rng.state==old_rng,"insufficient credits consume neither state nor RNG")
	g.res().credits = 1000
	g.state.frontier.pity = 19
	expect(F.act(g,"draw").ok and int(g.state.frontier.ships["深渊"])==1 and int(g.state.frontier.pity)==0,"20th draw guarantees SSR and resets pity")
	F.act(g,"draw","",10)
	expect(int(g.state.frontier.draws)==11 and g.state.frontier.history.size()==11,"ten draws apply individual rewards")
	g.state.frontier.ships["星尘"] = 0
	g.state.frontier.stars["星尘"] = 0
	var star_text: String = F._grant_ship(g.state.frontier,"星尘")
	F._grant_ship(g.state.frontier,"星尘")
	expect(star_text == "星尘级侦察舰" and int(g.state.frontier.stars["星尘"]) == 2,"duplicate ship raises star level")
	for i in range(8): F._grant_ship(g.state.frontier,"星尘")
	expect(int(g.state.frontier.stars["星尘"]) == 5,"ship star level caps at five")
	var buy_credits: int = int(g.res().credits)
	var buy_count: int = int(g.state.frontier.ships["苍穹"])
	expect(F.act(g,"buy_ship","苍穹").ok and int(g.res().credits) == buy_credits-104 and int(g.state.frontier.ships["苍穹"]) == buy_count+1,"direct ship purchase consumes star coins")
	F.act(g,"select","深渊")
	F.act(g,"upgrade_ship","深渊")
	expect(int(g.state.frontier.levels["深渊"])==2 and F.strength(g.state.frontier)>=40,"upgraded ship improves expedition strength")
	for i in range(3): expect(F.act(g,"dungeon","深空堡垒").ok,"dungeon resolves")
	before = g.state.duplicate(true)
	expect(not F.act(g,"dungeon","深空堡垒").ok and before==g.state,"attempt cap is atomic")
	expect(int(g.state.frontier.clears["深空堡垒"])==3 and int(g.state.frontier.reputation)==18,"dungeon rewards and faction reputation earned")
	var welfare_credits: int = int(g.res().credits)
	expect(F.act(g,"welfare","daily").ok and int(g.res().credits) == welfare_credits+50,"daily welfare grants star coins")
	expect(not F.act(g,"welfare","daily").ok,"welfare cannot be claimed twice in one round")
	expect(F.act(g,"welfare","weekly").ok and int(g.state.frontier.ships["星尘"]) > 9,"three dungeon clears unlock weekly welfare ship")
	F.act(g,"faction_supply")
	expect(int(g.state.frontier.reputation)==8,"faction exchange consumes merit")
	F.act(g,"building","合金矿场")
	var ore: int = int(g.res().materials)
	F.tick(g)
	expect(int(g.res().materials)==ore+4 and int(g.state.frontier.attempts)==3,"upgraded home production and turn reset")
	before = g.state.duplicate(true)
	expect(not F.act(g,"deploy","深渊").ok and g.state==before,"cannot deploy last selected ship")
	F.act(g,"build_ship","深渊")
	var fleets: int = g.state.fleets.size()
	F.act(g,"deploy","深渊")
	expect(g.state.fleets.size()==fleets+1 and g.state.fleets.back().level==2,"deploy creates upgraded campaign fleet")
	var dir: String = OS.get_cache_dir().path_join("frontier-test-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	expect(g.save_game("1",dir)=="","save frontier")
	var h := Rules.new()
	var load_error: String = h.load_game("1",dir)
	expect(load_error=="" and h.state.frontier==JSON.parse_string(JSON.stringify(g.state.frontier)),"frontier save roundtrip")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("campaign_slot_1.json")))
	legacy.frontier.erase("stars")
	legacy.frontier.erase("welfare")
	var legacy_file := FileAccess.open(dir.path_join("campaign_slot_3.json"),FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var legacy_error: String = h.load_game("3",dir)
	expect(legacy_error=="" and h.state.frontier.has("stars") and h.state.frontier.has("welfare"),"legacy frontier fields migrate on load")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(g.state))
	bad.frontier.levels["曙光"] = "bad"
	var file := FileAccess.open(dir.path_join("campaign_slot_2.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	var current: Dictionary = h.state.duplicate(true)
	expect(h.load_game("2",dir)!="" and h.state==current,"corrupt frontier rejected without changing current game")
	var series := Rules.new()
	series.new_game("联盟",8,"SERIES")
	series.state.frontier.buildings["贸易港"] = 3
	series.state.frontier.pity = 12
	series.state.phase = "finished"
	series.state.winner = "联盟"
	expect(series.advance_series().ok and int(series.state.frontier.buildings["贸易港"])==3 and int(series.state.frontier.pity)==12,"chapter transition preserves home and pity")
	g.state.frontier.ships["深渊"] = -1
	expect(F.validate(g.state)!="","negative stock rejected")
	g.state = before
	g.state.erase("frontier")
	F.ensure(g)
	expect(F.validate(g.state)=="" and int(g.state.frontier.ships["曙光"])==1,"legacy migration gives starter ship")
	g.state.phase = "finished"
	before = g.state.duplicate(true)
	expect(not F.act(g,"draw").ok and g.state==before,"finished campaign blocks rewards")
	print("Frontier: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

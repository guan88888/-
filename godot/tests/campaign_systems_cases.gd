extends RefCounted
const Rules = preload("res://game_state.gd")
const Systems = preload("res://campaign_systems.gd")

static func run(t) -> void:
	var g = t.fresh()
	t.expect(g.planet_view("p0").known_units == -1,"remote garrison unknown at start")
	var scout: Dictionary = g.spawn_fleet("帝国","",2,"侦察","迷雾测试侦察舰")
	scout.x = 75
	scout.y = 110
	g.refresh_intel()
	var observed: Dictionary = g.planet_view("p0")
	t.expect(observed.current_detail and int(observed.known_units)==g.ships("p0"),"scout resolves exact garrison")
	var remote_enemy: Dictionary = g.spawn_fleet("混沌","",3,"突击","远处隐名舰")
	remote_enemy.x = 100
	remote_enemy.y = 120
	g.refresh_intel()
	t.expect(Systems._find(g.fleet_views(),str(remote_enemy.id)).live,"scout detects enemy fleet")
	scout.x = 940
	scout.y = 740
	remote_enemy.x = 80
	remote_enemy.y = 60
	g.planet("p0").militia = 77
	g.state.turn += 1
	g.refresh_intel()
	var ghost: Dictionary = Systems._find(g.fleet_views(),str(remote_enemy.id))
	t.expect(not ghost.live and ghost.x==100 and ghost.y==120,"lost contact retains old location, not live coordinates")
	t.expect(g.planet_view("p0").known_units==observed.known_units,"hidden garrison change does not update old report")
	var frame_before: Dictionary = g.observer_frame()
	remote_enemy.x = 50
	remote_enemy.y = 45
	var hidden_events: Array = Systems.record(g,frame_before)
	t.expect(hidden_events.is_empty(),"replay suppresses movements entirely beyond sight")
	var action_before: Dictionary = g.state.duplicate(true)
	t.expect(not g.act("encounter",{"fleet":scout.id,"target":remote_enemy.id,"choice":"立即开战"}).ok,"cannot target unseen fleet by its internal id")
	t.expect(g.state==action_before,"unseen encounter rejection is atomic")
	scout.x = 75
	scout.y = 110
	g.refresh_intel()
	t.expect(g.planet_view("p0").known_units==77,"returning scout updates stale report")
	t.expect(Systems._find(g.fleet_views(),str(remote_enemy.id)).x==50,"reacquiring contact resolves its current coordinates")
	remote_enemy.modules = ["隐匿"]
	scout.type = "守卫"
	g.refresh_intel()
	t.expect(not Systems.fleet_live(g,remote_enemy),"ordinary sensor cannot penetrate stealth")
	scout.type = "侦察"
	t.expect(Systems.fleet_live(g,remote_enemy),"recon sensor detects nearby stealth")
	var ap: int = int(g.state.ap)
	var intel: int = int(g.res().intel)
	t.expect(g.act("scan",{"fleet":scout.id}).ok,"active recon scan succeeds")
	t.expect(g.state.ap==ap-1 and g.res().intel==intel-2,"active scan charges resources once")
	t.expect(int(scout.revealed)==int(g.state.turn)+1,"active scan exposes scanning ship")
	scout.x = 950
	scout.y = 740
	g.state.turn += 2
	g.refresh_intel()
	t.expect(g.state.fog.scans.is_empty() and not g.planet_view("p0").current_detail,"expired scan stops live intelligence")
	g = t.fresh()
	var ordinary: Dictionary = g.stationed("p11","帝国")[0]
	var before: Dictionary = g.state.duplicate(true)
	t.expect(not g.act("scan",{"fleet":ordinary.id}).ok and g.state==before,"ordinary ship cannot scan for free")
	t.expect(g.act("diplomacy",{"faction":"混沌","choice":"交换情报"}).ok,"diplomacy provides dated reports")
	t.expect(g.planet_view("p1").known_units>=0,"foreign intelligence includes remote garrison")
	var shared: int = int(g.planet_view("p1").known_units)
	g.stationed("p1")[0].units = 89
	g.refresh_intel()
	t.expect(int(g.planet_view("p1").known_units)==shared,"shared intelligence is not continuous tracking")
	var raid = t.fresh()
	var spent: Dictionary = raid.res("混沌").duplicate(true)
	for key in Rules.RESOURCES: raid.res("混沌")[key] = 0
	var fleet_before: Array = raid.state.fleets.duplicate(true)
	raid._ai_turn("混沌")
	t.expect(raid.state.fleets==fleet_before,"AI cannot conjure units or invade without funds")
	raid.res("混沌").merge(spent,true)
	var existing_ids: Array = raid.state.fleets.map(func(f: Dictionary): return f.id)
	raid._ai_turn("混沌")
	var transported: bool = false
	for f in raid.state.fleets:
		if f.owner=="混沌" and f.id in existing_ids and f.station not in ["p1","p7"]: transported = true
	t.expect(transported,"raider advances actual fleets rather than cloning garrisons")
	var defense_game := Rules.new()
	defense_game.new_game("联盟",7,"TITAN146",{"resources":500})
	defense_game.stationed("p7")[0].units = 20
	var material_before: int = int(defense_game.res("帝国").materials)
	defense_game._ai_step("帝国",0)
	t.expect(defense_game.planet("p11").building=="护盾阵列" and int(defense_game.res("帝国").materials)==material_before-4,"defender pays to fortify threatened capital")
	var trade = t.fresh()
	trade.state.turn = 3
	trade.state.relations["联盟"] = 25
	trade._ai_step("联盟",0)
	t.expect(int(trade.state.pacts["联盟"].ceasefire)==5,"trader proposes a truce when relations are warm")
	trade.state.relations["混沌"] = 0
	before = trade.state.duplicate(true)
	t.expect(not trade.act("diplomacy",{"faction":"混沌","choice":"结盟"}).ok and trade.state==before,"raider has distinct alliance requirement")
	trade.state.relations["联盟"] = -35
	t.expect(trade.act("diplomacy",{"faction":"联盟","choice":"资源交易"}).ok,"trader tolerates strained relations for trade")
	var story = t.fresh()
	story.state.turn = 2
	Systems.story_tick(story)
	t.expect(story.state.story.pending=="refugees","refugee event arrives")
	story.res().credits = 0
	before = story.state.duplicate(true)
	t.expect(not story.act("story",{"choice":0}).ok and story.state==before,"unaffordable narrative option has no side effects")
	story.res().credits = 500
	t.expect(story.act("story",{"choice":0}).ok,"accept refugee branch")
	before = story.state.duplicate(true)
	t.expect(not story.act("story",{"choice":0}).ok and story.state==before,"resolved narrative cannot reward twice")
	story.state.turn = 4
	Systems.story_tick(story)
	t.expect(story.state.story.pending=="engineers","earlier choice unlocks engineer follow-up")
	story.act("story",{"choice":1})
	story.state.turn = 5
	Systems.story_tick(story)
	story.act("story",{"choice":0})
	t.expect(story.state.story.flags.defectors and story.state.story.exposed_until==6,"defector branch creates exposure risk")
	var found: bool = false
	for f in story.state.fleets:
		if f.name=="归航者": found = int(f.level)==2 and f.type=="侦察"
	t.expect(found,"defector branch gives actual veteran recon fleet")
	story.state.turn = 7
	Systems.story_tick(story)
	t.expect(story.state.story.pending=="pursuit","defector decision triggers pursuing signals")
	story.act("story",{"choice":0})
	t.expect(story.state.story.exposed_until==0,"counter-intelligence clears narrative exposure")
	var rejected = t.fresh()
	rejected.state.turn=2
	Systems.story_tick(rejected)
	rejected.act("story",{"choice":2})
	rejected.state.turn=4
	Systems.story_tick(rejected)
	t.expect(rejected.state.story.pending=="closed_port","rejecting refugees leads to a different consequence")
	var campaign := Rules.new()
	campaign.new_game("帝国",8)
	var veteran: Dictionary = campaign.stationed("p11","帝国")[0]
	veteran.name="长夜号"
	veteran.level=3
	veteran.modules=["护盾","维修"]
	veteran.upgrades={"defense":2}
	veteran.cargo={"fuel":3}
	veteran.damage=1
	veteran.color="347fac"
	campaign.planet("p6").owner="帝国"
	var convoy: Dictionary = campaign.fleet(str(campaign.state.series.convoy))
	convoy.station="p6"
	convoy.x=campaign.planet("p6").x
	convoy.y=campaign.planet("p6").y
	campaign.check_victory()
	t.expect(campaign.state.phase=="finished" and campaign.state.series.convoy_saved,"first chapter victory records rescued supply convoy")
	var survivors: int = campaign.state.fleets.filter(func(f: Dictionary) -> bool: return f.owner=="帝国").size()
	var credits: int = campaign.res().credits
	t.expect(campaign.advance_series().ok,"advance to second chapter")
	t.expect(campaign.state.series.chapter==2 and campaign.res().credits==credits+12,"convoy unlocks next-chapter resources")
	t.expect(campaign.state.fleets.filter(func(f: Dictionary) -> bool: return f.owner=="帝国").size()==survivors,"chapter transition does not duplicate starting fleets")
	found=false
	for f in campaign.state.fleets:
		if f.name=="长夜号": found = f.level==3 and f.damage==1 and f.color=="347fac" and f.modules==["护盾","维修"] and f.cargo=={"fuel":3} and f.upgrades=={"defense":2}
	t.expect(found,"veteran identity and complete configuration persist between chapters")
	t.expect(campaign.state.fog.scans.is_empty() and campaign.state.replay.events.is_empty(),"new theatre clears old recon and replay")
	campaign.state.turn=6
	campaign.check_victory()
	t.expect(campaign.state.winner=="帝国" and campaign.advance_series().ok,"capital defense completes second chapter")
	campaign.planet("p7").owner="帝国"
	campaign.check_victory()
	t.expect(campaign.state.series.chapter==3 and campaign.state.winner=="帝国","capturing hostile capital completes expedition")
	t.expect(not campaign.advance_series().ok,"final chapter cannot advance forever")
	t.expect(campaign.validate_snapshot(campaign.state)=="","complete expedition remains saveable")
	var failed := Rules.new()
	failed.new_game("混沌",8)
	failed.state.turn=8
	failed.check_victory()
	t.expect(failed.state.winner=="敌方" and not failed.advance_series().ok,"failed chapter cannot be advanced")
	# Complete an expedition using only legal player actions and normal turn income.
	var playable := Rules.new()
	playable.new_game("帝国",8,"TITAN146",{"invasion":0})
	var leader: Dictionary = playable.stationed("p11","帝国")[0]
	t.expect(playable.act("upgrade",{"fleet":leader.id,"direction":"attack"}).ok,"expedition legal opening upgrade")
	t.expect(playable.act("attack",{"fleet":leader.id,"planet":"p6","method":"直接突袭"}).ok,"expedition legal opening captures objective")
	playable.end_turn()
	t.expect(playable.state.winner=="帝国" and playable.advance_series().ok,"chapter one can be completed without state injection")
	playable.act("build",{"planet":"p11","building":"护盾阵列"})
	for round_index in range(5):
		while int(playable.state.ap)>0 and playable.state.phase=="player":
			var reinforced: Dictionary = playable.act("reinforce",{"planet":"p11"})
			if not reinforced.ok: break
		if playable.state.phase=="player": playable.end_turn()
	t.expect(playable.state.winner=="帝国" and playable.advance_series().ok,"chapter two is survivable with legal fortification and income")
	var attackers: Array = playable.stationed("p11","帝国")
	var best: Dictionary = attackers[0] if not attackers.is_empty() else {}
	for f in playable.state.fleets:
		if f.owner=="帝国" and (best.is_empty() or playable.power(f)>playable.power(best)): best=f
	var final_attack: Dictionary = playable.act("attack",{"fleet":best.get("id",""),"planet":"p7","method":"直接突袭"})
	t.expect(final_attack.ok and playable.state.winner=="帝国" and playable.state.series.chapter==3,"all three chapters have a legal playable completion path")
	var saves = t.fresh()
	saves.end_turn()
	var saved: Dictionary = saves.state.duplicate(true)
	t.expect(saves.save_game("2",t.save_dir)=="","save new systems")
	var loaded := Rules.new()
	t.expect(loaded.load_game("2",t.save_dir)=="","load new systems")
	for key in ["fog","story","series","commanders","replay"]:
		t.expect(loaded.state[key]==JSON.parse_string(JSON.stringify(saved[key])),"round-trip preserves "+key)
	saves.end_turn()
	loaded.end_turn()
	t.expect(JSON.parse_string(JSON.stringify(saves.state.planets))==JSON.parse_string(JSON.stringify(loaded.state.planets)) and JSON.parse_string(JSON.stringify(saves.state.fleets))==JSON.parse_string(JSON.stringify(loaded.state.fleets)),"save restores deterministic AI decisions")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version=2
	legacy.rng_state=str(saved.rng_state)
	for key in ["fog","story","series","commanders","replay"]: legacy.erase(key)
	var file := FileAccess.open(t.save_dir.path_join("campaign_slot_3.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	t.expect(loaded.load_game("3",t.save_dir)=="" and loaded.state.version==3,"version two save migrates without discarding battle")
	t.expect(loaded.state.planets==JSON.parse_string(JSON.stringify(saved.planets)),"migration preserves existing territory")
	for case in range(8):
		var broken: Dictionary = saved.duplicate(true)
		match case:
			0: broken.fog.scans=[{"x":"bad","y":0,"radius":1,"until":1}]
			1: broken.story.pending="not_an_event"
			2: broken.series.chapter=99
			3: broken.replay.events=[{"text":"bad"}]
			4: broken.fog.planets.p0.known_units=[]
			5: broken.commanders["帝国"].style="unknown"
			6: broken.story.flags={"refugees":[]}
			7: broken.series.history=[{"chapter":"bad"}]
		t.expect(loaded.validate_snapshot(broken)!="","reject corrupt extension case "+str(case))
		broken.rng_state=str(saved.rng_state)
		var prior: Dictionary = loaded.state.duplicate(true)
		file = FileAccess.open(t.save_dir.path_join("campaign_slot_3.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(broken))
		file.close()
		t.expect(loaded.load_game("3",t.save_dir)!="" and loaded.state==prior,"corrupt extension load is atomic "+str(case))

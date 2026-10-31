extends RefCounted
## Serializable campaign systems. Presentation only receives observer snapshots.

const COMMANDERS: Dictionary = {
	"帝国":{"name":"林铎","style":"defender","title":"守备派","detail":"优先补强边境与首都；优势不足时不出击。结盟要求好感至少 0。"},
	"联盟":{"name":"沈遥","style":"trader","title":"通商派","detail":"优先中立资源星与贸易；好感 20 后可能主动停战。交易接受低至 -40 的好感。"},
	"混沌":{"name":"乌隼","style":"raider","title":"突袭派","detail":"优先薄弱边境、运输舰与暴露信号；结盟要求好感至少 15。"}
}
const CHAPTERS: Array = [
	{"name":"断线航道","goal":"第 6 轮结束前占领熔炉并守住一轮；将远航补给船送抵熔炉可提前完成，并获得下一章额外补给。","limit":6},
	{"name":"边境撤离","goal":"守住自己的首都，进入第 6 轮。幸存舰队将参加最后一战。","limit":7},
	{"name":"归航之战","goal":"第 10 轮结束前夺取任意一座敌方原始首都。","limit":10}
]

static func initialize(g) -> void:
	g.state.fog = {"planets":{},"fleets":{},"gates":{},"scans":[]}
	g.state.commanders = COMMANDERS.duplicate(true)
	g.state.story = {"pending":"","seen":[],"flags":{},"history":[],"exposed_until":0}
	g.state.replay = {"turn":0,"initial":{},"events":[]}
	g.state.series = {"chapter":1,"history":[],"convoy":"","convoy_saved":false}
	# Star charts are public; enemy strength is not. Turn 0 means chart only.
	for p in g.state.planets:
		var chart: Dictionary = p.duplicate(true)
		chart.known_units = -1
		chart.known_defense = -1
		chart.seen_turn = 0
		chart.detailed = false
		g.state.fog.planets[p.id] = chart
	refresh(g)

static func sensor_range(f: Dictionary, detailed: bool = false) -> float:
	var scout: bool = f.type == "侦察" or "侦察" in f.modules
	var upgrade: int = int(f.get("upgrades",{}).get("sensor",0))
	if detailed: return 230.0 + upgrade * 60 if scout else 0.0
	return (310.0 if scout else 155.0) + upgrade * 60

static func point_seen(g, point: Vector2, detailed: bool = false, observer: String = "") -> bool:
	var owner: String = str(g.state.player) if observer == "" else observer
	for f in g.state.fleets:
		if f.owner == owner and g.position_of(f).distance_to(point) <= sensor_range(f,detailed): return true
	if not detailed:
		for p in g.owned(owner):
			if g.position_of(p).distance_to(point) <= 170: return true
	if owner == g.state.player:
		for scan in g.state.fog.scans:
			if int(scan.until) >= int(g.state.turn) and Vector2(scan.x,scan.y).distance_to(point) <= float(scan.radius): return true
	return false

static func planet_live(g, p: Dictionary, detailed: bool = false) -> bool:
	if p.owner == g.state.player: return true
	if point_seen(g,g.position_of(p),detailed): return true
	if not detailed:
		for id in g.neighbors(str(p.id)):
			if g.planet(id).owner == g.state.player: return true
	return false

static func fleet_live(g, f: Dictionary) -> bool:
	if f.owner == g.state.player: return true
	if int(f.revealed) >= int(g.state.turn): return true
	if "隐匿" in f.modules and not point_seen(g,g.position_of(f),true): return false
	if f.station != "" and planet_live(g,g.planet(str(f.station))): return true
	return point_seen(g,g.position_of(f))

static func fleet_detail(g, f: Dictionary) -> bool:
	return f.owner == g.state.player or int(f.revealed) >= int(g.state.turn) or point_seen(g,g.position_of(f),true)

static func refresh(g) -> void:
	if not g.state.has("fog"): return
	var fog: Dictionary = g.state.fog
	fog.scans = fog.scans.filter(func(s: Dictionary) -> bool: return int(s.until) >= int(g.state.turn))
	for p in g.state.planets:
		if not planet_live(g,p): continue
		var detail: bool = planet_live(g,p,true)
		var entry: Dictionary = p.duplicate(true)
		entry.detailed = detail
		entry.known_units = g.ships(str(p.id)) if detail else -1
		entry.known_defense = g.defense(p) if detail else -1
		entry.seen_turn = int(g.state.turn)
		var previous: Dictionary = fog.planets.get(p.id,{})
		if not detail and previous.get("detailed",false) and previous.get("owner","") == p.owner:
			entry = previous.duplicate(true)
		fog.planets[p.id] = entry
	for f in g.state.fleets:
		if not fleet_live(g,f): continue
		var entry: Dictionary = f.duplicate(true)
		entry.detailed = fleet_detail(g,f)
		entry.seen_turn = int(g.state.turn)
		if not entry.detailed:
			entry.name = str(f.owner)+"舰队信号"
			entry.units = -1
			entry.level = 0
			entry.type = "未识别"
			entry.modules = []
			entry.upgrades = {}
			entry.cargo = {}
		fog.fleets[f.id] = entry
	# An empty last-known position clears a ghost; no remote death notification.
	for id in fog.fleets.keys():
		var old: Dictionary = fog.fleets[id]
		var actual: Dictionary = g.fleet(str(id))
		if old.owner == g.state.player and actual.is_empty():
			fog.fleets.erase(id)
		elif point_seen(g,g.position_of(old)) and (actual.is_empty() or (not fleet_live(g,actual) and g.position_of(actual).distance_to(g.position_of(old)) > 20)):
			fog.fleets.erase(id)
	for gate in g.state.gates:
		if planet_live(g,g.planet(str(gate.a))) or planet_live(g,g.planet(str(gate.b))): fog.gates[gate.id] = gate.duplicate(true)

static func planet_view(g, id: String) -> Dictionary:
	var p: Dictionary = g.state.fog.planets.get(id,{}).duplicate(true)
	if p.is_empty(): return p
	p.live = planet_live(g,g.planet(id))
	p.current_detail = planet_live(g,g.planet(id),true)
	return p

static func fleet_views(g) -> Array:
	var result: Array = []
	for id in g.state.fog.fleets:
		var entry: Dictionary = g.state.fog.fleets[id].duplicate(true)
		var actual: Dictionary = g.fleet(str(id))
		entry.live = not actual.is_empty() and fleet_live(g,actual)
		result.append(entry)
	return result

static func frame(g) -> Dictionary:
	var planets: Array = []
	for p in g.state.planets: planets.append(planet_view(g,str(p.id)))
	var gates: Array = []
	for gate in g.state.gates:
		gates.append(g.state.fog.gates.get(gate.id,{"id":gate.id,"a":gate.a,"b":gate.b,"owner":"无主","broken":false,"blocked":0}).duplicate(true))
	return {"planets":planets,"fleets":fleet_views(g),"gates":gates,"turn":int(g.state.turn)}

static func scan(g, f: Dictionary) -> Dictionary:
	if f.is_empty() or f.owner != g.state.player: return g.fail("先选择己方舰队。")
	if f.type != "侦察" and "侦察" not in f.modules: return g.fail("主动扫描需要侦察舰或侦察模块。")
	var reason: String = g._cost(1,{"intel":2})
	if reason != "": return g.fail(reason)
	g._pay(1,{"intel":2})
	g.state.fog.scans.append({"x":f.x,"y":f.y,"radius":420+int(f.get("upgrades",{}).get("sensor",0))*60,"until":int(g.state.turn)+1})
	f.revealed = int(g.state.turn)+1
	return g.done("主动扫描完成：周围 420 范围的驻军与舰队已识别，持续到下一轮；自身信号也会暴露。")

static func share_intel(g, other: String) -> void:
	# A dated report, not a live tracking subscription.
	for p in g.state.planets:
		if p.owner == other or point_seen(g,g.position_of(p),false,other):
			var entry: Dictionary = p.duplicate(true)
			entry.known_units = g.ships(str(p.id))
			entry.known_defense = g.defense(p)
			entry.detailed = true
			entry.seen_turn = int(g.state.turn)
			g.state.fog.planets[p.id] = entry
	for f in g.state.fleets:
		if f.owner == g.state.player: continue
		if f.owner == other or point_seen(g,g.position_of(f),true,other):
			var entry: Dictionary = f.duplicate(true)
			entry.detailed = true
			entry.seen_turn = int(g.state.turn)
			g.state.fog.fleets[f.id] = entry

static func record(g, before: Dictionary, label: String = "") -> Array:
	refresh(g)
	var after: Dictionary = frame(g)
	var events: Array = []
	for p in after.planets:
		var old: Dictionary = _find(before.planets,str(p.id))
		if old.is_empty() or not p.live: continue
		if old.owner != p.owner:
			events.append({"kind":"capture","text":"%s：%s → %s" % [p.name,old.owner,p.owner],"from":[p.x,p.y],"to":[p.x,p.y]})
	for f in after.fleets:
		if not f.live: continue
		var old: Dictionary = _find(before.fleets,str(f.id))
		if old.is_empty() or not old.get("live",false):
			events.append({"kind":"contact","text":"发现%s。" % f.name,"from":[f.x,f.y],"to":[f.x,f.y]})
		elif Vector2(old.x,old.y).distance_to(Vector2(f.x,f.y)) > 2:
			events.append({"kind":"move","text":"%s移动至新位置。" % f.name,"from":[old.x,old.y],"to":[f.x,f.y]})
		if not old.is_empty() and int(old.units) > 0 and int(f.units) > 0 and int(f.units) < int(old.units):
			events.append({"kind":"battle","text":"%s损失 %d 单位。" % [f.name,int(old.units)-int(f.units)],"from":[f.x,f.y],"to":[f.x,f.y]})
	for f in before.fleets:
		if not f.get("live",false): continue
		var current: Dictionary = _find(after.fleets,str(f.id))
		if current.is_empty():
			events.append({"kind":"battle" if f.owner==g.state.player else "contact","text":"%s被摧毁或撤销编制。" % f.name if f.owner==g.state.player else "%s的原位置已空，信号消失。" % f.name,"from":[f.x,f.y],"to":[f.x,f.y]})
		elif not current.live:
			events.append({"kind":"contact","text":"失去%s的实时信号，保留最后位置。" % f.name,"from":[f.x,f.y],"to":[f.x,f.y]})
	if events.is_empty() and label != "": events.append({"kind":"report","text":label,"from":[500,410],"to":[500,410]})
	for event in events:
		event.frame = after.duplicate(true)
	return events

static func _find(items: Array, id: String) -> Dictionary:
	for item in items:
		if item.id == id: return item
	return {}

static func story_tick(g) -> void:
	var story: Dictionary = g.state.story
	if story.pending != "" or g.state.phase != "player": return
	var schedule: Array = [[2,"refugees"],[4,"engineers" if story.flags.get("refugees",false) else "closed_port"],[5,"defectors"],[7,"pursuit" if story.flags.get("defectors",false) else "safe_route"]]
	for pair in schedule:
		if int(g.state.turn) >= int(pair[0]) and pair[1] not in story.seen:
			story.pending = pair[1]
			return

static func story_info(id: String) -> Dictionary:
	var stories: Dictionary = {
		"refugees":{"title":"边境难民","body":"一支民用船队请求入港，其中有退役工程人员。接纳他们需要占用补给。","choices":[["接纳船队","4 信用 / 3 燃料；两轮后开启工程师支线。"],["提供航路","2 情报；声望 +3，不接纳船队。"],["关闭港口","不消耗资源；之后可能遇到边境抗议。"]]},
		"engineers":{"title":"工程师的承诺","body":"获救的工程师愿意留下来维修舰队，也可以帮助重建工业。","choices":[["加入维修组","3 材料；所有现存己舰修复至多 2 个受损单位。"],["协助生产","获得 6 材料和 4 信用，记录工程师支援。"]]},
		"closed_port":{"title":"边境抗议","body":"难民被拒收后，边境居民要求解释。","choices":[["发放补偿","3 信用；己方领地好感 +5。"],["维持决定","不消耗资源；声望 -3。"]]},
		"defectors":{"title":"叛逃舰队","body":"一支受损侦察舰请求投诚。它仍使用旧识别码，收编可能让敌方追踪到你的舰队。","choices":[["接收叛舰","获得一支 LV.2 侦察舰；己舰暴露两轮，并开启追击支线。"],["交换航图","获得 5 情报；不接收舰队。"],["拒绝接触","不消耗资源，也不暴露坐标。"]]},
		"pursuit":{"title":"识别码追踪","body":"敌方正在用叛舰的旧识别码锁定补给航线。","choices":[["重写识别码","4 情报；立即解除剧情导致的暴露。"],["紧急转移","4 燃料；解除暴露，获得 1 行动。"],["保持航线","不消耗资源；全部己舰继续暴露两轮。"]]},
		"safe_route":{"title":"旧商路","body":"一位商人愿意出售避开交战区的补给线路。","choices":[["购买补给图","3 信用；获得 6 燃料。"],["暂不交易","不消耗资源。"]]}
	}
	return stories.get(id,{})

static func story_choice(g, index: int) -> Dictionary:
	var story: Dictionary = g.state.story
	var id: String = str(story.pending)
	var info: Dictionary = story_info(id)
	if info.is_empty() or index < 0 or index >= info.choices.size(): return g.fail("这项剧情选择已经失效。")
	var costs: Dictionary = {}
	match id:
		"refugees": costs = {"credits":4,"fuel":3} if index == 0 else ({"intel":2} if index == 1 else {})
		"engineers": costs = {"materials":3} if index == 0 else {}
		"closed_port": costs = {"credits":3} if index == 0 else {}
		"pursuit": costs = {"intel":4} if index == 0 else ({"fuel":4} if index == 1 else {})
		"safe_route": costs = {"credits":3} if index == 0 else {}
	var reason: String = g._cost(0,costs)
	if reason != "": return g.fail(reason)
	g._pay(0,costs)
	match id:
		"refugees":
			story.flags.refugees = index == 0
			if index == 1: g.res().reputation += 3
		"engineers":
			story.flags.engineers = true
			if index == 0:
				for f in g.state.fleets:
					if f.owner == g.state.player:
						var healed: int = mini(2,int(f.get("damage",0)))
						f.units += healed
						f.damage = int(f.get("damage",0))-healed
			else:
				g.res().materials += 6
				g.res().credits += 4
		"closed_port":
			if index == 0:
				for p in g.owned(): p.affinity = mini(100,int(p.affinity)+5)
			else: g.res().reputation = maxi(0,int(g.res().reputation)-3)
		"defectors":
			story.flags.defectors = index == 0
			if index == 0:
				var homes: Array = g.owned()
				if not homes.is_empty():
					var f: Dictionary = g.spawn_fleet(str(g.state.player),str(homes[0].id),2,"侦察","归航者")
					f.level = 2
					f.damage = 2
					f.modules = ["侦察"]
				story.exposed_until = int(g.state.turn)+1
			elif index == 1: g.res().intel += 5
		"pursuit":
			story.exposed_until = int(g.state.turn)+1 if index == 2 else 0
			if index == 1: g.state.ap += 1
		"safe_route":
			if index == 0: g.res().fuel += 6
	story.seen.append(id)
	story.history.append(info.title+"："+str(info.choices[index][0]))
	story.pending = ""
	return g.done("%s：%s。" % [info.title,info.choices[index][0]])

static func start_series(g) -> void:
	g.state.limit = CHAPTERS[0].limit
	var convoy: Dictionary = g.spawn_fleet(str(g.state.player),g.capital_for(str(g.state.player)),2,"运输","远航补给船")
	g.state.series.convoy = convoy.id
	g.log_event("连续战役 · 第一章「断线航道」。")

static func series_victory(g) -> void:
	var chapter: int = int(g.state.series.chapter)
	var won: bool = false
	if chapter == 1:
		var convoy: Dictionary = g.fleet(str(g.state.series.convoy))
		if not convoy.is_empty() and convoy.station == "p6": g.state.series.convoy_saved = true
		# A full round on the objective leaves time to escort the optional convoy.
		if g.planet("p6").owner == g.state.player:
			if not g.state.series.has("secured_turn"): g.state.series.secured_turn = int(g.state.turn)
			won = int(g.state.turn) > int(g.state.series.secured_turn) or bool(g.state.series.convoy_saved)
		else: g.state.series.erase("secured_turn")
	elif chapter == 2:
		if g.planet(g.capital_for(str(g.state.player))).owner != g.state.player:
			g._finish("敌方","撤离期间首都失守。")
			return
		won = int(g.state.turn) >= 6
	else:
		for p in g.owned():
			if p.capital and p.home != g.state.player: won = true
	if won: g._finish(str(g.state.player),"第 %d 章「%s」完成。%s" % [chapter,CHAPTERS[chapter-1].name,"三章战役全部完成。" if chapter == 3 else "幸存舰队已准备进入下一章。"])
	elif int(g.state.turn) > int(g.state.limit): g._finish("敌方","本章期限已到，目标未完成。")

static func advance_series(g) -> Dictionary:
	if int(g.state.mode) != 8 or g.state.phase != "finished" or g.state.winner != g.state.player or int(g.state.series.chapter) >= 3: return g.fail("只有本章胜利后才能进入下一章。")
	var series: Dictionary = g.state.series.duplicate(true)
	var survivors: Array = g.state.fleets.filter(func(f: Dictionary) -> bool: return f.owner == g.state.player).duplicate(true)
	if survivors.is_empty(): return g.fail("没有可带入下一章的幸存舰队。")
	var resources: Dictionary = g.res().duplicate(true)
	var frontier_progress: Dictionary = g.state.get("frontier",{}).duplicate(true)
	var story: Dictionary = g.state.story.duplicate(true)
	series.history.append({"chapter":series.chapter,"survivors":survivors.size(),"result":g.state.result})
	series.chapter = int(series.chapter)+1
	series.erase("secured_turn")
	var seed_text: String = str(g.state.seed).split("/CH")[0]+"/CH"+str(series.chapter)
	var player: String = str(g.state.player)
	g.new_game(player,0,seed_text)
	g.state.mode = 8
	g.state.frontier = frontier_progress
	g.state.series = series
	g.state.limit = CHAPTERS[int(series.chapter)-1].limit
	g.state.resources[player] = resources
	g.res().fuel += 6
	if int(series.chapter) == 2 and series.convoy_saved:
		g.res().credits += 12
		g.res().materials += 8
		g.res().fuel += 8
	if story.flags.get("engineers",false): g.res().materials += 3
	g.state.story = story
	g.state.story.exposed_until = 0
	# Never duplicate the starting garrisons when importing veterans.
	g.state.fleets = g.state.fleets.filter(func(f: Dictionary) -> bool: return f.owner != player)
	var homes: Array = g.owned()
	for i in range(survivors.size()):
		var old: Dictionary = survivors[i]
		var p: Dictionary = homes[i%homes.size()]
		var next: Dictionary = g.spawn_fleet(player,str(p.id),int(old.units),str(old.type),str(old.name))
		for key in ["level","modules","icon","color","upgrades","cargo","damage"]:
			var value: Variant = old.get(key,next[key])
			next[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	# Reset theatre intelligence; retain narrative choices and the expedition history.
	var saved_story: Dictionary = g.state.story
	initialize(g)
	g.state.story = saved_story
	g.state.series = series
	g.state.replay = {"turn":0,"initial":{},"events":[]}
	return g.done("进入第 %d 章「%s」，%d 支幸存舰队已抵达。" % [int(series.chapter),CHAPTERS[int(series.chapter)-1].name,survivors.size()])

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < 1.0e12

static func _report_valid(report: Variant) -> bool:
	if not report is Dictionary or not _number(report.get("turn")): return false
	for key in ["planets","fleets","gates"]:
		if not report.get(key) is Array or report[key].size() > 1024: return false
	for p in report.planets:
		if not _planet_valid(p) or not p.get("live") is bool or not p.get("current_detail") is bool: return false
	for f in report.fleets:
		if not _fleet_valid(f) or not f.get("live") is bool: return false
	for gate in report.gates:
		if not _gate_valid(gate): return false
	return true

static func _planet_valid(p: Variant) -> bool:
	if not p is Dictionary: return false
	for key in ["id","name","owner","home","type","building","status","policy"]:
		if not p.get(key) is String: return false
	for key in ["x","y","income","defense","militia","affinity","locked","siege","known_units","known_defense","seen_turn"]:
		if not _number(p.get(key)): return false
	for key in ["capital","depleted","detailed"]:
		if not p.get(key) is bool: return false
	if p.has("live") and not p.live is bool: return false
	return p.owner in ["帝国","联盟","混沌","外星","无主"]

static func _fleet_valid(f: Variant) -> bool:
	if not f is Dictionary: return false
	for key in ["id","name","owner","station","type","icon","color"]:
		if not f.get(key) is String: return false
	for key in ["x","y","units","level","seen_turn"]:
		if not _number(f.get(key)): return false
	if not f.get("detailed") is bool or (f.has("live") and not f.live is bool): return false
	if not f.get("modules") is Array: return false
	for module in f.modules:
		if not module is String: return false
	return Color.html_is_valid(f.color) and f.owner in ["帝国","联盟","混沌","外星"]

static func _gate_valid(gate: Variant) -> bool:
	if not gate is Dictionary: return false
	for key in ["id","a","b","owner"]:
		if not gate.get(key) is String: return false
	return gate.owner in ["帝国","联盟","混沌","外星","无主"] and _number(gate.get("blocked")) and gate.get("broken") is bool

static func validate(data: Dictionary) -> String:
	var error: String = "存档的侦察、剧情或连续战役数据损坏；当前战局未改动。"
	for key in ["fog","commanders","story","replay","series"]:
		if not data.get(key) is Dictionary: return error
	var fog: Dictionary = data.fog
	for key in ["planets","fleets","gates"]:
		if not fog.get(key) is Dictionary or fog[key].size() > 1024: return error
	for p in data.planets:
		if not fog.planets.has(p.id): return error
	for key in fog.planets:
		if not key is String or not _planet_valid(fog.planets[key]) or fog.planets[key].id != key: return error
	for key in fog.fleets:
		if not key is String or not _fleet_valid(fog.fleets[key]) or fog.fleets[key].id != key: return error
	for key in fog.gates:
		if not key is String or not _gate_valid(fog.gates[key]) or fog.gates[key].id != key: return error
	if not fog.get("scans") is Array or fog.scans.size() > 1024: return error
	for scan in fog.scans:
		if not scan is Dictionary: return error
		for key in ["x","y","radius","until"]:
			if not _number(scan.get(key)): return error
	for faction in COMMANDERS:
		if not data.commanders.get(faction) is Dictionary: return error
		for key in ["name","style","title","detail"]:
			if not data.commanders[faction].get(key) is String: return error
		if data.commanders[faction].style not in ["defender","trader","raider"]: return error
	var story: Dictionary = data.story
	if not story.get("pending") is String or (story.pending != "" and story_info(story.pending).is_empty()): return error
	if not story.get("seen") is Array or not story.get("history") is Array or not story.get("flags") is Dictionary or not _number(story.get("exposed_until")): return error
	for id in story.seen:
		if not id is String or story_info(id).is_empty(): return error
	for entry in story.history:
		if not entry is String: return error
	for key in story.flags:
		if not key is String or not story.flags[key] is bool: return error
	var series: Dictionary = data.series
	if not _number(series.get("chapter")) or int(series.chapter) not in [1,2,3] or not series.get("convoy") is String or not series.get("convoy_saved") is bool or not series.get("history") is Array: return error
	if series.has("secured_turn") and not _number(series.secured_turn): return error
	for entry in series.history:
		if not entry is Dictionary or not _number(entry.get("chapter")) or not _number(entry.get("survivors")) or not entry.get("result") is String: return error
	var replay: Dictionary = data.replay
	if not _number(replay.get("turn")) or not replay.get("initial") is Dictionary or not replay.get("events") is Array or replay.events.size()>64: return error
	if not replay.initial.is_empty() and not _report_valid(replay.initial): return error
	if not replay.events.is_empty() and replay.initial.is_empty(): return error
	for event in replay.events:
		if not event is Dictionary or not event.get("text") is String or event.get("kind") not in ["move","battle","capture","contact","report"]: return error
		for key in ["from","to"]:
			if not event.get(key) is Array or event[key].size() != 2: return error
			for number in event[key]:
				if not _number(number): return error
		if not _report_valid(event.get("frame")): return error
	return ""

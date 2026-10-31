extends RefCounted
## All campaign rules live here. Coordinates are JSON-safe numbers, never Nodes.

const VERSION: int = 3
const Systems = preload("res://campaign_systems.gd")
const FACTIONS: Array[String] = ["帝国", "联盟", "混沌", "外星"]
const COLORS: Dictionary = {"帝国":"81acd4", "联盟":"c4aa82", "混沌":"a59bc6", "无主":"98a5b7", "外星":"ce8288"}
const MODES: Array[String] = ["标准银河战争", "外星入侵", "星门争夺", "护航运输", "残局生存", "外交竞赛", "随机灾变", "沙盒", "连续战役"]
const TYPES: Array[String] = ["突击", "守卫", "开拓", "劫掠", "侦察", "运输"]
const MODULES: Array[String] = ["主武器", "护盾", "引擎", "侦察", "运输", "维修", "隐匿", "帝国矩阵", "联盟信标", "混沌跃迁"]
const RESOURCES: Array[String] = ["credits", "materials", "intel", "fuel", "reputation"]
const RESOURCE_NAMES: Dictionary = {"credits":"信用点", "materials":"材料", "intel":"情报", "fuel":"燃料", "reputation":"声望"}
const UPGRADES: Dictionary = {"attack":"攻击力","defense":"防御力","speed":"移动速度","gate":"星门移动效率","range":"远程攻击","sensor":"侦察范围","cargo":"运输容量","repair":"维修速度","retreat":"撤退成功率","influence":"外交威慑力"}
const MODE_HELP: Array[String] = [
	"夺取全部首都，或在战争周期结束时获得最高积分。",
	"第 3 轮起持续入侵；摧毁 3 个入侵核心并清除外星舰队，共同获胜。",
	"率先控制 5 座星门。己方控制的星门每轮额外产出信用点。",
	"护送「曙光运输船」抵达标记终点；运输船被击毁即失败。",
	"低资源开局；每轮外星军增强，坚持到第 10 轮且保住首都。",
	"通过好感、声望和协议获得 180 外交分；无需发动战争。",
	"每轮发生灾变，修复网络、稳定领地，在第 12 轮比较积分。",
	"自由调整资源、回合数、初始舰队、入侵概率与关系，不强制结算。",
	"三章远征：控制熔炉、坚守首都、夺取敌都。幸存舰队与资源延续，护送补给船影响下一章补给。"
]
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()

func new_game(faction: String = "帝国", mode: int = 0, seed_text: String = "TITAN146", settings: Dictionary = {}) -> void:
	rng.seed = absi(seed_text.hash())
	state = {"version":VERSION, "player":faction, "mode":mode, "seed":seed_text, "turn":1, "limit":int(settings.get("limit",12)), "ap":2, "phase":"player", "winner":"", "result":"", "next_fleet":1, "planets":[], "fleets":[], "gates":[], "resources":{}, "relations":{}, "pacts":{}, "skill_turn":0, "ultimate":false, "diplomacy_turn":0, "invasion":0, "cores_destroyed":0, "events":[], "log":[], "settings":settings.duplicate(true), "escort":"", "escort_goal":"", "rng_state":0, "frontier":{}}
	for f in FACTIONS:
		state.resources[f] = {"credits":24, "materials":14, "intel":10, "fuel":24, "reputation":20}
		state.relations[f] = int(settings.get("relations",0))
		state.pacts[f] = {"alliance":0, "ceasefire":0, "access":0, "protection":0, "joint":0}
	var names: Array[String] = ["脉冲", "圣环", "天琴", "织女座", "渡鸦", "螺旋港", "熔炉", "新伊甸", "镜海", "玄幕", "静默港", "猎户庭", "断层", "泰坦锚", "暗面", "神盾", "凡塔", "开普勒"]
	var starting_ships: Array[int] = [2,2,2,1,1,1,2,4,2,2,2,4,2,2,1,2,4,1]
	var points: Array[Vector2] = [Vector2(75,110),Vector2(150,174),Vector2(75,320),Vector2(400,80),Vector2(665,117),Vector2(860,199),Vector2(485,275),Vector2(256,353),Vector2(756,340),Vector2(911,378),Vector2(115,551),Vector2(360,551),Vector2(625,503),Vector2(823,565),Vector2(510,678),Vector2(785,701),Vector2(927,660),Vector2(220,704)]
	for i in range(names.size()):
		var owner: String = "无主"
		if i in [9,11]: owner = "帝国"
		if i in [10,12,16]: owner = "联盟"
		if i in [1,7]: owner = "混沌"
		var pos: Vector2 = points[i]
		if seed_text != "TITAN146": pos += Vector2(rng.randf_range(-20,20),rng.randf_range(-18,18))
		var capital: bool = i in [7,11,16]
		state.planets.append({"id":"p%d" % i, "name":names[i], "x":pos.x, "y":pos.y, "owner":owner, "capital":capital, "home":owner if capital else "", "type":["工业", "资源", "贸易", "遗迹"][i % 4], "income":3 if i % 4 == 2 else 2, "defense":1 if capital else 0, "militia":starting_ships[i] if owner == "无主" else 0, "affinity":25, "building":"首都中枢" if capital else "无", "status":"稳定", "locked":0, "siege":0, "policy":"直接统治", "depleted":false})
	var edges: Array = [[0,1],[0,3],[0,2],[1,7],[1,3],[2,7],[2,10],[3,7],[3,6],[3,4],[4,5],[4,8],[5,8],[5,9],[6,7],[6,8],[6,12],[7,11],[8,12],[8,13],[9,13],[9,16],[10,11],[10,17],[11,12],[11,14],[11,17],[12,13],[12,14],[13,15],[13,16],[14,15],[14,17],[15,16]]
	for pair in edges:
		state.gates.append({"id":"g%d" % state.gates.size(), "a":"p%d" % int(pair[0]), "b":"p%d" % int(pair[1]), "owner":"无主", "blocked":0, "broken":false})
	if seed_text != "TITAN146":
		for p in state.planets:
			p.type = ["工业","资源","贸易","遗迹"][rng.randi_range(0,3)]
			p.income = rng.randi_range(1,4)
			if p.owner == "无主": p.militia = rng.randi_range(1,3)
		for attempt in range(6):
			var a: Dictionary = state.planets[rng.randi_range(0,17)]
			var b: Dictionary = state.planets[rng.randi_range(0,17)]
			if a.id != b.id and position_of(a).distance_to(position_of(b)) < 350 and adjacency(str(a.id),str(b.id)).is_empty():
				state.gates.append({"id":"g%d" % state.gates.size(),"a":a.id,"b":b.id,"owner":"无主","blocked":0,"broken":false})
	for p in state.planets:
		if p.owner != "无主":
			spawn_fleet(str(p.owner), str(p.id), 4 if p.capital else 2, "突击" if p.id == "p1" else "守卫", "%s驻守舰队" % p.name)
	if mode == 3:
		var escort: Dictionary = spawn_fleet(faction, capital_for(faction), 2, "运输", "曙光运输船")
		state.escort = escort.id
		state.escort_goal = "p3" if faction != "混沌" else "p13"
	if mode == 4:
		state.limit = 10
		res()["credits"] = 8
		res()["materials"] = 4
	if mode == 7:
		for key in RESOURCES: res()[key] = int(settings.get("resources",100))
		for f in state.fleets:
			if f.owner == faction: f.units = maxi(1,int(settings.get("fleets",4)))
	update_gates()
	log_event("星门破碎纪元 100 年 · %s已接入星门网络。" % faction)
	state.rng_state = rng.state
	Systems.initialize(self)
	if mode == 8: Systems.start_series(self)
	Systems.refresh(self)
	_init_new_systems()

func _init_new_systems() -> void:
	preload("res://frontier_systems.gd").ensure(self)

func planet_view(id: String) -> Dictionary:
	return Systems.planet_view(self,id)

func fleet_views() -> Array:
	return Systems.fleet_views(self)

func observer_frame() -> Dictionary:
	return Systems.frame(self)

func refresh_intel() -> void:
	Systems.refresh(self)

func advance_series() -> Dictionary:
	return Systems.advance_series(self)

func res(owner: String = "") -> Dictionary:
	return state.resources[owner if owner != "" else str(state.player)]

func planet(id: String) -> Dictionary:
	for p in state.get("planets",[]):
		if p.id == id: return p
	return {}

func fleet(id: String) -> Dictionary:
	for f in state.get("fleets",[]):
		if f.id == id: return f
	return {}

func gate(id: String) -> Dictionary:
	for g in state.get("gates",[]):
		if g.id == id: return g
	return {}

func capital_for(owner: String) -> String:
	for p in state.planets:
		if p.home == owner: return str(p.id)
	return ""

func owned(owner: String = "") -> Array:
	var result: Array = []
	for p in state.planets:
		if p.owner == (owner if owner != "" else str(state.player)): result.append(p)
	return result

func stationed(id: String, owner: String = "") -> Array:
	var result: Array = []
	for f in state.fleets:
		if f.station == id and (owner == "" or f.owner == owner): result.append(f)
	return result

func ships(id: String) -> int:
	var p: Dictionary = planet(id)
	var count: int = int(p.get("militia",0))
	for f in stationed(id): count += int(f.units)
	return count

func position_of(item: Dictionary) -> Vector2:
	return Vector2(float(item.get("x",0)),float(item.get("y",0)))

func spawn_fleet(owner: String, station: String, units: int, kind: String = "突击", title: String = "") -> Dictionary:
	var p: Dictionary = planet(station)
	var id: String = "f%d" % int(state.next_fleet)
	state.next_fleet = int(state.next_fleet) + 1
	var f: Dictionary = {"id":id,"name":title if title != "" else "%s编队 %s" % [kind,id],"owner":owner,"station":station,"x":float(p.get("x",500)),"y":float(p.get("y",420)),"units":units,"type":kind,"level":1,"modules":[],"icon":"楔形","color":COLORS[owner],"support":0,"support_until":0,"support_target":"","revealed":0,"destination":{},"state":"驻守" if station != "" else "太空","upgrades":{},"cargo":{},"damage":0}
	state.fleets.append(f)
	return f

func adjacency(a: String, b: String) -> Dictionary:
	for g in state.gates:
		if (g.a == a and g.b == b) or (g.a == b and g.b == a): return g
	return {}

func neighbors(id: String) -> Array[String]:
	var result: Array[String] = []
	for g in state.gates:
		if g.a == id: result.append(str(g.b))
		elif g.b == id: result.append(str(g.a))
	return result

func friendly(a: String, b: String) -> bool:
	if a == b: return true
	if a != state.player and b != state.player: return false
	var other: String = b if a == state.player else a
	return int(state.pacts.get(other,{}).get("alliance",0)) >= int(state.turn)

func protected_from(owner: String) -> bool:
	var pact: Dictionary = state.pacts.get(owner,{})
	return friendly(str(state.player),owner) or int(pact.get("ceasefire",0)) >= int(state.turn)

func available_source(target: String) -> Dictionary:
	var best: Dictionary = {}
	for f in state.fleets:
		if f.owner != state.player or f.station == "": continue
		var g: Dictionary = adjacency(str(f.station),target)
		if not g.is_empty() and not g.broken and int(g.blocked) < int(state.turn):
			if best.is_empty() or int(f.units) > int(best.units): best = f
	return best

func power(f: Dictionary, attacking: bool = true) -> int:
	var value: int = int(f.units) + int(f.level) - 1
	value += int(f.get("upgrades",{}).get("attack" if attacking else "defense",0))
	if attacking and f.type == "突击": value += 2
	if not attacking and f.type == "守卫": value += 2
	if f.type == "运输": value = maxi(1,value - 2)
	if f.type == "侦察": value = maxi(1,value - 1)
	if "主武器" in f.modules and attacking: value += 2
	if "护盾" in f.modules and not attacking: value += 2
	if "帝国矩阵" in f.modules and not attacking: value += 2
	if int(f.support_until) >= int(state.turn): value += int(f.support)
	return value

func defense(p: Dictionary) -> int:
	var value: int = int(p.militia) + int(p.defense)
	for f in stationed(str(p.id)): value += power(f,false)
	if p.owner == "帝国": value += 1
	if int(p.siege) >= int(state.turn): value = maxi(0,value - 2)
	return value

func movement_quote(f: Dictionary, target: Dictionary, preview: bool = false) -> Dictionary:
	if f.is_empty(): return {"valid":false,"reason":"先选择己方舰队。"}
	var distance: float = position_of(f).distance_to(position_of(target))
	var connected: Dictionary = adjacency(str(f.station),str(target.get("id","")))
	if preview and not connected.is_empty(): connected = state.fog.gates.get(connected.id,{"broken":false,"blocked":0})
	if not connected.is_empty() and (connected.broken or int(connected.blocked) >= int(state.turn)):
		return {"valid":false,"reason":"这条星门已被封锁或破坏，请修复或等待解除。"}
	var use_gate: bool = not connected.is_empty()
	var remote: bool = distance > 280 and not use_gate
	var fuel_cost: int = 1 if use_gate else maxi(2,int(ceil(distance / 100.0)))
	fuel_cost = maxi(1,fuel_cost - int(f.get("upgrades",{}).get("speed",0)))
	if f.type in ["劫掠","侦察"] or "引擎" in f.modules or "混沌跃迁" in f.modules: fuel_cost = maxi(1,fuel_cost - 2)
	if f.owner == "帝国" and remote: fuel_cost += 1
	if use_gate and int(f.get("upgrades",{}).get("gate",0)) > 0: fuel_cost = 0
	var territory: String = str(target.get("owner","无主"))
	if not target.has("capital") and not target.has("units"):
		territory = space_owner(position_of(target),preview)
	var hostile: bool = territory not in [f.owner,"无主"] and not friendly(str(f.owner),territory)
	return {"valid":true,"reason":"", "ap":2 if remote and f.type not in ["劫掠","侦察"] else 1,"fuel":fuel_cost,"distance":int(distance),"risk":"外星未知区域" if territory == "外星" else ("敌方控制区" if hostile else ("额外燃料" if remote else "安全航线")),"remote":remote,"gate":use_gate,"eta":"立即结算","hostile":hostile}

func space_owner(point: Vector2, preview: bool = false) -> String:
	var nearest: float = 110.0
	var owner: String = "无主"
	for p in state.fog.planets.values() if preview else state.planets:
		var distance: float = point.distance_to(position_of(p))
		if distance < nearest:
			nearest = distance
			owner = str(p.owner)
	return owner

func _cost(ap: int, costs: Dictionary = {}) -> String:
	if state.phase != "player": return "战役已结束，请重开或读取存档。"
	if int(state.ap) < ap: return "剩余行动不足，需要 %d 次行动。" % ap
	for key in costs:
		if int(res().get(key,0)) < int(costs[key]): return "%s不足，需要 %d。" % [RESOURCE_NAMES.get(key,key),int(costs[key])]
	return ""

func _pay(ap: int, costs: Dictionary = {}) -> void:
	state.ap = int(state.ap) - ap
	for key in costs: res()[key] = int(res()[key]) - int(costs[key])

func fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func done(message: String) -> Dictionary:
	update_gates()
	log_event(message)
	check_victory()
	Systems.refresh(self)
	state.rng_state = rng.state
	return {"ok":true,"message":message}

func log_event(message: String) -> void:
	state.log.push_front("第 %d 轮 · %s" % [int(state.turn),message])
	if state.log.size() > 100: state.log.resize(100)

func act(action: String, args: Dictionary = {}) -> Dictionary:
	if state.is_empty(): return fail("请先开启星门。")
	var before: Dictionary = observer_frame()
	var result: Dictionary = _act(action,args)
	if result.ok: result.visuals = Systems.record(self,before)
	return result

func _act(action: String, args: Dictionary = {}) -> Dictionary:
	if state.is_empty(): return fail("请先开启星门。")
	if state.phase != "player": return fail("战役已经结束，请重开或读取存档。")
	var p: Dictionary = planet(str(args.get("planet","")))
	var f: Dictionary = fleet(str(args.get("fleet","")))
	if action in ["expand","reinforce","buy","policy","build","skill"] and p.is_empty(): return fail("请先在星图选择星球。")
	if action in ["move","attack","split","upgrade","configure","merge","support","exchange","encounter","cargo"] and (f.is_empty() or f.owner != state.player): return fail("请先选择己方舰队。")
	match action:
		"scan": return Systems.scan(self,f)
		"story": return Systems.story_choice(self,int(args.get("choice",-1)))
		"expand": return _expand(p)
		"reinforce":
			if p.owner != state.player: return fail("只能增援己方星球。")
			var reason: String = _cost(1)
			if reason != "": return fail(reason)
			_pay(1)
			var list: Array = stationed(str(p.id),str(state.player))
			if list.is_empty(): spawn_fleet(str(state.player),str(p.id),1,"守卫")
			else: list[0].units = int(list[0].units) + 1
			p.affinity = mini(100,int(p.affinity) + 3)
			return done("%s获得 1 支增援舰队。" % p.name)
		"buy": return _buy(p,str(args.get("type","突击")))
		"move": return _move(f,args)
		"attack": return _attack(f,p,str(args.get("method","直接突袭")))
		"split": return _split(f,int(args.get("units",1)))
		"merge", "support", "exchange": return _friendly_encounter(action,f,fleet(str(args.get("target",""))))
		"encounter": return _enemy_encounter(f,fleet(str(args.get("target",""))),str(args.get("choice","立即开战")))
		"upgrade":
			if int(f.level) >= 5: return fail("舰队已达到最高等级 5。")
			var direction: String = str(args.get("direction","attack"))
			if direction not in UPGRADES: return fail("无效升级方向。")
			var reason: String = _cost(0,{"credits":6,"materials":3})
			if reason != "": return fail(reason)
			_pay(0,{"credits":6,"materials":3})
			f.level = int(f.level) + 1
			if not f.has("upgrades"): f.upgrades = {}
			f.upgrades[direction] = int(f.upgrades.get(direction,0)) + 1
			return done("%s升级至 LV.%d，%s +1。" % [f.name,int(f.level),UPGRADES[direction]])
		"configure": return _configure(f,args)
		"policy": return _policy(p,str(args.get("policy","直接统治")))
		"build":
			if p.owner != state.player: return fail("只能建设己方星球。")
			var building: String = str(args.get("building","护盾阵列"))
			if building not in ["护盾阵列","资源基地"]: return fail("无效设施类型。")
			if p.building == building: return fail("该星球已经拥有这项设施。")
			var reason: String = _cost(1,{"materials":4})
			if reason != "": return fail(reason)
			_pay(1,{"materials":4})
			if p.building == "护盾阵列": p.defense = maxi(0,int(p.defense)-2)
			if p.building == "资源基地": p.income = maxi(0,int(p.income)-2)
			p.building = building
			p.defense = int(p.defense) + (2 if p.building == "护盾阵列" else 0)
			p.income = int(p.income) + (2 if p.building == "资源基地" else 0)
			return done("%s完成%s。" % [p.name,p.building])
		"gate": return _gate_action(gate(str(args.get("gate",""))),str(args.get("choice","占领")),f)
		"diplomacy": return _diplomacy(str(args.get("faction","")),str(args.get("choice","结盟")))
		"skill": return _skill(p,false)
		"ultimate": return _skill({},true)
		"explore": return _explore(f)
		"cargo": return _cargo(f,str(args.get("resource","materials")),int(args.get("amount",1)),bool(args.get("unload",false)))
	return fail("未知指令。")

func _expand(p: Dictionary) -> Dictionary:
	if p.owner != "无主": return fail("扩张只能选择相邻的灰色无主星球。")
	var source: Dictionary = available_source(str(p.id))
	if source.is_empty(): return fail("没有通过开放星门相连的己方驻守舰队。")
	var price: int = 1 if state.player == "联盟" or source.type == "开拓" else 2
	var reason: String = _cost(1,{"credits":price})
	if reason != "": return fail(reason)
	_pay(1,{"credits":price})
	p.owner = state.player
	p.militia = 0
	p.affinity = 40 if source.type == "开拓" else 25
	spawn_fleet(str(state.player),str(p.id),1,"开拓")
	return done("扩张成功：%s加入%s，星门已接管。" % [p.name,state.player])

func _buy(p: Dictionary, kind: String) -> Dictionary:
	if p.owner != state.player: return fail("先在地图选择己方星球，再购买舰队。")
	if kind not in TYPES: return fail("无效舰队类型。")
	var count: int = 0
	for f in state.fleets:
		if f.owner == state.player: count += 1
	if count >= (12 if state.player == "帝国" else 20): return fail("已经达到阵营舰队编制上限。可先合并舰队。")
	var reason: String = _cost(0,{"credits":8,"materials":4})
	if reason != "": return fail(reason)
	_pay(0,{"credits":8,"materials":4})
	spawn_fleet(str(state.player),str(p.id),3 if state.player == "联盟" else 2,kind)
	return done("%s在%s完成建造。" % [kind,p.name])

func _move(f: Dictionary, args: Dictionary) -> Dictionary:
	var target: Dictionary = planet(str(args.get("planet","")))
	var target_fleet: Dictionary = fleet(str(args.get("target","")))
	if args.has("planet") and target.is_empty(): return fail("目标星球已不存在，请重新选择。")
	if args.has("target") and target_fleet.is_empty(): return fail("目标舰队已不存在，请重新选择。")
	if not target_fleet.is_empty(): target = target_fleet
	if target.is_empty(): target = {"x":clampf(float(args.get("x",500)),25,975),"y":clampf(float(args.get("y",400)),30,790),"owner":"无主"}
	if f.station != "" and target.get("id","") == f.station: return fail("这支舰队已经驻守在该星球。")
	if target.get("owner","无主") not in [state.player,"无主"]:
		var permission: bool = friendly(str(state.player),str(target.owner)) or int(state.pacts.get(target.owner,{}).get("access",0)) >= int(state.turn)
		if not permission: return fail("目标属于敌方，请选择进攻或先取得通行权。")
	var quote: Dictionary = movement_quote(f,target)
	if not quote.valid: return fail(str(quote.reason))
	var reason: String = _cost(int(quote.ap),{"fuel":int(quote.fuel)})
	if reason != "": return fail(reason)
	_pay(int(quote.ap),{"fuel":int(quote.fuel)})
	f.x = float(target.x)
	f.y = float(target.y)
	f.station = str(target.get("id","")) if target.has("capital") and target.owner == state.player else ""
	if f.station == "" and target.has("id"): f.x = clampf(float(f.x) + 35,25,975)
	f.state = "驻守" if f.station != "" else "太空"
	f.destination = target.duplicate(true) if not target.has("modules") else {"x":target.x,"y":target.y}
	if f.station == "" and bool(quote.get("hostile",false)) and "隐匿" not in f.modules and rng.randf() < 0.2:
		f.units = int(f.units)-1
		f.damage = int(f.get("damage",0))+1
		if int(f.units) <= 0:
			state.fleets.erase(f)
			return done("进入敌方控制区遭到拦截，舰队被摧毁。")
		return done("舰队抵达敌方控制区，途中受到拦截损失 1 单位。")
	return done("%s完成%s；消耗 %d 行动 / %d 燃料。" % [f.name,"星门跃迁" if quote.gate else "太空移动",int(quote.ap),int(quote.fuel)])

func _attack(f: Dictionary, p: Dictionary, method: String) -> Dictionary:
	if method not in ["直接突袭","围困","星门封锁","轨道轰炸","策反行动","诱敌出击"]: return fail("无效进攻方式。")
	if p.is_empty(): return fail("请选择目标星球。")
	if p.owner == state.player: return fail("不能攻击己方星球。")
	if protected_from(str(p.owner)): return fail("目标处于联盟或停战协议中；先在外交频道取消协议。")
	if int(p.locked) >= int(state.turn): return fail("星门锁域生效，目标本轮无法被攻击。")
	var q: Dictionary = movement_quote(f,p)
	if not q.valid: return fail(str(q.reason))
	if q.remote and f.type not in ["突击","劫掠","侦察"] and int(f.level) < 2 and int(f.get("upgrades",{}).get("range",0)) == 0: return fail("远程攻击需要突击 / 劫掠 / 侦察舰队，或至少 LV.2。")
	var costs: Dictionary = {"fuel":int(q.fuel)}
	if q.remote: costs["intel"] = maxi(0,2-int(f.get("upgrades",{}).get("range",0)))
	if method == "策反行动": costs["intel"] = 6 if state.player == "联盟" else 9
	if method == "轨道轰炸": costs["materials"] = 2
	var reason: String = _cost(int(q.ap),costs)
	if reason != "": return fail(reason)
	_pay(int(q.ap),costs)
	# Committing an attack establishes local contact, including a failed assault.
	state.fog.scans.append({"x":p.x,"y":p.y,"radius":60,"until":int(state.turn)})
	match method:
		"围困":
			p.siege = int(state.turn) + 2
			p.status = "围困"
			return done("%s被围困两轮，防御 -2、产出减半。" % p.name)
		"星门封锁":
			for g in state.gates:
				if g.a == p.id or g.b == p.id: g.blocked = int(state.turn) + 1
			p.status = "封锁"
			return done("%s周边星门被封锁。" % p.name)
		"轨道轰炸":
			p.defense = maxi(0,int(p.defense) - 2)
			if p.building == "资源基地": p.income = maxi(0,int(p.income)-2)
			p.building = "无"
			p.affinity = maxi(-100,int(p.affinity) - 25)
			res().reputation = maxi(0,int(res().reputation) - 8)
			for defender in stationed(str(p.id)): defender.units = maxi(1,int(defender.units) - 1)
			_change_relation(str(p.owner),-20)
			return done("轨道轰炸摧毁建筑并削弱驻军；当地好感 -25，声望 -8。")
		"诱敌出击":
			var defenders: Array = stationed(str(p.id))
			if not defenders.is_empty():
				defenders[0].station = ""
				defenders[0].state = "太空"
				defenders[0].x = float(p.x) + 40
			return done("诱敌讯号发出，首支驻守舰队离开星球。")
		"策反行动":
			var chance: float = 0.70 if state.player == "联盟" else 0.4
			if p.owner == "帝国": chance -= 0.25
			chance += float(p.affinity) / 400.0
			if rng.randf() > chance: return done("策反失败，情报已消耗，目标提高了警戒。")
	var attack_value: int = power(f)
	var defense_value: int = defense(p)
	var won: bool = method == "策反行动" or attack_value > defense_value or (attack_value == defense_value and state.player == "混沌")
	var previous: String = str(p.owner)
	_change_relation(previous,-15)
	if won:
		for defender in stationed(str(p.id)).duplicate():
			if defender.get("core",false): state.cores_destroyed = int(state.cores_destroyed) + 1
			state.fleets.erase(defender)
		p.owner = state.player
		p.militia = 0
		p.affinity = 10
		p.siege = 0
		p.status = "待治理"
		var losses: int = mini(int(f.units)-1,maxi(1,defense_value / 3))
		f.units = int(f.units) - losses
		f.damage = int(f.get("damage",0)) + losses
		f.station = p.id
		f.state = "驻守"
		f.x = p.x
		f.y = p.y
		res().credits = int(res().credits) + 4
		if previous == "外星": res().reputation = int(res().reputation) + 6
		return done("%s占领%s（进攻 %d / 防守 %d）。请选择治理方式。" % [f.name,p.name,attack_value,defense_value])
	var losses: int = maxi(1,defense_value / 2)
	f.units = int(f.units) - losses
	f.damage = int(f.get("damage",0)) + losses
	if int(f.units) <= 0:
		state.fleets.erase(f)
		return done("进攻失败（%d / %d），舰队被摧毁。" % [attack_value,defense_value])
	return done("进攻失败（%d / %d），幸存舰队撤回原位。" % [attack_value,defense_value])

func _split(f: Dictionary, count: int) -> Dictionary:
	if count < 1 or count >= int(f.units): return fail("拆分后每支舰队至少保留 1 个单位。")
	var reason: String = _cost(1)
	if reason != "": return fail(reason)
	_pay(1)
	f.units = int(f.units) - count
	var child: Dictionary = spawn_fleet(str(f.owner),str(f.station),count,str(f.type),str(f.name) + " · 分队")
	child.x = float(f.x) + (30 if f.station == "" else 0)
	child.y = f.y
	child.level = f.level
	child.modules = f.modules.duplicate()
	child.upgrades = f.get("upgrades",{}).duplicate(true)
	return done("舰队拆分完成：%d + %d，两个编制可独立行动。" % [int(f.units),count])

func _friendly_encounter(action: String, a: Dictionary, b: Dictionary) -> Dictionary:
	if b.is_empty() or a.id == b.id or a.owner != b.owner: return fail("请选择另一支己方舰队；盟友编制不能合并。")
	if position_of(a).distance_to(position_of(b)) > 100: return fail("舰队相距太远，请先移动到友舰附近。")
	if action == "exchange" and (b.modules.size() > mini(5,int(a.level) + 1) or a.modules.size() > mini(5,int(b.level) + 1)): return fail("模块交换取消：等级槽位不足。")
	if action == "support" and int(a.support_until) >= int(state.turn) and a.support_target != "": return fail("该舰队的支援已在进行，不能重复支援。")
	var costs: Dictionary = {"materials":2} if action == "exchange" else {}
	var reason: String = _cost(1,costs)
	if reason != "": return fail(reason)
	_pay(1,costs)
	if action == "merge":
		a.units = int(a.units) + int(b.units)
		a.damage = int(a.get("damage",0)) + int(b.get("damage",0))
		if not a.has("cargo"): a.cargo = {}
		for key in b.get("cargo",{}): a.cargo[key] = int(a.cargo.get(key,0)) + int(b.cargo[key])
		if a.type != b.type: a.name = str(a.name) + " · 混合舰队"
		state.fleets.erase(b)
		return done("舰队合并；保留主舰队类型，共 %d 个单位。" % int(a.units))
	if action == "exchange":
		var modules: Array = a.modules.duplicate()
		a.modules = b.modules.duplicate()
		b.modules = modules
		return done("双方模块已交换。")
	b.support = maxi(1,int(a.units) / 2)
	b.support_until = int(state.turn) + 1
	a.support_target = b.id
	a.support_until = int(state.turn) + 1
	return done("友军获得两轮临时战力 +%d，支援舰保留独立编制。" % int(b.support))

func _enemy_encounter(a: Dictionary, b: Dictionary, choice: String) -> Dictionary:
	if choice not in ["立即开战","观察和侦察","避让","威慑","暂时停火"]: return fail("无效接触指令。")
	if b.is_empty() or a.id == b.id: return fail("目标舰队不存在。")
	if not Systems.fleet_live(self,b): return fail("目标已离开视野，请先侦察最后位置。")
	if position_of(a).distance_to(position_of(b)) > 180: return fail("请先接近目标舰队，距离须小于 180。")
	if a.owner == b.owner: return fail("这是己方舰队。")
	if choice == "立即开战" and protected_from(str(b.owner)): return fail("受到外交协议限制；请先取消协议。")
	var costs: Dictionary = {"intel":2} if choice == "观察和侦察" else ({"fuel":3} if choice == "避让" else {})
	var reason: String = _cost(1,costs)
	if reason != "": return fail(reason)
	_pay(1,costs)
	b.revealed = maxi(int(b.revealed),int(state.turn))
	match choice:
		"观察和侦察":
			b.revealed = int(state.turn) + 2
			a.revealed = int(state.turn) + 1
			return done("侦察：%s · %s · LV.%d · %d 单位。己方信号也已暴露。" % [b.name,b.type,int(b.level),int(b.units)])
		"避让":
			var chance: float = 0.25 - float(a.get("upgrades",{}).get("retreat",0))*0.15
			if "隐匿" in a.modules: chance -= 0.25
			if b.type == "守卫" and rng.randf() < chance: return done("遭到守卫拦截，避让失败。")
			a.station = ""
			a.state = "太空"
			a.x = clampf(float(a.x) - 100,25,975)
			a.y = clampf(float(a.y) + 70,30,790)
			return done("舰队成功避让，脱离接触区域。")
		"威慑":
			if power(a) + int(res().reputation) / 10 + int(a.get("upgrades",{}).get("influence",0))*2 <= power(b): return done("威慑失败：声望与舰队差距不足。")
			b.x = clampf(float(b.x) + 100,25,975)
			b.station = ""
			b.state = "太空"
			return done("敌方受威慑撤退。")
		"暂时停火":
			if b.owner == "外星": return done("外星远征军拒绝了停火请求。")
			state.pacts[b.owner].ceasefire = int(state.turn) + 1
			return done("双方建立两轮临时停火，可暂时共存。")
	var won: bool = power(a) > power(b,false) or (power(a) == power(b,false) and a.owner == "混沌")
	_change_relation(str(b.owner),-12)
	if won:
		var losses: int = mini(int(a.units)-1,maxi(1,int(b.units)/3))
		a.units = int(a.units) - losses
		a.damage = int(a.get("damage",0)) + losses
		a.x = b.x
		a.y = b.y
		a.station = ""
		a.state = "太空"
		if b.type == "运输": res().credits = int(res().credits) + 8
		for key in b.get("cargo",{}): res()[key] = int(res()[key]) + int(b.cargo[key])
		if b.get("core",false): state.cores_destroyed = int(state.cores_destroyed) + 1
		state.fleets.erase(b)
		res().reputation = int(res().reputation) + 4
		return done("舰队战胜利，敌舰被消灭，当前位置已控制。")
	a.units = int(a.units) - maxi(1,int(b.units) / 2)
	a.damage = int(a.get("damage",0)) + maxi(1,int(b.units)/2)
	if int(a.units) <= 0: state.fleets.erase(a)
	else:
		a.x = clampf(float(a.x) - 70,25,975)
		a.station = ""
		a.state = "太空"
	return done("舰队战失利，残部撤退或被摧毁。")

func _configure(f: Dictionary, args: Dictionary) -> Dictionary:
	var mods: Array = args.get("modules",[])
	if mods.size() > mini(5,int(f.level) + 1): return fail("模块槽不足；当前最多 %d 个，升级可增加槽位。" % mini(5,int(f.level) + 1))
	var seen: Array = []
	for module in mods:
		if module not in MODULES or module in seen: return fail("包含无效或重复模块。")
		seen.append(module)
		if module in ["隐匿","帝国矩阵","联盟信标","混沌跃迁"] and int(f.level) < 2: return fail("高级模块需要 LV.2。")
		if module in ["帝国矩阵","联盟信标","混沌跃迁"] and not str(module).begins_with(str(state.player)): return fail("该专属模块不属于你的阵营。")
	var kind: String = str(args.get("type",f.type))
	if kind not in TYPES: return fail("舰队类型无效。")
	if not Color.html_is_valid(str(args.get("color",f.color))): return fail("涂装颜色无效。")
	var reason: String = _cost(0,{"materials":2 + mods.size(),"credits":2})
	if reason != "": return fail(reason)
	_pay(0,{"materials":2 + mods.size(),"credits":2})
	f.name = str(args.get("name",f.name)).strip_edges().left(24)
	if f.name == "": f.name = "无名舰队"
	f.type = kind
	f.modules = mods.duplicate()
	f.color = str(args.get("color",f.color))
	f.icon = str(args.get("icon",f.icon))
	return done("舰队配置已保存；类型、涂装和模块立即生效。")

func _policy(p: Dictionary, policy: String) -> Dictionary:
	if policy not in ["直接统治","自治管理","保护协议","掠夺开发","重建星球"]: return fail("无效治理政策。")
	if p.owner != state.player: return fail("只能治理己方星球。")
	if int(p.get("policy_turn",0)) == int(state.turn): return fail("该星球本轮已调整治理政策。")
	var costs: Dictionary = {"materials":4} if policy == "重建星球" else ({"credits":2} if policy == "保护协议" else {})
	var reason: String = _cost(0,costs)
	if reason != "": return fail(reason)
	if p.policy == policy and p.status != "待治理": return fail("该星球已经执行这项政策。")
	_pay(0,costs)
	p.policy_turn = state.turn
	p.policy = policy
	p.status = "稳定"
	match policy:
		"直接统治": p.affinity = maxi(-100,int(p.affinity) - 10)
		"自治管理": p.affinity = mini(100,int(p.affinity) + 15)
		"保护协议": p.affinity = mini(100,int(p.affinity) + 20)
		"掠夺开发":
			res().credits = int(res().credits) + 10
			p.affinity = maxi(-100,int(p.affinity) - 45)
			res().reputation = maxi(0,int(res().reputation) - 8)
		"重建星球":
			p.affinity = mini(100,int(p.affinity) + 25)
			p.income = int(p.income) + 1
	return done("%s执行%s，当地好感 %d。" % [p.name,policy,int(p.affinity)])

func _gate_action(g: Dictionary, choice: String, f: Dictionary) -> Dictionary:
	if choice not in ["占领","封锁","破坏","修复"]: return fail("无效星门指令。")
	if g.is_empty(): return fail("请选择星门线路中间的菱形节点。")
	var accessible: bool = planet(str(g.a)).owner == state.player or planet(str(g.b)).owner == state.player
	if not f.is_empty() and f.owner == state.player:
		var mid: Vector2 = (position_of(planet(str(g.a))) + position_of(planet(str(g.b)))) / 2
		accessible = accessible or position_of(f).distance_to(mid) < 160
	if not accessible: return fail("需要邻接己方领地或附近的己方舰队。")
	var costs: Dictionary = {"materials":3} if choice == "修复" else {}
	var reason: String = _cost(1,costs)
	if reason != "": return fail(reason)
	_pay(1,costs)
	match choice:
		"占领": g.owner = state.player
		"封锁": g.blocked = int(state.turn) + 1
		"破坏": g.broken = true
		"修复":
			g.broken = false
			g.blocked = 0
	return done("星门 %s完成%s。" % [g.id,choice])

func _skill(p: Dictionary, ultimate: bool) -> Dictionary:
	if ultimate:
		if int(state.turn) < 4: return fail("第 4 轮解锁。")
		if state.ultimate: return fail("本局终极技能已经使用。")
		state.ultimate = true
		for home in owned():
			var list: Array = stationed(str(home.id),str(state.player))
			if list.is_empty(): spawn_fleet(str(state.player),str(home.id),1,"守卫")
			else: list[0].units = int(list[0].units) + 1
		state.ap = int(state.ap) + 1
		return done("银河重整：所有己方星球舰队 +1，额外获得 1 次行动。")
	if int(state.skill_turn) == int(state.turn): return fail("本轮技能已经使用。")
	if p.owner != state.player: return fail("请选择己方星球。")
	state.skill_turn = state.turn
	match str(state.player):
		"帝国":
			p.locked = state.turn
			return done("星门锁域：%s本轮无法被敌人攻击。" % p.name)
		"联盟":
			res().credits = int(res().credits) + 4
			p.affinity = mini(100,int(p.affinity) + 8)
			return done("自由贸易：获得 4 信用点，当地好感 +8。")
		_:
			res().intel = int(res().intel) + 3
			res().fuel = int(res().fuel) + 3
			return done("暗网补给：获得 3 情报与 3 燃料。")

func _change_relation(other: String, amount: int) -> void:
	if other in FACTIONS and other != state.player:
		state.relations[other] = clampi(int(state.relations[other]) + amount,-100,100)

func _diplomacy(other: String, choice: String) -> Dictionary:
	if choice not in ["结盟","提出停战","赠送资源","资源交易","交换情报","请求援军","开放星门","保护协议","共同抗敌","交换领地","取消协议","宣布背叛"]: return fail("无效外交指令。")
	if other not in FACTIONS or other == state.player or other == "外星": return fail("外星远征军不接受普通外交协议。")
	if int(state.diplomacy_turn) == int(state.turn): return fail("每轮只能开展一次外交行动。")
	var opinion: int = int(state.relations[other])
	var costs: Dictionary = {}
	match choice:
		"结盟":
			var threshold: int = 15 if other == "混沌" else (0 if other == "帝国" else -25)
			if opinion < threshold: return fail("%s指挥官要求好感至少 %d 才接受结盟。" % [other,threshold])
			costs = {"credits":4}
		"赠送资源": costs = {"credits":4}
		"资源交易":
			if opinion < (-40 if other == "联盟" else -25): return fail("敌对势力拒绝交易。")
			costs = {"credits":4}
		"交换情报": costs = {"materials":2}
		"请求援军":
			if not friendly(str(state.player),other) and opinion < 25: return fail("请求援军需要盟友或至少 25 好感。")
			costs = {"credits":3}
		"开放星门": costs = {"credits":2}
		"保护协议": costs = {"credits":3}
		"共同抗敌": costs = {"intel":2}
		"交换领地":
			if opinion < 25: return fail("领地交换需要至少 25 好感。")
			var theirs: Array = owned(other).filter(func(item: Dictionary) -> bool: return not item.capital)
			var ours: Array = owned().filter(func(item: Dictionary) -> bool: return not item.capital)
			if theirs.is_empty() or ours.is_empty(): return fail("双方都需要至少一颗非首都星球。")
	var reason: String = _cost(0,costs)
	if reason != "": return fail(reason)
	_pay(0,costs)
	state.diplomacy_turn = state.turn
	var pact: Dictionary = state.pacts[other]
	match choice:
		"结盟":
			pact.alliance = int(state.turn) + 3
			pact.access = int(state.turn) + 3
			_change_relation(other,25)
		"提出停战": pact.ceasefire = int(state.turn) + 2
		"赠送资源": _change_relation(other,20)
		"资源交易":
			res().materials = int(res().materials) + 4
			_change_relation(other,5)
		"交换情报":
			res().intel = int(res().intel) + 4
			Systems.share_intel(self,other)
		"请求援军":
			var homes: Array = owned()
			if not homes.is_empty(): spawn_fleet(str(state.player),str(homes[0].id),2,"守卫","%s援军" % other)
			_change_relation(other,5)
		"开放星门": pact.access = int(state.turn) + 3
		"保护协议":
			pact.protection = int(state.turn) + 3
			_change_relation(other,15)
		"共同抗敌":
			pact.joint = int(state.turn) + 3
			pact.ceasefire = int(state.turn) + 3
			_change_relation(other,20)
			res().reputation = int(res().reputation) + 5
		"交换领地":
			var theirs: Array = owned(other).filter(func(item: Dictionary) -> bool: return not item.capital)
			var ours: Array = owned().filter(func(item: Dictionary) -> bool: return not item.capital)
			var a: Dictionary = ours[0]
			var b: Dictionary = theirs[0]
			for ship in stationed(str(a.id)): ship.owner = other
			for ship in stationed(str(b.id)): ship.owner = state.player
			a.owner = other
			b.owner = state.player
		"宣布背叛", "取消协议":
			for key in pact: pact[key] = 0
			_change_relation(other,-40 if choice == "宣布背叛" else -10)
			if choice == "宣布背叛": res().reputation = maxi(0,int(res().reputation) - 10)
	return done("与%s：%s。当前好感 %d。" % [other,choice,int(state.relations[other])])

func _explore(f: Dictionary) -> Dictionary:
	if f.is_empty() or f.owner != state.player or f.station != "": return fail("请选择太空中的己方舰队。")
	var region: Vector2 = Vector2(500,420)
	var scan_range: int = (180 if f.type == "侦察" else 100) + int(f.get("upgrades",{}).get("sensor",0))*60
	if position_of(f).distance_to(region) > scan_range: return fail("请先驶入星图中央的未知遗迹区域。")
	if state.get("explored_turn",0) == state.turn: return fail("本轮已完成区域调查。")
	var reason: String = _cost(1,{"fuel":2})
	if reason != "": return fail(reason)
	_pay(1,{"fuel":2})
	state.explored_turn = state.turn
	res().materials = int(res().materials) + (6 if "运输" in f.modules else 4)
	res().intel = int(res().intel) + (4 if "侦察" in f.modules or f.type == "侦察" else 2)
	res().reputation = int(res().reputation) + 2
	return done("未知遗迹调查完成，获得材料、情报与声望。")

func _cargo(f: Dictionary, resource: String, amount: int, unload: bool) -> Dictionary:
	if resource not in ["credits","materials","intel","fuel"] or amount < 1: return fail("请选择有效物资和数量。")
	if f.type != "运输" and "运输" not in f.modules: return fail("需要运输舰队或运输模块。")
	if not f.has("cargo"): f.cargo = {}
	if unload:
		if f.station == "" or planet(str(f.station)).owner != state.player: return fail("请在己方星球驻守后卸载补给。")
		if int(f.cargo.get(resource,0)) < amount: return fail("舰队携带的物资不足。")
		f.cargo[resource] = int(f.cargo[resource]) - amount
		res()[resource] = int(res()[resource]) + amount
		planet(str(f.station)).affinity = mini(100,int(planet(str(f.station)).affinity)+2)
		return done("%s向驻守星球交付 %d %s。" % [f.name,amount,RESOURCE_NAMES[resource]])
	if f.station == "": return fail("装载补给需要先驻守己方星球。")
	var loaded: int = 0
	for key in f.cargo: loaded += int(f.cargo[key])
	var capacity: int = int(f.units)*4 + int(f.get("upgrades",{}).get("cargo",0))*8
	if loaded + amount > capacity: return fail("运输舱位不足：%d / %d。" % [loaded,capacity])
	var reason: String = _cost(0,{resource:amount})
	if reason != "": return fail(reason)
	_pay(0,{resource:amount})
	f.cargo[resource] = int(f.cargo.get(resource,0)) + amount
	return done("装载 %d %s；被摧毁时会损失舰载物资。" % [amount,RESOURCE_NAMES[resource]])

func update_gates() -> void:
	for g in state.gates:
		var a: Dictionary = planet(str(g.a))
		var b: Dictionary = planet(str(g.b))
		if a.owner == b.owner and a.owner != "无主": g.owner = a.owner

func gate_count(owner: String) -> int:
	var count: int = 0
	for g in state.gates:
		if g.owner == owner and not g.broken: count += 1
	return count

func score(owner: String) -> int:
	var result: int = owned(owner).size() * 10 + gate_count(owner) * 2
	for p in owned(owner): result += 15 if p.capital else 0
	for f in state.fleets:
		if f.owner == owner: result += int(f.units)
	result += int(res(owner).reputation) / 5
	return result

func diplomacy_score() -> int:
	var points: int = int(res().reputation)
	for other in FACTIONS:
		if other in [state.player,"外星"]: continue
		points += maxi(0,int(state.relations[other]))
		for key in state.pacts[other]:
			if int(state.pacts[other][key]) >= int(state.turn): points += 10
	return points

func end_turn() -> Dictionary:
	if state.phase != "player": return fail("战役已经结束。")
	Systems.refresh(self)
	state.replay = {"turn":int(state.turn),"initial":observer_frame(),"events":[]}
	var before_income: Dictionary = observer_frame()
	for f in FACTIONS:
		for p in owned(f):
			var income: int = int(p.income)
			if int(p.siege) >= int(state.turn) or p.policy == "自治管理": income = maxi(1,income / 2)
			if p.depleted: income = 0
			res(f).credits = int(res(f).credits) + income
			res(f).materials = int(res(f).materials) + 1
			res(f).fuel = int(res(f).fuel) + 1
			res(f).intel = int(res(f).intel) + (1 if p.type == "遗迹" else 0)
			if p.policy == "保护协议":
				res(f).credits = maxi(0,int(res(f).credits) - 1)
				p.affinity = mini(100,int(p.affinity) + 2)
			if int(p.affinity) < -30 and rng.randf() < 0.25:
				p.owner = "无主"
				p.militia = 2
				p.status = "叛乱"
				for ship in stationed(str(p.id)):
					ship.station = ""
					ship.state = "太空"
					ship.x = float(p.x) + 40
				log_event("%s爆发叛乱，驻军撤入太空。" % p.name)
		if int(state.mode) == 2: res(f).credits = int(res(f).credits) + gate_count(f)
	_append_replay(before_income)
	for other in FACTIONS:
		if other != state.player and other != "外星": _ai_turn(other)
	_alien_turn()
	var before_events: Dictionary = observer_frame()
	state.turn = int(state.turn) + 1
	preload("res://frontier_systems.gd").tick(self)
	state.ap = 2
	for f in state.fleets:
		if int(f.support_until) < int(state.turn):
			f.support = 0
			f.support_target = ""
		var repair: int = (1 if "维修" in f.modules else 0) + int(f.get("upgrades",{}).get("repair",0))
		if repair > 0 and int(f.get("damage",0)) > 0:
			var repaired: int = mini(repair,int(f.damage))
			f.units = int(f.units) + repaired
			f.damage = int(f.damage) - repaired
		if "联盟信标" in f.modules and f.station != "":
			var home: Dictionary = planet(str(f.station))
			home.affinity = mini(100,int(home.affinity)+3)
			res(str(f.owner)).credits = int(res(str(f.owner)).credits)+1
	for p in state.planets:
		if int(p.siege) < int(state.turn) and p.status == "围困": p.status = "稳定"
	if int(state.mode) == 6 or rng.randf() < 0.45: _war_event()
	var chance: float = float(state.settings.get("invasion",15)) / 100.0
	if (int(state.mode) == 1 and int(state.turn) in [3,5,7]) or (int(state.mode) == 4 and int(state.turn) >= 2):
		_spawn_invasion()
	elif int(state.mode) != 1 and int(state.turn) > 3 and rng.randf() < chance: _spawn_invasion()
	var result: Dictionary = done("资源结算完成，敌方已行动。可回看本轮战况。")
	if not bool(state.get("tutorial",{}).get("active",false)): Systems.story_tick(self)
	_append_replay(before_events,"补给与事件结算完成。")
	return result

func _append_replay(before: Dictionary, label: String = "") -> void:
	var events: Array = Systems.record(self,before,label)
	for event in events:
		if state.replay.events.size() < 64: state.replay.events.append(event)

func _ai_turn(owner: String) -> void:
	if bool(state.get("tutorial",{}).get("active",false)): return
	if owned(owner).is_empty(): return
	for step in range(2):
		var before: Dictionary = observer_frame()
		_ai_step(owner,step)
		_append_replay(before)

func _ai_step(owner: String, step: int) -> void:
	var style: String = str(state.commanders[owner].style)
	var homes: Array = owned(owner)
	if homes.is_empty(): return
	# The same two actions and treasury fund each personality's decisions.
	var frontier: Dictionary = homes[0]
	var threat: int = -999
	for home in homes:
		var pressure: int = 2 if home.capital else 0
		for id in neighbors(str(home.id)):
			var enemy: Dictionary = planet(id)
			if enemy.owner not in [owner,"无主"]: pressure += ships(id)
		pressure -= ships(str(home.id))
		if pressure > threat:
			threat = pressure
			frontier = home
	if style == "defender" and threat >= 0 and step == 0:
		if frontier.building != "护盾阵列" and int(res(owner).materials) >= 4:
			res(owner).materials -= 4
			if frontier.building == "资源基地": frontier.income = maxi(0,int(frontier.income)-2)
			frontier.building = "护盾阵列"
			frontier.defense += 2
			_ai_log(owner,frontier,"加固了%s的防线。" % frontier.name)
			return
		if _ai_reinforce(owner,frontier): return
	if style == "trader" and step == 0 and int(state.turn)%3 == 0 and int(state.relations[owner]) >= 20:
		state.pacts[owner].ceasefire = int(state.turn)+2
		log_event("%s指挥官提出贸易停火，双方三轮内停止交战。" % owner)
		return
	if _ai_intercept(owner): return
	var candidates: Array = []
	for source in state.fleets:
		if source.owner != owner or source.station == "": continue
		for id in neighbors(str(source.station)):
			var target: Dictionary = planet(id)
			var route: Dictionary = adjacency(str(source.station),id)
			if route.broken or int(route.blocked) >= int(state.turn) or int(target.locked) >= int(state.turn): continue
			if target.owner == owner or (target.owner == state.player and (protected_from(owner) or int(state.turn)<3)): continue
			var margin: int = power(source)-defense(target)
			if margin < (2 if style == "defender" else 1): continue
			var rank: float = margin + rng.randf()*0.5
			if target.owner == "无主": rank += 12 if style == "trader" else 4
			elif style == "raider": rank += 12
			if target.capital: rank += 7
			if style == "trader": rank += int(target.income)*2
			if target.owner == "外星" and int(state.pacts[owner].joint) >= int(state.turn): rank += 30
			if style == "defender" and planet(str(source.station)).capital and stationed(str(source.station)).size() <= 1: rank -= 18
			candidates.append({"p":target,"f":source,"rank":rank})
	if not candidates.is_empty() and int(res(owner).credits) >= 2 and int(res(owner).fuel) >= 1:
		candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.rank)>float(b.rank))
		var target: Dictionary = candidates[0].p
		var source: Dictionary = candidates[0].f
		var known: bool = Systems.planet_live(self,target) or target.owner == state.player
		var loss: int = mini(int(source.units)-1,maxi(1,defense(target)/3))
		res(owner).credits -= 2
		res(owner).fuel -= 1
		for old in stationed(str(target.id)).duplicate():
			if old.get("core",false): state.cores_destroyed += 1
			state.fleets.erase(old)
		target.owner = owner
		target.militia = 0
		source.units -= loss
		source.damage = int(source.get("damage",0))+loss
		source.station = target.id
		source.x = target.x
		source.y = target.y
		if known: log_event("%s进攻并占领了%s。" % [owner,target.name])
		return
	if style == "trader" and int(res(owner).materials) < 3 and int(res(owner).credits) >= 4:
		res(owner).credits -= 4
		res(owner).materials += 4
		return
	_ai_reinforce(owner,frontier)

func _ai_reinforce(owner: String, p: Dictionary) -> bool:
	if int(res(owner).credits) < 2 or int(res(owner).materials) < 1: return false
	res(owner).credits -= 2
	res(owner).materials -= 1
	var defenders: Array = stationed(str(p.id),owner)
	if defenders.is_empty(): spawn_fleet(owner,str(p.id),1,"守卫")
	else: defenders[0].units += 1
	_ai_log(owner,p,"向%s派出增援。" % p.name)
	return true

func _ai_log(owner: String, p: Dictionary, text: String) -> void:
	if Systems.planet_live(self,p,true): log_event(owner+"指挥官"+text)

func _ai_intercept(owner: String) -> bool:
	if int(res(owner).fuel) < 1: return false
	var targets: Array = state.fleets.duplicate()
	if owner=="混沌": targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.type=="运输" and b.type!="运输")
	for attacker in state.fleets.duplicate():
		if attacker.owner != owner: continue
		for target in targets:
			if target.owner == owner or target.station != "": continue
			if target.owner == state.player and (protected_from(owner) or (int(state.turn)<3 and owner != "外星")): continue
			var exposed: bool = int(target.revealed) >= int(state.turn) or (target.owner == state.player and int(state.story.exposed_until) >= int(state.turn))
			if "隐匿" in target.modules and not exposed: continue
			if position_of(attacker).distance_to(position_of(target)) > (240 if exposed else 140) or power(attacker) <= power(target,false): continue
			var known: bool = target.owner == state.player or Systems.fleet_live(self,target) or Systems.fleet_live(self,attacker)
			res(owner).fuel = int(res(owner).fuel)-1
			for resource in target.get("cargo",{}): res(owner)[resource] = int(res(owner)[resource])+int(target.cargo[resource])
			if target.get("core",false): state.cores_destroyed = int(state.cores_destroyed)+1
			attacker.station = ""
			attacker.state = "太空"
			attacker.x = target.x
			attacker.y = target.y
			state.fleets.erase(target)
			if known: log_event("%s拦截并摧毁了%s，舰载补给被夺取。" % [owner,target.name])
			return true
	return false

func _spawn_invasion() -> void:
	state.invasion = int(state.invasion) + 1
	var alien: Dictionary = spawn_fleet("外星","",3 + mini(5,int(state.invasion)),"突击","外星远征军 %d" % int(state.invasion))
	alien.x = [940,60,520][int(state.invasion) % 3]
	alien.y = [80,740,65][int(state.invasion) % 3]
	alien.core = true
	alien.level = 2
	state.events.push_front("未知星门开启：外星远征军抵达银河。")
	log_event("红色警报：外星入侵！可请求其他势力共同抗敌。")

func _alien_turn() -> void:
	if bool(state.get("tutorial",{}).get("active",false)): return
	var before_intercept: Dictionary = observer_frame()
	_ai_intercept("外星")
	_append_replay(before_intercept)
	for alien in state.fleets.duplicate():
		if alien.owner != "外星": continue
		var before: Dictionary = observer_frame()
		var target: Dictionary = {}
		var distance: float = INF
		for p in state.planets:
			if p.owner == "外星" or int(p.locked) >= int(state.turn): continue
			var d: float = position_of(alien).distance_to(position_of(p))
			if d < distance:
				distance = d
				target = p
		if target.is_empty(): continue
		if distance > 150:
			var pos: Vector2 = position_of(alien).move_toward(position_of(target),120)
			alien.x = pos.x
			alien.y = pos.y
			alien.station = ""
			alien.state = "太空"
		elif power(alien) > defense(target):
			for old in stationed(str(target.id)).duplicate(): state.fleets.erase(old)
			target.owner = "外星"
			target.militia = 0
			target.status = "入侵"
			alien.x = target.x
			alien.y = target.y
			alien.station = target.id
			alien.state = "驻守"
			if Systems.planet_live(self,target) or Systems._find(before.planets,str(target.id)).get("owner","") == state.player: log_event("外星军占领了%s。" % target.name)
		elif int(res("外星").materials) >= 1:
			res("外星").materials -= 1
			alien.units = int(alien.units) + 1
		_append_replay(before)

func _war_event() -> void:
	if bool(state.get("tutorial",{}).get("active",false)): return
	var index: int = rng.randi_range(0,5)
	var p: Dictionary = state.planets[rng.randi_range(0,state.planets.size()-1)]
	var message: String
	match index:
		0:
			var g: Dictionary = state.gates[rng.randi_range(0,state.gates.size()-1)]
			g.broken = true
			message = "星门崩塌：%s至%s的线路需要修复。" % [planet(str(g.a)).name,planet(str(g.b)).name]
		1:
			p.depleted = not p.depleted
			message = "%s资源%s。" % [p.name,"枯竭" if p.depleted else "恢复"]
		2:
			p.affinity = maxi(-100,int(p.affinity) - 25)
			message = "%s发生地方抗议，好感 -25。" % p.name
		3:
			res().credits = int(res().credits) + 6
			message = "贸易繁荣：获得 6 信用点。"
		4:
			res().intel = int(res().intel) + 3
			message = "遗迹讯号：获得 3 情报。"
		_:
			res().fuel = maxi(0,int(res().fuel) - 3)
			message = "离子风暴：补给损失 3 燃料。"
	state.events.push_front(message)
	if state.events.size() > 30: state.events.resize(30)
	log_event(message)

func check_victory() -> void:
	if int(state.mode) == 7 or state.phase != "player": return
	var player: String = str(state.player)
	if owned().is_empty():
		_finish("外星" if not owned("外星").is_empty() else "敌方","所有领地已经失守。")
		return
	if int(state.mode) == 8:
		Systems.series_victory(self)
		return
	match int(state.mode):
		1:
			var aliens: int = 0
			for f in state.fleets:
				if f.owner == "外星": aliens += 1
			if int(state.cores_destroyed) >= 3 and aliens == 0: _finish(player,"银河联合抵抗成功，外星入侵被击退。")
		2:
			for faction in FACTIONS:
				if gate_count(faction) >= 5:
					_finish(faction,"率先控制了 5 座星门。")
					return
		3:
			var escort: Dictionary = fleet(str(state.escort))
			if escort.is_empty(): _finish("敌方","曙光运输船被摧毁，护航失败。")
			elif escort.station == state.escort_goal:
				res().credits = int(res().credits) + 30
				_finish(player,"运输船抵达终点，获得 30 信用点奖励。")
		4:
			if planet(capital_for(player)).owner != player: _finish("外星","首都失守，生存挑战失败。")
			elif int(state.turn) >= 10: _finish(player,"成功坚守 10 轮。")
		5:
			if diplomacy_score() >= 180: _finish(player,"外交积分达到 180，和平统一银河。")
		_:
			for faction in FACTIONS:
				var capitals: int = 0
				for p in owned(faction):
					if p.capital: capitals += 1
				if capitals >= 3:
					_finish(faction,"所有首都均已控制。")
	if state.phase == "player" and int(state.turn) > int(state.limit):
		if int(state.mode) in [1,3,4]:
			_finish("敌方","战争周期已结束，模式目标未完成。")
		else:
			var best: String = player
			for faction in FACTIONS:
				if score(faction) > score(best): best = faction
			_finish(best,"战争周期结束，按领地、首都、星门、舰队与声望积分结算。")

func _finish(winner: String, message: String) -> void:
	state.phase = "finished"
	state.winner = winner
	state.result = message
	log_event("战役结算：%s获胜。%s" % [winner,message])

func save_game(slot: String = "1", directory: String = "user://") -> String:
	if slot not in ["1","2","3","auto"]: return "无效存档槽位。"
	state.rng_state = rng.state
	var snapshot: Dictionary = state.duplicate(true)
	snapshot.saved_at = Time.get_datetime_string_from_system().replace("T"," ")
	# Store RNG state as text; JSON numbers cannot represent all 64-bit integers.
	snapshot.rng_state = str(rng.state)
	var path: String = directory.path_join("campaign_%s.json" % ("auto" if slot == "auto" else "slot_" + slot))
	var file := FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null: return "无法写入存档：%s" % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(snapshot))
	file.close()
	var error: Error = DirAccess.rename_absolute(path + ".tmp",path)
	return "" if error == OK else "保存失败：" + error_string(error)

func load_game(slot: String = "1", directory: String = "user://") -> String:
	if slot not in ["1","2","3","auto"]: return "无效存档槽位。"
	var path: String = directory.path_join("campaign_%s.json" % ("auto" if slot == "auto" else "slot_" + slot))
	if not FileAccess.file_exists(path): return "这个槽位还没有存档。"
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return "无法读取存档。"
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return "存档损坏：不是有效 JSON。"
	var data: Variant = parser.data
	if not data is Dictionary: return "存档损坏：不是有效 JSON。"
	var error: String = validate_snapshot(data)
	if error != "": return error
	if data.has("tutorial"):
		var tutorial: Variant = data.tutorial
		if not tutorial is Dictionary: return "实战教学存档损坏。"
		if not tutorial.get("active") is bool or not _valid_saved_number(tutorial.get("step")): return "实战教学进度损坏。"
		if int(tutorial.step) not in range(12): return "实战教学步骤无效。"
		for key in ["home","expand","enemy","fleet"]:
			if not tutorial.get(key) is String: return "实战教学目标损坏。"
		if tutorial.active:
			for key in ["home","expand","enemy"]:
				if not data.planets.any(func(p: Dictionary) -> bool: return p.id == tutorial[key]): return "实战教学星球丢失。"
			if not data.fleets.any(func(f: Dictionary) -> bool: return f.id == tutorial.fleet and f.owner == data.player): return "实战教学舰队丢失。"
	state = data
	_init_new_systems()
	rng.seed = absi(str(state.seed).hash())
	rng.state = int(state.rng_state)
	if int(state.version) == 2:
		Systems.initialize(self)
		state.version = VERSION
	return ""

func _valid_saved_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < 1.0e12

func validate_snapshot(data: Dictionary) -> String:
	if not _valid_saved_number(data.get("version")): return "存档版本字段损坏。"
	if int(data.get("version",0)) not in [2,VERSION]: return "存档版本不兼容；旧版存档未被覆盖。"
	for key in ["planets","fleets","gates","log","events"]:
		if not data.get(key) is Array: return "存档损坏：缺少 " + key
	for key in ["resources","relations","pacts","settings"]:
		if not data.get(key) is Dictionary: return "存档损坏：缺少 " + key
	for key in ["player","mode","turn","limit","ap","seed","rng_state","phase","next_fleet","escort","escort_goal","invasion","cores_destroyed","skill_turn","ultimate","diplomacy_turn"]:
		if not data.has(key): return "存档损坏：缺少 " + key
	for key in ["player","seed","phase","winner","result","escort","escort_goal"]:
		if not data.get(key) is String: return "存档文本字段损坏：" + key
	for key in ["mode","turn","limit","ap","next_fleet","invasion","cores_destroyed","skill_turn","diplomacy_turn"]:
		if not _valid_saved_number(data[key]): return "存档数值字段损坏：" + key
	if not data.ultimate is bool or data.phase not in ["player","finished"]: return "存档战役状态损坏。"
	if not (data.rng_state is int or (data.rng_state is String and data.rng_state.is_valid_int())): return "存档随机数状态损坏。"
	if data.winner not in ["","敌方"] and data.winner not in FACTIONS: return "存档胜利阵营无效。"
	for key in data.settings:
		if not _valid_saved_number(data.settings[key]): return "存档沙盒设置损坏。"
	for key in ["log","events"]:
		for entry in data[key]:
			if not entry is String: return "存档战报损坏。"
	if str(data.player) not in ["帝国","联盟","混沌"] or int(data.mode) not in range(9): return "存档模式或阵营无效。"
	if int(data.turn) < 1 or int(data.ap) < 0: return "存档回合或行动数无效。"
	var ids: Array = []
	for p in data.planets:
		if not p is Dictionary: return "星球数据损坏。"
		for key in ["id","name","x","y","owner","capital","home","income","defense","militia","affinity","building","status","locked","siege","policy","depleted","type"]:
			if not p.has(key): return "星球缺少属性：" + key
		for key in ["id","name","owner","home","building","status","policy","type"]:
			if not p[key] is String: return "星球文本属性损坏：" + key
		for key in ["x","y","income","defense","militia","affinity","locked","siege"]:
			if not _valid_saved_number(p[key]): return "星球数值属性损坏：" + key
		if not p.capital is bool or not p.depleted is bool: return "星球状态损坏。"
		if p.id in ids or p.owner not in COLORS: return "星球标识或阵营无效。"
		ids.append(p.id)
	if ids.size() < 3: return "星图数据不完整。"
	var fleet_ids: Array = []
	for f in data.fleets:
		if not f is Dictionary: return "舰队数据损坏。"
		for key in ["id","name","x","y","owner","station","units","type","level","modules","icon","color","support","support_until","support_target","revealed","destination","state"]:
			if not f.has(key): return "舰队缺少属性：" + key
		for key in ["id","name","owner","station","type","icon","color","support_target","state"]:
			if not f[key] is String: return "舰队文本属性损坏：" + key
		for key in ["x","y","units","level","support","support_until","revealed"]:
			if not _valid_saved_number(f[key]): return "舰队数值属性损坏：" + key
		if f.type not in TYPES or int(f.level) not in range(1,6) or not Color.html_is_valid(f.color): return "舰队类型、等级或涂装无效。"
		if not f.destination is Dictionary: return "舰队航行目标损坏。"
		for key in ["upgrades","cargo"]:
			var values: Variant = f.get(key,{})
			if not values is Dictionary: return "舰队专精或货物损坏。"
			for item in values:
				if not _valid_saved_number(values[item]) or float(values[item]) < 0: return "舰队专精或货物数值损坏。"
				if (key == "cargo" and item not in ["credits","materials","intel","fuel"]) or (key == "upgrades" and item not in UPGRADES): return "舰队专精或货物种类无效。"
		if f.has("damage") and not _valid_saved_number(f.damage): return "舰队损伤数值损坏。"
		if f.id in fleet_ids or int(f.units) < 1 or f.owner not in FACTIONS or (f.station != "" and f.station not in ids): return "舰队数据无效。"
		if not f.modules is Array: return "模块数据损坏。"
		for module in f.modules:
			if not module is String or module not in MODULES: return "模块类型无效。"
		fleet_ids.append(f.id)
	var gate_ids: Array = []
	if data.gates.is_empty(): return "星门网络不完整。"
	for g in data.gates:
		if not g is Dictionary: return "星门数据损坏。"
		for key in ["id","a","b","owner","blocked","broken"]:
			if not g.has(key): return "星门缺少属性：" + key
		for key in ["id","a","b","owner"]:
			if not g[key] is String: return "星门标识损坏。"
		if not _valid_saved_number(g.blocked) or not g.broken is bool or g.owner not in COLORS: return "星门状态损坏。"
		if g.id in gate_ids or g.a == g.b: return "星门标识重复或连接无效。"
		gate_ids.append(g.id)
		if g.a not in ids or g.b not in ids: return "星门目标不存在。"
	for faction in FACTIONS:
		if not data.resources.get(faction) is Dictionary or not data.pacts.get(faction) is Dictionary: return "阵营数据缺失。"
		if not data.relations.has(faction): return "好感数据缺失。"
		if not _valid_saved_number(data.relations[faction]): return "好感数值损坏。"
		for resource in RESOURCES:
			if not data.resources[faction].has(resource): return "资源数据缺失。"
			if not _valid_saved_number(data.resources[faction][resource]): return "资源数值损坏。"
		for key in ["alliance","ceasefire","access","protection","joint"]:
			if not data.pacts[faction].has(key): return "外交协议缺失。"
			if not _valid_saved_number(data.pacts[faction][key]): return "外交协议数值损坏。"
	var frontier_error: String = preload("res://frontier_systems.gd").validate(data)
	if frontier_error != "": return frontier_error
	if int(data.version) == VERSION: return Systems.validate(data)
	return ""

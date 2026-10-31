extends RefCounted
## Campaign-local progression. Network duels use equal loadouts, never these rewards.
const SHIPS: Dictionary = {
	"曙光":{"name":"曙光级护卫舰","rarity":"R","attack":8,"armor":5,"speed":8,"cost":12,"type":"突击"},
	"星尘":{"name":"星尘级侦察舰","rarity":"R","attack":5,"armor":4,"speed":12,"cost":14,"type":"侦察"},
	"苍穹":{"name":"苍穹级巡洋舰","rarity":"SR","attack":12,"armor":10,"speed":6,"cost":26,"type":"守卫"},
	"深渊":{"name":"深渊级战列舰","rarity":"SSR","attack":18,"armor":16,"speed":3,"cost":48,"type":"突击"}}
const DUNGEONS: Dictionary = {
	"遗迹回收":{"power":12,"fuel":2,"materials":8,"credits":5,"rep":2,"text":"突破无人机防线，回收合金。"},
	"星门突袭":{"power":23,"fuel":4,"materials":12,"credits":10,"rep":4,"text":"摧毁守卫中枢，需要更强战舰。"},
	"深空堡垒":{"power":34,"fuel":6,"materials":20,"credits":18,"rep":6,"text":"攻击、装甲与机动综合考验。"}}
const BUILDINGS: Dictionary = {"指挥中心":"提高副本战力", "合金矿场":"每轮生产 2 × 等级 材料", "能源阵列":"每轮生产 2 × 等级 燃料", "贸易港":"每轮生产 3 × 等级 星币"}
const GACHA_BANNERS: Dictionary = {
	"standard":{"title":"星门标准补给","cost":10,"ssr":5,"sr":15,"r":20,"materials":10,"detail":"稳定获取战舰与材料"},
	"elite":{"title":"精英舰队补给","cost":25,"ssr":12,"sr":28,"r":30,"materials":25,"detail":"更高战舰概率，适合追求升星"},
	"material":{"title":"工程材料补给","cost":15,"ssr":2,"sr":8,"r":10,"materials":35,"detail":"大概率获得材料，少量战舰"}}
const WELFARE: Dictionary = {
	"daily":{"title":"每日签到","detail":"获得 50 星币、5 材料、2 燃料","credits":50,"materials":5,"fuel":2},
	"fleet":{"title":"舰队援助","detail":"免费获得 1 艘曙光级护卫舰；首次领取后可再次领取材料","credits":20,"materials":12,"ship":"曙光"},
	"weekly":{"title":"远征里程奖","detail":"完成 3 次副本后获得 120 星币、20 材料和 1 艘星尘级侦察舰","credits":120,"materials":20,"ship":"星尘","need_clears":3}}

static func ensure(g) -> void:
	if g.state.get("frontier",{}).is_empty():
		g.state.frontier = {"buildings":{"指挥中心":1,"合金矿场":1,"能源阵列":1,"贸易港":1},"ships":{"曙光":1,"星尘":0,"苍穹":0,"深渊":0},"levels":{"曙光":1,"星尘":1,"苍穹":1,"深渊":1},"stars":{"曙光":1,"星尘":0,"苍穹":0,"深渊":0},"selected":"曙光","pity":0,"draws":0,"attempts":3,"clears":{},"reputation":0,"welfare":{"claimed":[],"streak":0,"last_turn":0},"history":[]}
	var f: Dictionary = g.state.frontier
	if not f.has("stars"): f.stars = {"曙光":1,"星尘":0,"苍穹":0,"深渊":0}
	if not f.has("welfare"): f.welfare = {"claimed":[],"streak":0,"last_turn":0}
	for key in SHIPS:
		if not f.ships.has(key): f.ships[key] = 0
		if not f.levels.has(key): f.levels[key] = 1
		if not f.stars.has(key): f.stars[key] = 0

static func validate(data: Dictionary) -> String:
	if not data.has("frontier"): return ""
	var f: Variant = data.frontier
	if not f is Dictionary: return "家园进度损坏。"
	if f.is_empty(): return ""
	for group in ["buildings","ships","levels","clears"]:
		if not f.get(group) is Dictionary: return "家园进度字段损坏。"
	for group in ["buildings","ships","levels"]:
		var keys: Array = BUILDINGS.keys() if group == "buildings" else SHIPS.keys()
		for key in keys:
			var value: Variant = f[group].get(key)
			if not (value is int or value is float): return "家园数值损坏。"
			var minimum: int = 0 if group in ["ships","stars"] else 1
			if not is_finite(float(value)) or float(value) != floor(float(value)) or value < minimum or value > (999999 if group == "ships" else 5): return "家园数值超出范围。"
	# stars was added after the first frontier save format; an absent field is
	# migrated by ensure(), while a present malformed field is still rejected.
	if f.has("stars"):
		if not f.stars is Dictionary: return "家园进度字段损坏。"
		for key in SHIPS:
			var star_value: Variant = f.stars.get(key)
			if not (star_value is int or star_value is float) or not is_finite(float(star_value)) or float(star_value) != floor(float(star_value)) or star_value < 0 or star_value > 5: return "家园星级数值损坏。"
	for key in ["pity","draws","attempts","reputation"]:
		var v: Variant = f.get(key)
		if not (v is int or v is float): return "远征数值损坏。"
		if not is_finite(float(v)) or float(v) != floor(float(v)) or v < 0 or v > 1000000: return "远征数值超出范围。"
	if f.pity > 19 or f.attempts > 3: return "补给或副本次数损坏。"
	if f.has("welfare"):
		if not f.welfare is Dictionary or not f.welfare.get("claimed",[]) is Array: return "福利领取记录损坏。"
		for welfare_id in f.welfare.claimed:
			if not WELFARE.has(welfare_id): return "福利编号损坏。"
	if not f.get("selected") is String or not SHIPS.has(f.selected): return "出战舰船损坏。"
	if int(f.ships[f.selected]) < 1: return "出战舰船未拥有。"
	if not f.get("history") is Array or f.history.size() > 12: return "补给历史损坏。"
	for line in f.history:
		if not line is String: return "补给历史损坏。"
	for key in f.clears:
		var v: Variant = f.clears[key]
		if not DUNGEONS.has(key) or not (v is int or v is float): return "副本记录损坏。"
		if not is_finite(float(v)) or v < 0 or v > 1000000: return "副本记录损坏。"
	return ""

static func tick(g) -> void:
	ensure(g)
	var b: Dictionary = g.state.frontier.buildings
	g.res().materials += int(b["合金矿场"]) * 2
	g.res().fuel += int(b["能源阵列"]) * 2
	g.res().credits += int(b["贸易港"]) * 3
	g.state.frontier.attempts = 3
	g.state.frontier.welfare.claimed = []
	g.state.frontier.welfare.last_turn = int(g.state.turn)
	g.log_event("家园产出到账，副本出击次数恢复至 3。")

static func strength(f: Dictionary) -> int:
	var s: Dictionary = SHIPS[f.selected]
	return int(s.attack) + int(s.armor) + int(s.speed) / 2 + (int(f.levels[f.selected])-1)*4 + maxi(0,int(f.stars.get(f.selected,0))-1)*5 + int(f.buildings["指挥中心"])*2

static func _grant_ship(f: Dictionary, key: String, duplicate_raises_star: bool = true) -> String:
	var owned: int = int(f.ships.get(key,0))
	f.ships[key] = owned + 1
	if owned == 0:
		f.stars[key] = maxi(1,int(f.stars.get(key,0)))
		return str(SHIPS[key].name)
	if duplicate_raises_star and int(f.stars.get(key,0)) < 5:
		f.stars[key] = int(f.stars.get(key,0)) + 1
		return "%s（重复舰体，升至 %d 星）" % [SHIPS[key].name,int(f.stars[key])]
	return "%s（重复舰体，已满 5 星）" % SHIPS[key].name

static func act(g, action: String, id: String = "", count: int = 1) -> Dictionary:
	ensure(g)
	var f: Dictionary = g.state.frontier
	if g.state.phase != "player": return g.fail("战役已结束，请开启新战役或进入下一章。")
	match action:
		"building":
			if not BUILDINGS.has(id): return g.fail("未知建筑。")
			var lv: int = int(f.buildings[id])
			if lv >= 5: return g.fail("建筑已满级。")
			var reason: String = g._cost(1,{"materials":lv*8,"credits":lv*4})
			if reason != "": return g.fail(reason)
			g._pay(1,{"materials":lv*8,"credits":lv*4})
			f.buildings[id] = lv+1
			return g.done("%s升级至 Lv.%d，消耗星币与材料。" % [id,lv+1])
		"draw":
			if count not in [1,10]: return g.fail("抽取数量无效。")
			var banner_id: String = id if GACHA_BANNERS.has(id) else "standard"
			var banner: Dictionary = GACHA_BANNERS[banner_id]
			var reason: String = g._cost(0,{"credits":int(banner.cost)*count})
			if reason != "": return g.fail(reason)
			g._pay(0,{"credits":int(banner.cost)*count})
			var results: Array[String] = []
			for i in range(count):
				var roll: int = g.rng.randi_range(0,99)
				var reward: String
				if int(f.pity) >= 19 or roll < int(banner.ssr):
					reward = _grant_ship(f,"深渊")
					f.pity = 0
				else:
					f.pity += 1
					if roll < int(banner.ssr)+int(banner.sr):
						reward = _grant_ship(f,"苍穹")
					elif roll < int(banner.ssr)+int(banner.sr)+int(banner.r):
						var key: String = "曙光" if roll % 2 == 0 else "星尘"
						reward = _grant_ship(f,key)
					else:
						var material_reward: int = int(banner.materials)
						g.res().materials += material_reward
						reward = "材料 ×%d" % material_reward
				results.append(reward)
				f.history.push_front(reward)
				if f.history.size() > 12: f.history.resize(12)
				f.draws += 1
			return g.done("%s：%s" % [banner.title,"、".join(results)])
		"select", "build_ship", "buy_ship", "upgrade_ship", "deploy":
			if not SHIPS.has(id): return g.fail("未知战舰。")
			var s: Dictionary = SHIPS[id]
			if action == "select":
				if int(f.ships[id]) <= 0: return g.fail("尚未拥有这艘战舰。")
				f.selected = id
				return g.done("出战战舰：" + str(s.name))
			if action == "build_ship":
				var reason: String = g._cost(1,{"materials":int(s.cost),"credits":8})
				if reason != "": return g.fail(reason)
				g._pay(1,{"materials":int(s.cost),"credits":8})
				f.ships[id] += 1
				if int(f.stars.get(id,0)) == 0: f.stars[id] = 1
				return g.done(str(s.name)+"建造完成。")
			if action == "buy_ship":
				var price: int = int(s.cost) * 4
				var reason: String = g._cost(1,{"credits":price})
				if reason != "": return g.fail(reason)
				g._pay(1,{"credits":price})
				f.ships[id] += 1
				if int(f.stars.get(id,0)) == 0: f.stars[id] = 1
				return g.done("商店直购：%s已加入机库，消耗 %d 星币。" % [s.name,price])
			if int(f.ships[id]) <= 0: return g.fail("尚未拥有这艘战舰。")
			if action == "upgrade_ship":
				var lv: int = int(f.levels[id])
				if lv >= 5: return g.fail("战舰已满级。")
				var reason: String = g._cost(1,{"materials":lv*6})
				if reason != "": return g.fail(reason)
				g._pay(1,{"materials":lv*6})
				f.levels[id] = lv+1
				return g.done(str(s.name)+"升级完成。")
			var home: String = g.capital_for(str(g.state.player))
			if home == "" or g.planet(home).owner != g.state.player: return g.fail("需要控制本阵营原始首都才能部署。")
			var fleet_count: int = g.state.fleets.filter(func(ship: Dictionary) -> bool: return ship.owner==g.state.player).size()
			if fleet_count >= (12 if g.state.player=="帝国" else 20): return g.fail("已达阵营舰队上限，请先合并舰队。")
			if id == f.selected and int(f.ships[id]) == 1: return g.fail("请保留至少一艘当前出战战舰，或先切换出战舰。")
			var reason: String = g._cost(1,{"fuel":2})
			if reason != "": return g.fail(reason)
			g._pay(1,{"fuel":2})
			f.ships[id] -= 1
			var ship: Dictionary = g.spawn_fleet(str(g.state.player),home,maxi(2,int(s.attack)/3),str(s.type),str(s.name))
			ship.level = int(f.levels[id])
			ship.modules = ["护盾"] if id == "苍穹" else (["侦察"] if id == "星尘" else ["主武器"])
			return g.done(str(s.name)+"已部署至首都，可在星图调度。")
		"dungeon":
			if not DUNGEONS.has(id): return g.fail("未知副本。")
			if int(f.attempts) <= 0: return g.fail("本轮副本次数用尽，下一轮恢复。")
			var d: Dictionary = DUNGEONS[id]
			var reason: String = g._cost(1,{"fuel":int(d.fuel)})
			if reason != "": return g.fail(reason)
			g._pay(1,{"fuel":int(d.fuel)})
			f.attempts -= 1
			var score: int = strength(f) + g.rng.randi_range(-3,3)
			if score < int(d.power): return g.done("%s撤离：战力 %d / 守军 %d，未获得奖励。升级战舰或指挥中心再试。" % [id,score,int(d.power)])
			g.res().materials += int(d.materials)
			g.res().credits += int(d.credits)
			f.reputation += int(d.rep)
			f.clears[id] = int(f.clears.get(id,0))+1
			return g.done("%s胜利！战力 %d / %d；材料 +%d，星币 +%d，阵营功勋 +%d。" % [id,score,int(d.power),int(d.materials),int(d.credits),int(d.rep)])
		"faction_supply":
			if int(f.reputation) < 10: return g.fail("兑换需要 10 阵营功勋。")
			f.reputation -= 10
			g.res().materials += 15
			g.res().fuel += 8
			return g.done("阵营军需到账：材料 +15，燃料 +8。")
		"welfare":
			if not WELFARE.has(id): return g.fail("未知福利。")
			if id in f.welfare.claimed: return g.fail("这份福利本轮已经领取。")
			var welfare: Dictionary = WELFARE[id]
			if int(welfare.get("need_clears",0)) > int(f.clears.values().reduce(func(total: int, value: Variant) -> int: return total + int(value),0)): return g.fail("完成 3 次副本后才能领取远征里程奖。")
			for key in ["credits","materials","fuel"]:
				if welfare.has(key): g.res()[key] = int(g.res()[key]) + int(welfare[key])
			var reward_text: String = welfare.detail
			if welfare.has("ship"):
				reward_text += "；" + _grant_ship(f,str(welfare.ship),false)
			f.welfare.claimed.append(id)
			f.welfare.streak = int(f.welfare.streak) + 1
			return g.done("福利领取成功：" + reward_text)

	return g.fail("未知远征操作。")

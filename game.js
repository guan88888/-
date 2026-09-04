"use strict";

const FACTIONS = {
  empire: { name: "残余银河帝国", short: "帝国", color: "#5fc6d1" },
  alliance: { name: "自由星域联盟", short: "联盟", color: "#e3a864" },
  chaos: { name: "破碎星域议会", short: "混沌", color: "#b186d7" },
  neutral: { name: "无主星域", short: "无主", color: "#829097" }
  ,alien: { name: "外星系远征军", short: "外星", color: "#eb6969" }
};

const FACTION_KITS = {
  empire: {
    label: "帝国技能", role: "防守反击，适合先巩固防线再稳步推进。",
    passive: "统御秩序：帝国星球防守时战力 +1。",
    active: { name: "星门锁域", icon: "锁", help: "选择一颗己方星球，本轮敌人无法攻击它。" },
    ultimate: { name: "银河重整", icon: "整", help: "所有己方星球舰队 +1，并额外获得 1 次行动。" },
    core: "均等军备", coreText: "每轮没有丢失星球，就积累 1 层秩序。3 层时首都舰队 +1。",
    weakness: "弱点：开局领地少，前期扩张速度较慢。"
  },
  alliance: {
    label: "联盟技能", role: "渗透扩张，适合快速铺开版图并瓦解弱点。",
    passive: "星域自治：开局比其他阵营多控制 1 颗星球。",
    active: { name: "离间策反", icon: "策", help: "选择相邻且舰队不高于 3 的非首都敌星，使其变为中立。" },
    ultimate: { name: "大分裂时代", icon: "裂", help: "所有敌方非首都舰队 -1，并额外获得 1 次行动。" },
    core: "众星割据", coreText: "控制星球越多，越容易从多个方向发动进攻。",
    weakness: "弱点：正面进攻战力 -1，不适合硬碰硬。"
  },
  chaos: {
    label: "混沌技能", role: "游击套利，适合削弱强敌并在残局抢占空白星域。",
    passive: "混沌游离：进攻出现平局时，混沌获胜。",
    active: { name: "星际劫掠", icon: "劫", help: "选择相邻且舰队大于 1 的敌星，偷取 1 点舰队。" },
    ultimate: { name: "乱世独霸", icon: "霸", help: "立即占领所有仍然无主的星球，每颗留下 1 舰队。" },
    core: "择主而栖", coreText: "不必正面硬拼，优先削弱领先者并等待残局机会。",
    weakness: "弱点：防守战力 -1，被连续进攻时很脆弱。"
  }
};
const FLEET_TYPES = { assault:{name:"突击舰队",icon:"攻",attack:2,defense:0}, guardian:{name:"守卫舰队",icon:"守",attack:0,defense:2}, pioneer:{name:"开拓舰队",icon:"拓",attack:0,defense:0}, raider:{name:"劫掠舰队",icon:"劫",attack:1,defense:-1} };

const PLANETS = [
  { id: "sol", name: "圣环", x: 17, y: 23, trait: "初代星门遗址。" },
  { id: "vega", name: "织女座", x: 39, y: 15, trait: "恒星工业世界。" },
  { id: "corvus", name: "渡鸦", x: 65, y: 18, trait: "边境情报站。" },
  { id: "helix", name: "螺旋港", x: 85, y: 29, trait: "星门贸易枢纽。" },
  { id: "eden", name: "新伊甸", x: 25, y: 47, trait: "人口充沛的宜居世界。" },
  { id: "cinder", name: "烬炉", x: 49, y: 38, trait: "巨型军工熔炉。" },
  { id: "mirror", name: "镜海", x: 74, y: 47, trait: "自治星门工坊。" },
  { id: "haven", name: "静默港", x: 12, y: 72, trait: "流亡舰队避难所。" },
  { id: "orion", name: "猎户庭", x: 36, y: 70, trait: "边境要塞。" },
  { id: "rift", name: "断层", x: 61, y: 66, trait: "空间裂隙星域。" },
  { id: "titan", name: "泰坦锚", x: 84, y: 72, trait: "舰队集结锚地。" },
  { id: "umbra", name: "暗面", x: 53, y: 87, trait: "通往未知深空。" }
  ,{ id: "lyra", name: "天琴", x: 8, y: 42, trait: "远古观测站。" }
  ,{ id: "sable", name: "玄幕", x: 90, y: 50, trait: "黑色晶体矿场。" }
  ,{ id: "kepler", name: "开普勒", x: 22, y: 88, trait: "深空农殖地。" }
  ,{ id: "aegis", name: "神盾", x: 77, y: 87, trait: "废弃防御环。" }
  ,{ id: "pulsar", name: "脉冲", x: 6, y: 15, trait: "高能脉冲源。" }
  ,{ id: "vanta", name: "凡塔", x: 96, y: 85, trait: "星门边缘哨站。" }
];

const EDGES = [
  ["sol","vega"],["sol","eden"],["vega","corvus"],["vega","cinder"],["vega","eden"],
  ["corvus","helix"],["corvus","cinder"],["corvus","mirror"],["helix","mirror"],["eden","cinder"],
  ["eden","haven"],["eden","orion"],["cinder","mirror"],["cinder","orion"],["cinder","rift"],
  ["mirror","titan"],["mirror","rift"],["haven","orion"],["orion","rift"],["orion","umbra"],
  ["rift","titan"],["rift","umbra"],["titan","umbra"]
  ,["sol","pulsar"],["pulsar","lyra"],["lyra","haven"],["lyra","orion"],["helix","sable"],["sable","titan"],["sable","vanta"],["haven","kepler"],["kepler","umbra"],["kepler","aegis"],["aegis","vanta"],["rift","aegis"]
];

const EVENTS = [
  { title: "流亡舰队归航", icon: "援", lore: "一支失联舰队突然穿过星门。", effect: "帝国最弱的星球舰队 +1。", apply: g => addToWeakest(g, "empire", 1) },
  { title: "自治动员", icon: "盟", lore: "联盟各星球共同组织边境防卫。", effect: "联盟最弱的星球舰队 +1。", apply: g => addToWeakest(g, "alliance", 1) },
  { title: "拾荒者集结", icon: "游", lore: "破碎星域的流浪舰队决定联手。", effect: "混沌最弱的星球舰队 +1。", apply: g => addToWeakest(g, "chaos", 1) },
  { title: "边境归顺", icon: "扩", lore: "一颗无主星球主动寻求庇护。", effect: "领地最少的势力获得一颗无主星球。", apply: g => giveNeutralToWeakest(g) },
  { title: "太阳风暴", icon: "减", lore: "强烈辐射迫使大型舰队分散。", effect: "每个势力最强的星球舰队 -1。", apply: g => weakenStrongestAll(g) },
  { title: "烬炉复产", icon: "加", lore: "沉睡的自动军工厂重新启动。", effect: "烬炉控制者舰队 +2。", apply: g => addAt(g, "cinder", 2) },
  { title: "首都征召", icon: "守", lore: "三方都开始保卫自己的核心世界。", effect: "三方首都舰队 +1。", apply: g => reinforceCapitals(g) },
  { title: "深空回声", icon: "战", lore: "未知信号让无主星域陷入恐慌。", effect: "所有无主星球舰队变为 1。", apply: g => g.planets.filter(p => p.owner === "neutral").forEach(p => p.fleet = 1) }
];

const ACTION_HINTS = {
  expand: "点击发亮的灰色星球完成扩张。",
  attack: "点击发亮的敌方星球发起进攻。舰队越多越容易获胜。",
  reinforce: "点击任意己方星球，让它的舰队增加 1。"
};

const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
let selectedFaction = "empire";
let state = null;
let toastTimer = null;
let tutorialStep = 0;

const TUTORIAL_STEPS = [
  { icon: "门", title: "目标：夺取敌方首都", copy: "你控制自己阵营颜色的星球。沿着星门线前进，夺取任意敌方首都即可立刻获胜。", tip: "地图上圆环更大的星球就是首都。" },
  { icon: "扩", title: "第一步：扩张", copy: "左侧选择“扩张”，地图会自动标亮能占领的灰色星球。点击任意一个发亮目标。", tip: "扩张最简单，不需要掷骰，适合作为开局第一步。" },
  { icon: "援", title: "第二步：增援", copy: "选择“增援”，再点击己方星球，它的舰队数字会增加 1。舰队越多，攻防越强。", tip: "准备进攻前，先给连接敌方的前线星球增援。" },
  { icon: "技", title: "第三步：使用阵营技能", copy: "每轮可免费使用一次专属主动技能。第 4 轮解锁终极技能，整局只能发动一次。", tip: "技能不消耗两次基础行动。完成行动后点击“结束本轮”。" }
];

function hashSeed(text) {
  let value = 2166136261;
  for (const ch of text) { value ^= ch.charCodeAt(0); value = Math.imul(value, 16777619); }
  return value >>> 0;
}

function mulberry32(seed) {
  return function() {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function shuffle(items, rng) {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function createGame(seed, playerFaction) {
  const rng = mulberry32(hashSeed(seed));
  const order = shuffle(PLANETS.map(p => p.id), rng);
  const capitals = { empire: order[0], alliance: order[1], chaos: order[2] };
  const owners = { [order[0]]: "empire", [order[1]]: "alliance", [order[2]]: "chaos", [order[3]]: "empire", [order[4]]: "alliance", [order[5]]: "chaos", [order[6]]: "alliance" };
  const planets = PLANETS.map(p => {
    const owner = owners[p.id] || "neutral";
    const capitalFaction = Object.keys(capitals).find(f => capitals[f] === p.id) || null;
    return {
      ...p,
      x: Math.max(8, Math.min(92, p.x + (rng() - .5) * 4)),
      y: Math.max(10, Math.min(90, p.y + (rng() - .5) * 4)),
      owner,
      fleet: capitalFaction ? 4 : owner === "neutral" ? 1 + Math.floor(rng() * 2) : 2,
      fleetType: owner === "neutral" ? "guardian" : (capitalFaction ? "guardian" : ["assault","guardian","pioneer"][Math.floor(rng()*3)]),
      capitalFaction
    };
  });
  return {
    seed, rng, playerFaction, round: 1, phase: "player", actions: 2, action: "expand", selectedPlanet: null,
    planets, edges: EDGES.map(([a,b]) => ({ a, b })), capitals, eventDeck: shuffle(EVENTS, rng), logs: [], gameOver: false,
    activeUsed: false, ultimateUsed: false, skillMode: null, shielded: null, empireHeld: territoryCountFor(planets, "empire"), order: 0,
    diplomacy: null, diplomacyUsed: false, alienActive: false, alienDefeated: false, credits: 24, materials: 14
  };
}

function territoryCountFor(planets, faction) { return planets.filter(p => p.owner === faction).length; }

function planet(id) { return state.planets.find(p => p.id === id); }
function ownedBy(faction) { return state.planets.filter(p => p.owner === faction); }
function neighbors(id) { return state.edges.filter(e => e.a === id || e.b === id).map(e => e.a === id ? e.b : e.a); }
function hasAdjacentOwner(id, faction) { return neighbors(id).some(neighborId => planet(neighborId).owner === faction); }
function territoryCount(faction) { return ownedBy(faction).length; }
function totalFleet(faction) { return ownedBy(faction).reduce((sum, p) => sum + p.fleet, 0); }
function factionScore(faction) { return territoryCount(faction) * 10 + totalFleet(faction); }

function init() {
  $$(".faction-card").forEach(card => card.addEventListener("click", () => {
    selectedFaction = card.dataset.faction;
    $$(".faction-card").forEach(item => item.classList.toggle("selected", item === card));
  }));
  $("#random-seed").addEventListener("click", () => $("#seed-input").value = randomSeed());
  $("#start-game").addEventListener("click", startGame);
  $("#start-tutorial").addEventListener("click", () => { window.forceTutorial = true; startGame(); });
  $$(".action-button").forEach(button => button.addEventListener("click", () => selectAction(button.dataset.action)));
  $("#end-turn").addEventListener("click", endPlayerTurn);
  $("#help-button").addEventListener("click", () => showModal("help-modal"));
  $("#faction-manual-button").addEventListener("click", showFactionManual);
  $("#active-skill").addEventListener("click", armActiveSkill);
  $("#ultimate-skill").addEventListener("click", useUltimate);
  $("#diplomacy-list").addEventListener("click", event => { const button = event.target.closest("button[data-faction]"); if (button) formDiplomacy(button.dataset.faction); });
  $("#buy-fleet").addEventListener("click", buyFleet); $("#upgrade-fleet").addEventListener("click", upgradeFleet); $("#save-game").addEventListener("click", saveGame); $("#load-game").addEventListener("click", loadGame);
  $("#restart-button").addEventListener("click", () => { if (confirm("放弃当前战役并返回阵营选择？")) returnToStart(); });
  $("#clear-log").addEventListener("click", () => { state.logs = []; renderLog(); });
  $("[data-close='help']").addEventListener("click", closeModals);
  $("[data-close='faction']").addEventListener("click", closeModals);
  $("#tutorial-next").addEventListener("click", nextTutorialStep);
  $("#tutorial-skip").addEventListener("click", finishTutorial);
  $("#replay-tutorial").addEventListener("click", () => { closeModals(); startTutorial(); });
  $("#resolve-event").addEventListener("click", () => { closeModals(); runAISequence(); });
  $("#new-game").addEventListener("click", returnToStart);
  $("#same-seed").addEventListener("click", () => { closeModals(); state = createGame(state.seed, state.playerFaction); beginGame(); });
  window.addEventListener("resize", () => { if (state) renderEdges(); });
  $("#seed-input").value = randomSeed();
}

function randomSeed() {
  const words = ["NOVA","ORBIT","RIFT","HELIX","PRIME","UMBRA","TITAN"];
  return words[Math.floor(Math.random() * words.length)] + Math.floor(100 + Math.random() * 900);
}

function startGame() {
  const seed = ($("#seed-input").value.trim() || randomSeed()).toUpperCase();
  state = createGame(seed, selectedFaction);
  beginGame();
}

function beginGame() {
  window.scrollTo({ top: 0, left: 0, behavior: "auto" });
  $("#start-screen").hidden = true;
  $("#game-screen").hidden = false;
  $("#seed-display").textContent = `星图 ${state.seed}`;
  log(`你选择了${FACTIONS[state.playerFaction].name}。`, "good");
  log("每轮行动两次，占领敌方首都即可获胜。第 12 轮结算。", "");
  selectAction("expand");
  renderAll();
  if (window.forceTutorial || !hasSeenTutorial()) {
    window.forceTutorial = false;
    setTimeout(() => startTutorial(), 180);
  } else {
    setTimeout(() => showToast("先选动作，再点击发亮的星球。"), 300);
  }
}

function renderAll() { renderTopbar(); renderMap(); renderDetail(); renderLog(); renderTurnOrder(); renderActions(); renderFactionCommand(); renderDiplomacy(); renderFleetPanel(); }

function renderTopbar() {
  $("#round-value").textContent = state.round;
  $("#ap-value").textContent = state.actions;
  $("#control-value").textContent = territoryCount(state.playerFaction);
  $("#credit-value").textContent = state.credits; $("#material-value").textContent = state.materials;
  $("#phase-status").textContent = state.phase === "player" ? "轮到你行动" : state.phase === "event" ? "发生战争事件" : "敌方正在行动";
  $("#alien-alert").hidden = !state.alienActive;
}

function renderMap() {
  const layer = $("#planet-layer");
  layer.innerHTML = "";
  state.planets.forEach(p => {
    const button = document.createElement("button");
    button.type = "button";
    const targetIsValid = state.skillMode === "active" ? isSkillTarget(p) : isValidTarget(p);
    button.className = `planet ${p.owner}${p.capitalFaction ? " capital" : ""}${state.selectedPlanet === p.id ? " selected" : ""}${targetIsValid ? " valid-target" : ""}${state.shielded === p.id ? " shielded" : ""}`;
    button.style.setProperty("--x", `${p.x}%`);
    button.style.setProperty("--y", `${p.y}%`);
    button.setAttribute("aria-label", `${p.name}，${FACTIONS[p.owner].name}，舰队 ${p.fleet}`);
    button.innerHTML = `<span class="planet-orb">${p.fleet}</span><strong>${p.name}</strong><small>${p.capitalFaction ? "首都" : FACTIONS[p.owner].short} · ${FLEET_TYPES[p.fleetType]?.icon || "舰"}</small>`;
    button.addEventListener("click", () => clickPlanet(p.id));
    layer.appendChild(button);
  });
  requestAnimationFrame(renderEdges);
}

function renderEdges() {
  if (!state || $("#game-screen").hidden) return;
  const svg = $("#gate-lines");
  svg.setAttribute("viewBox", "0 0 100 100");
  svg.setAttribute("preserveAspectRatio", "none");
  svg.innerHTML = state.edges.map(edge => {
    const a = planet(edge.a), b = planet(edge.b);
    const hot = state.selectedPlanet && (edge.a === state.selectedPlanet || edge.b === state.selectedPlanet);
    return `<line class="gate-line${hot ? " hot" : ""}" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" />`;
  }).join("");
}

function isValidTarget(p) {
  if (!state || state.phase !== "player" || state.actions < 1) return false;
  const faction = state.playerFaction;
  if (state.action === "expand") return p.owner === "neutral" && hasAdjacentOwner(p.id, faction);
  if (state.action === "attack") return p.owner !== faction && p.owner !== "neutral" && hasAdjacentOwner(p.id, faction) && !isDiplomaticTarget(p);
  if (state.action === "reinforce") return p.owner === faction;
  return false;
}

function selectAction(action) {
  if (!state || state.phase !== "player") return;
  state.skillMode = null;
  state.action = action;
  $$(".action-button").forEach(button => button.classList.toggle("active", button.dataset.action === action));
  $("#action-hint").textContent = ACTION_HINTS[action];
  renderMap();
}

function clickPlanet(id) {
  state.selectedPlanet = id;
  const target = planet(id);
  renderMap();
  renderDetail();
  if (state.skillMode && isSkillTarget(target)) {
    resolveActiveSkill(target);
    return;
  }
  if (state.phase !== "player" || state.actions < 1 || !isValidTarget(target)) return;
  performPlayerAction(target);
}

function performPlayerAction(target) {
  const faction = state.playerFaction;
  state.actions--;
  if (state.action === "expand") {
    target.owner = faction;
    target.fleet = 1;
    target.fleetType = "pioneer";
    state.credits += 2; state.materials += 1;
    log(`${FACTIONS[faction].short}占领了${target.name}。`, "good");
  } else if (state.action === "attack") {
    resolveBattle(faction, target);
  } else {
    target.fleet++;
    state.credits += 1;
    log(`${target.name}获得增援，舰队变为 ${target.fleet}。`, "good");
  }
  renderAll();
  if (!state.gameOver && state.actions === 0) showToast("两次行动已完成，请结束本轮。 ");
}

function resolveBattle(attacker, target) {
  const source = ownedBy(attacker).filter(p => neighbors(p.id).includes(target.id)).sort((a,b) => b.fleet - a.fleet)[0];
  if (!source) return;
  const attackPower = source.fleet + 1 + Math.floor(state.rng() * 6) + (FLEET_TYPES[source.fleetType]?.attack || 0);
  let defensePower = target.fleet + 1 + Math.floor(state.rng() * 6) + (FLEET_TYPES[target.fleetType]?.defense || 0);
  let finalAttack = attackPower;
  if (attacker === "alliance") finalAttack--;
  if (target.owner === "empire") defensePower++;
  if (target.owner === "chaos") defensePower--;
  if (state.shielded === target.id && attacker !== state.playerFaction) {
    log(`${target.name}受星门锁域保护，敌方无法进攻。`, "good");
    return;
  }
  const attackerWins = finalAttack > defensePower || (attacker === "chaos" && finalAttack === defensePower);
  if (attackerWins) {
    const oldOwner = target.owner;
    target.owner = attacker;
    target.fleet = 1;
    if (source.fleet > 1) source.fleet--;
    log(`${source.name}攻下${target.name}，${finalAttack} 比 ${defensePower}。`, attacker === state.playerFaction ? "good" : "bad");
    checkCapital(target, attacker, oldOwner);
  } else {
    if (source.fleet > 1) source.fleet--;
    log(`${source.name}进攻失败，${finalAttack} 比 ${defensePower}。`, attacker === state.playerFaction ? "bad" : "good");
  }
}

function checkCapital(target, attacker) {
  if (target.capitalFaction && target.capitalFaction !== attacker) finishGame(attacker, "capital");
}

function endPlayerTurn() {
  if (state.phase !== "player" || state.gameOver) return;
  state.phase = "event";
  state.credits += 3; state.materials += 2;
  state.selectedPlanet = null;
  const alienHit = !state.alienActive && state.rng() < 0.25;
  const event = alienHit ? triggerAlienInvasion() : state.eventDeck[(state.round - 1) % state.eventDeck.length];
  if (!alienHit) event.apply(state);
  log(`事件：${event.title}。${event.effect}`, "event");
  $("#event-sigil").textContent = event.icon;
  $("#event-title").textContent = event.title;
  $("#event-lore").textContent = event.lore;
  $("#event-effect").textContent = event.effect;
  renderAll();
  showModal("event-modal");
}

async function runAISequence() {
  if (state.gameOver) return;
  state.phase = "ai";
  renderAll();
  const enemies = ["empire","alliance","chaos"].filter(f => f !== state.playerFaction);
  for (const faction of enemies) {
    if (state.gameOver) return;
    await wait(420);
    aiAction(faction);
    renderAll();
  }
  if (state.gameOver) return;
  await wait(250);
  if (state.round >= 12) return finishGame(null, "score");
  state.round++;
  state.phase = "player";
  state.actions = 2;
  state.credits += 2; state.materials += 1;
  state.activeUsed = false;
  state.diplomacyUsed = false;
  state.skillMode = null;
  state.shielded = null;
  state.selectedPlanet = null;
  applyEmpireOrder();
  log(`第 ${state.round} 轮开始。`, "event");
  selectAction(state.action);
  renderAll();
  showToast(`第 ${state.round} 轮，你可以行动两次。`);
}

function aiAction(faction) {
  const owned = ownedBy(faction);
  if (!owned.length) return;
  const attacks = state.planets.filter(p => p.owner !== faction && p.owner !== "neutral" && p.owner !== "alien" && hasAdjacentOwner(p.id, faction) && state.shielded !== p.id && !isDiplomaticTarget(p)).sort((a,b) => a.fleet - b.fleet);
  const neutrals = state.planets.filter(p => p.owner === "neutral" && hasAdjacentOwner(p.id, faction));
  const strongest = [...owned].sort((a,b) => b.fleet - a.fleet)[0];
  if (attacks.length && strongest.fleet >= attacks[0].fleet && state.rng() > .3) {
    resolveBattle(faction, attacks[0]);
  } else if (neutrals.length) {
    const target = neutrals[Math.floor(state.rng() * neutrals.length)];
    target.owner = faction;
    target.fleet = 1;
    target.fleetType = faction === "alliance" ? "pioneer" : "assault";
    log(`${FACTIONS[faction].short}占领了${target.name}。`, "bad");
  } else {
    strongest.fleet++;
    log(`${FACTIONS[faction].short}增援了${strongest.name}。`, "");
  }
}

function isDiplomaticTarget(p) {
  return state.diplomacy === p.owner && p.owner !== "neutral" && p.owner !== "alien";
}

function formDiplomacy(faction) {
  if (!state || state.phase !== "player" || state.diplomacyUsed) return;
  if (faction === state.playerFaction) return;
  if (state.diplomacy === faction) {
    state.diplomacy = null;
    log(`你结束了与${FACTIONS[faction].short}的停战。`, "event");
  } else {
    state.diplomacy = faction;
    log(`你与${FACTIONS[faction].short}达成临时同盟，共同抵抗外星系。`, "good");
  }
  state.diplomacyUsed = true;
  renderAll();
}

function renderDiplomacy() {
  if (!state) return;
  const list = $("#diplomacy-list");
  const options = ["empire", "alliance", "chaos"].filter(f => f !== state.playerFaction);
  list.innerHTML = options.map(f => `<button class="diplomacy-button${state.diplomacy === f ? " active" : ""}" data-faction="${f}" type="button" ${state.diplomacyUsed ? "disabled" : ""}>${state.diplomacy === f ? "已结盟" : `与${FACTIONS[f].short}结盟`}</button>`).join("");
  $("#diplomacy-status").textContent = state.diplomacy ? `与${FACTIONS[state.diplomacy].short}同盟` : state.diplomacyUsed ? "本轮已用" : "未结盟";
}

function renderFleetPanel() {
  const p = state.selectedPlanet ? planet(state.selectedPlanet) : null;
  $("#fleet-hint").textContent = p && p.owner === state.playerFaction ? `${p.name}：${FLEET_TYPES[p.fleetType]?.name || "舰队"} Lv${p.fleet}` : "先在地图选择己方星球，再购买或升级舰队。";
}
function buyFleet() {
  const p = state.selectedPlanet ? planet(state.selectedPlanet) : null;
  const type = $("#fleet-type-select").value;
  if (!p || p.owner !== state.playerFaction) return showToast("请选择己方星球作为驻守点。", true);
  if (state.credits < 8 || state.materials < 4) return showToast("信用点或材料不足。", true);
  state.credits -= 8; state.materials -= 4; p.fleet++; p.fleetType = type;
  log(`${p.name}购买并部署${FLEET_TYPES[type].name}。`, "good"); renderAll();
}
function upgradeFleet() {
  const p = state.selectedPlanet ? planet(state.selectedPlanet) : null;
  if (!p || p.owner !== state.playerFaction) return showToast("请选择己方星球作为升级目标。", true);
  if (state.credits < 6 || state.materials < 3) return showToast("升级所需资源不足。", true);
  state.credits -= 6; state.materials -= 3; p.fleet++;
  log(`${p.name}的${FLEET_TYPES[p.fleetType]?.name || "舰队"}完成升级。`, "good"); renderAll();
}
function saveGame() {
  if (!state) return;
  const snapshot = {...state, rng: null};
  try { localStorage.setItem("stargate-save", JSON.stringify(snapshot)); state.savedAt = Date.now(); showToast("战役已保存到本机。"); } catch { showToast("存档失败。", true); }
}
function loadGame() {
  try {
    const raw = localStorage.getItem("stargate-save"); if (!raw) return showToast("还没有可读取的存档。", true);
    const data = JSON.parse(raw); state = {...data, rng: mulberry32(hashSeed(data.seed + "-resume")), eventDeck: shuffle(EVENTS, mulberry32(hashSeed(data.seed + "-events"))), phase:"player", gameOver:false}; beginGame(); showToast("已读取本机存档。");
  } catch { showToast("存档读取失败。", true); }
}

function triggerAlienInvasion() {
  state.alienActive = true;
  const neutral = shuffle(state.planets.filter(p => p.owner === "neutral"), state.rng).slice(0, 3);
  neutral.forEach(p => { p.owner = "alien"; p.fleet = 7; });
  alienAttack();
  return { title: "外星系入侵", icon: "外", lore: "未知星门打开，远征军进入银河边缘。", effect: "3 颗无主星球被外星系占领，外星舰队十分强大。", apply: () => {} };
}

function alienAttack() {
  const targets = state.planets.filter(p => p.owner === state.playerFaction || p.owner === state.diplomacy).sort((a,b) => b.fleet - a.fleet);
  const alien = state.planets.filter(p => p.owner === "alien").sort((a,b) => b.fleet - a.fleet)[0];
  const target = targets.find(p => neighbors(p.id).some(id => planet(id).owner === "alien"));
  if (!alien || !target) return;
  const alliedBonus = state.diplomacy && target.owner === state.playerFaction ? 2 : 0;
  const attack = alien.fleet + 3 + Math.floor(state.rng() * 6);
  const defense = target.fleet + alliedBonus + Math.floor(state.rng() * 6);
  if (attack > defense) {
    target.owner = "alien"; target.fleet = 5;
    log(`外星远征军攻占${target.name}，需要更多盟军支援。`, "bad");
  } else {
    alien.fleet = Math.max(1, alien.fleet - 2);
    log(`${target.name}在${state.diplomacy ? "同盟舰队" : "孤军"}支援下击退外星远征军。`, "good");
    if (alien.fleet <= 1) { state.alienActive = false; state.alienDefeated = true; log("外星系入侵被击退。", "event"); }
  }
}

function finishGame(winner, reason) {
  if (state.gameOver) return;
  state.gameOver = true;
  if (!winner) winner = ["empire","alliance","chaos"].sort((a,b) => factionScore(b) - factionScore(a))[0];
  const won = winner === state.playerFaction;
  $("#result-kicker").textContent = won ? "你赢了" : "战役结束";
  $("#result-title").textContent = `${FACTIONS[winner].short}赢得银河`;
  $("#result-copy").textContent = reason === "capital" ? `${FACTIONS[winner].name}夺取了敌方首都。` : `第 12 轮结束，${FACTIONS[winner].name}控制的星球最多。`;
  $("#score-board").innerHTML = ["empire","alliance","chaos"].sort((a,b) => factionScore(b)-factionScore(a)).map(f => `<div class="score-row${f === winner ? " winner" : ""}"><span>${FACTIONS[f].name}</span><b>${territoryCount(f)} 颗星球</b></div>`).join("");
  showModal("result-modal");
}

function renderDetail() {
  const p = state.selectedPlanet ? planet(state.selectedPlanet) : null;
  const box = $("#planet-detail");
  if (!p) {
    $("#selected-code").textContent = "未选择";
    box.className = "planet-detail empty-state";
    box.innerHTML = `<div class="radar-placeholder" aria-hidden="true"></div><p>点击星球查看归属与舰队</p>`;
    return;
  }
  $("#selected-code").textContent = p.id.toUpperCase();
  box.className = "planet-detail";
  box.style.setProperty("--owner-color", FACTIONS[p.owner].color);
  box.innerHTML = `<div class="detail-name"><div><h3>${p.name}</h3><p>${p.capitalFaction ? "阵营首都" : "普通星球"}</p></div><span class="owner-badge">${FACTIONS[p.owner].short}</span></div><div class="detail-stats"><div><span>舰队</span><b>${p.fleet}</b></div><div><span>类型</span><b>${FLEET_TYPES[p.fleetType]?.name || "舰队"}</b></div></div><p class="detail-trait">${p.trait}</p>`;
}

function renderActions() {
  const locked = state.phase !== "player" || state.actions < 1;
  $$(".action-button").forEach(button => button.disabled = locked);
  $("#end-turn").disabled = state.phase !== "player";
}

function isSkillTarget(p) {
  if (!state || state.phase !== "player" || state.skillMode !== "active") return false;
  const faction = state.playerFaction;
  if (faction === "empire") return p.owner === faction;
  if (faction === "alliance") return p.owner !== faction && p.owner !== "neutral" && !p.capitalFaction && p.fleet <= 3 && hasAdjacentOwner(p.id, faction);
  return p.owner !== faction && p.owner !== "neutral" && p.fleet > 1 && hasAdjacentOwner(p.id, faction);
}

function armActiveSkill() {
  if (!state || state.phase !== "player" || state.activeUsed) return;
  const available = state.planets.some(p => {
    const old = state.skillMode;
    state.skillMode = "active";
    const valid = isSkillTarget(p);
    state.skillMode = old;
    return valid;
  });
  if (!available) return showToast("当前没有可使用该技能的目标。", true);
  state.skillMode = state.skillMode === "active" ? null : "active";
  const kit = FACTION_KITS[state.playerFaction];
  $("#action-hint").textContent = state.skillMode ? kit.active.help : ACTION_HINTS[state.action];
  renderMap();
  renderFactionCommand();
}

function resolveActiveSkill(target) {
  const faction = state.playerFaction;
  if (faction === "empire") {
    state.shielded = target.id;
    log(`${target.name}启动星门锁域，本轮无法被攻击。`, "good");
  } else if (faction === "alliance") {
    const oldOwner = target.owner;
    target.owner = "neutral";
    target.fleet = 1;
    log(`${target.name}遭到离间，脱离${FACTIONS[oldOwner].short}并变为中立。`, "good");
  } else {
    target.fleet--;
    const receiver = ownedBy("chaos").sort((a,b) => a.fleet - b.fleet)[0];
    if (receiver) receiver.fleet++;
    log(`混沌从${target.name}劫掠 1 点舰队。`, "good");
  }
  state.activeUsed = true;
  state.skillMode = null;
  $("#action-hint").textContent = ACTION_HINTS[state.action];
  renderAll();
}

function useUltimate() {
  if (!state || state.phase !== "player" || state.round < 4 || state.ultimateUsed) return;
  const faction = state.playerFaction;
  if (faction === "empire") {
    ownedBy(faction).forEach(p => p.fleet++);
    state.actions++;
    log("银河重整启动：全体舰队 +1，本轮行动 +1。", "event");
  } else if (faction === "alliance") {
    state.planets.filter(p => p.owner !== faction && p.owner !== "neutral" && !p.capitalFaction).forEach(p => p.fleet = Math.max(1, p.fleet - 1));
    state.actions++;
    log("大分裂时代爆发：敌方边缘星球削弱，本轮行动 +1。", "event");
  } else {
    state.planets.filter(p => p.owner === "neutral").forEach(p => { p.owner = faction; p.fleet = 1; });
    log("乱世独霸发动：混沌抢占了所有无主星球。", "event");
  }
  state.ultimateUsed = true;
  renderAll();
}

function applyEmpireOrder() {
  const current = territoryCount("empire");
  if (current >= state.empireHeld) state.order++;
  else state.order = 0;
  state.empireHeld = current;
  if (state.order >= 3) {
    const capital = planet(state.capitals.empire);
    if (capital && capital.owner === "empire") capital.fleet++;
    state.order = 0;
    log("帝国秩序叠满，首都舰队 +1。", "event");
  }
}

function renderFactionCommand() {
  const faction = state.playerFaction;
  const kit = FACTION_KITS[faction];
  $("#faction-mini-name").textContent = kit.label;
  $("#passive-line p").textContent = kit.passive;
  const active = $("#active-skill");
  active.querySelector(".skill-icon").textContent = kit.active.icon;
  active.querySelector("b").textContent = kit.active.name;
  active.querySelector("small").textContent = kit.active.help;
  active.querySelector("em").textContent = state.activeUsed ? "已使用" : state.skillMode === "active" ? "选择目标" : "就绪";
  active.disabled = state.phase !== "player" || state.activeUsed;
  active.classList.toggle("armed", state.skillMode === "active");
  const ultimate = $("#ultimate-skill");
  ultimate.querySelector(".skill-icon").textContent = kit.ultimate.icon;
  ultimate.querySelector("b").textContent = kit.ultimate.name;
  ultimate.querySelector("small").textContent = kit.ultimate.help;
  ultimate.querySelector("em").textContent = state.ultimateUsed ? "已使用" : state.round < 4 ? `第 4 轮解锁` : "可发动";
  ultimate.disabled = state.phase !== "player" || state.ultimateUsed || state.round < 4;
}

function showFactionManual() {
  const kit = FACTION_KITS[state.playerFaction];
  $("#faction-manual-title").textContent = FACTIONS[state.playerFaction].name;
  $("#faction-manual-role").textContent = kit.role;
  $("#faction-manual-grid").innerHTML = `
    <article class="manual-card"><span>常驻被动</span><b>${kit.passive.split("：")[0]}</b><p>${kit.passive.split("：").slice(1).join("：")}</p></article>
    <article class="manual-card"><span>每轮技能</span><b>${kit.active.name}</b><p>${kit.active.help}</p></article>
    <article class="manual-card"><span>核心机制</span><b>${kit.core}</b><p>${kit.coreText}</p></article>
    <article class="manual-card"><span>一次终极</span><b>${kit.ultimate.name}</b><p>${kit.ultimate.help}</p></article>`;
  $("#faction-weakness").textContent = kit.weakness;
  showModal("faction-modal");
}

function startTutorial() {
  tutorialStep = 0;
  renderTutorialStep();
  showModal("tutorial-modal");
}

function renderTutorialStep() {
  const step = TUTORIAL_STEPS[tutorialStep];
  $("#tutorial-title").textContent = step.title;
  $("#tutorial-copy").textContent = step.copy;
  $("#tutorial-tip").textContent = step.tip;
  $("#tutorial-visual").dataset.icon = step.icon;
  $$("#tutorial-progress span").forEach((bar, index) => bar.classList.toggle("active", index <= tutorialStep));
  $("#tutorial-next").textContent = tutorialStep === TUTORIAL_STEPS.length - 1 ? "开始指挥" : "下一步";
}

function nextTutorialStep() {
  if (tutorialStep >= TUTORIAL_STEPS.length - 1) return finishTutorial();
  tutorialStep++;
  renderTutorialStep();
}

function finishTutorial() {
  rememberTutorial();
  closeModals();
  selectAction("expand");
  showToast("选择“扩张”后，点击地图上发亮的灰色星球。 ");
}

function hasSeenTutorial() {
  try { return localStorage.getItem("stargate-tutorial-seen") === "1"; }
  catch { return false; }
}

function rememberTutorial() {
  try { localStorage.setItem("stargate-tutorial-seen", "1"); }
  catch { /* 教学仍可正常关闭 */ }
}

function renderTurnOrder() {
  const order = [state.playerFaction, ...["empire","alliance","chaos"].filter(f => f !== state.playerFaction)];
  $("#turn-order-list").innerHTML = order.map((f,i) => `<span class="turn-chip${state.phase === "player" && i === 0 ? " current" : state.phase === "ai" && i > 0 ? " current" : ""}" style="color:${FACTIONS[f].color}">${FACTIONS[f].short}</span>`).join("");
}

function log(message, type = "") {
  state.logs.unshift({ message, type, round: state.round });
  state.logs = state.logs.slice(0, 30);
  renderLog();
}

function renderLog() {
  if (!state) return;
  $("#war-log").innerHTML = state.logs.length ? state.logs.map(entry => `<div class="log-entry ${entry.type}"><b>R${entry.round}</b>${entry.message}</div>`).join("") : `<div class="log-entry">记录已清空。</div>`;
}

function showToast(message, error = false) {
  const toast = $("#toast");
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.style.borderColor = error ? "var(--danger)" : "var(--line-bright)";
  toast.classList.add("show");
  toastTimer = setTimeout(() => toast.classList.remove("show"), 2400);
}

function showModal(id) {
  $("#modal-backdrop").hidden = false;
  $$(".modal").forEach(modal => modal.hidden = modal.id !== id);
  setTimeout(() => $("#" + id).querySelector("button")?.focus(), 10);
}

function closeModals() { $("#modal-backdrop").hidden = true; $$(".modal").forEach(modal => modal.hidden = true); }
function returnToStart() { closeModals(); state = null; $("#game-screen").hidden = true; $("#start-screen").hidden = false; $("#seed-input").value = randomSeed(); window.scrollTo({ top: 0, left: 0, behavior: "auto" }); }
function wait(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

function addToWeakest(g, faction, amount) {
  const target = g.planets.filter(p => p.owner === faction).sort((a,b) => a.fleet - b.fleet)[0];
  if (target) target.fleet += amount;
}

function giveNeutralToWeakest(g) {
  const neutral = shuffle(g.planets.filter(p => p.owner === "neutral"), g.rng)[0];
  if (!neutral) return;
  const faction = ["empire","alliance","chaos"].sort((a,b) => g.planets.filter(p => p.owner === a).length - g.planets.filter(p => p.owner === b).length)[0];
  neutral.owner = faction;
  neutral.fleet = 1;
}

function weakenStrongestAll(g) {
  ["empire","alliance","chaos"].forEach(faction => {
    const target = g.planets.filter(p => p.owner === faction).sort((a,b) => b.fleet - a.fleet)[0];
    if (target) target.fleet = Math.max(1, target.fleet - 1);
  });
}

function addAt(g, id, amount) {
  const target = g.planets.find(p => p.id === id);
  if (target && target.owner !== "neutral") target.fleet += amount;
}

function reinforceCapitals(g) {
  Object.values(g.capitals).forEach(id => {
    const target = g.planets.find(p => p.id === id);
    if (target) target.fleet++;
  });
}

init();

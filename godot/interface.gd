extends Control

const Rules = preload("res://game_state.gd")
const StarMap = preload("res://galaxy_map.gd")
const Help = preload("res://ui_help.gd")
const Systems = preload("res://campaign_systems.gd")
const Music = preload("res://music_player.gd")
const BG := Color("061326")
const PANEL := Color("091c32")
const LINE := Color("203d57")
const TEXT := Color("dce9f4")
const MUTED := Color("91a9bf")
const CYAN := Color("7bbdd3")
const ORANGE := Color("d0a26a")
const PURPLE := Color("aa9bc4")
const RED := Color("dd8d90")
const INK := Color("102e49")
const ACCENT := Color("174d70")
const FACTION_TITLES: Array[String] = ["残余银河帝国","自由星域联盟","破碎星域议会"]
const FACTION_DESCRIPTIONS: Array[String] = ["适合稳守，首都更难攻破","适合扩张，开局多一颗星球","适合进攻，平局也能获胜"]
const FACTION_BONUSES: Array[String] = ["首都防御 +1","开局领地 +1","进攻平局获胜"]
const GUIDE: Array = [
	["选择阵营","帝国稳守、联盟扩张、混沌进攻。选择喜欢的阵营，点击「开启星门」。"],
	["认识星图","圆圈是星球，轨道环是首都。? 表示兵力未识别，暗色与空心舰标是旧情报。侦察舰靠近或主动扫描可更新；扫描花费 1 行动和 2 情报。"],
	["选择指令","扩张、进攻、增援每次消耗行动。先点指令，再点带框选标记的目标。失败会显示原因，不扣资源。"],
	["选择舰队","点击己方星球，在「星球信息」或「舰队工坊」选择一支驻军。三角形代表独立舰队。"],
	["拖动舰队","拖动选中舰队或己方星球上的舰队图标，松手查看距离、消耗和风险，再确认操作。"],
	["星门与远程移动","相连开放星门仅需 1 燃料。太空远程移动消耗更多行动和燃料；损坏线路先修复。"],
	["友方相遇","靠近己方舰队可以合并、临时支援、交换模块。拆分滑块决定新分队数量，每队至少 1 单位。"],
	["敌方相遇","接近敌舰后选择开战、侦察、避让、威慑或停火。强攻前先比较舰队战力。"],
	["驻守与攻城","移动到己方星球自动驻守。攻击敌星可选择突袭、围困、轰炸、封锁、策反或诱敌。占领后选择治理政策。"],
	["购买和改装","舰队工坊可购买六种舰队、升级或配置名称、类型、涂装与模块。高级模块需要 LV.2。"],
	["资源与燃料","信用点购买舰队，材料建设改装，情报侦察策反，燃料移动，声望影响外交威慑。每轮由领地产出。"],
	["外交与好感","每轮一次外交。交换情报获得对方掌握的航图报告。帝国重防守、联盟重交易、混沌重突袭，结盟门槛也不同；结盟或停战后禁止互相攻击。"],
	["共同抵抗入侵","外星远征军从未知星门出现。外交频道请求援军、共同抗敌；点击入侵核心并消灭它。"],
	["完成模式目标","结束回合后可回放可见战况。「战役事务」处理有后续影响的剧情；「连续战役」提供三章目标，胜利后保留幸存舰队。所有进度保存在本机。"]
]

class HeroTitle extends Control:
	var title_font: Font
	func _draw() -> void:
		if title_font == null: return
		# Fit both lines inside the allocated area, not just the window width.
		var fs: int = int(minf(size.x / 5.4,size.y / 2.6))
		draw_string(title_font,Vector2(0,fs),"星门纪元",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,TEXT)
		draw_string(title_font,Vector2(2,fs*1.9),"银河分裂",HORIZONTAL_ALIGNMENT_LEFT,-1,int(fs*0.48),MUTED)
		draw_line(Vector2(2,size.y-2),Vector2(48,size.y-2),CYAN,2,true)

class FactionMark extends Control:
	var index: int = 0
	var tint: Color = CYAN
	func _draw() -> void:
		var center := size/2
		var s: float = minf(size.x,size.y)/48.0
		if index == 0:
			for i in range(3):
				var x: float = float(i-1)*11*s
				var top: float = -18*s if i==1 else -9*s
				draw_polyline(PackedVector2Array([center+Vector2(x-3*s,14*s),center+Vector2(x-3*s,top),center+Vector2(x+3*s,top-4*s),center+Vector2(x+3*s,14*s)]),tint,1.5,true)
			draw_line(center+Vector2(-20,19)*s,center+Vector2(20,19)*s,tint,1.5,true)
		elif index == 1:
			var points := PackedVector2Array([center+Vector2(0,-18)*s,center+Vector2(18,13)*s,center+Vector2(-18,13)*s,center+Vector2(0,-18)*s])
			draw_polyline(points,Color(tint,0.6),1,true)
			for i in range(3): draw_rect(Rect2(points[i]-Vector2(4,4)*s,Vector2(8,8)*s),tint,false,1.5,true)
			draw_circle(center,3*s,tint)
		else:
			draw_polyline(PackedVector2Array([center+Vector2(-17,-14)*s,center+Vector2(0,-21)*s,center+Vector2(17,-14)*s,center+Vector2(12,9)*s,center+Vector2(0,21)*s,center+Vector2(-10,11)*s]),tint,1.5,true)
			draw_line(center+Vector2(-13,9)*s,center+Vector2(12,-8)*s,tint,3,true)
			draw_line(center+Vector2(-7,17)*s,center+Vector2(17,0)*s,Color(tint,0.55),1,true)

class SymbolBadge extends Control:
	var glyph: String = ""
	var badge_font: Font
	var tint := CYAN
	var circular: bool = false
	func _draw() -> void:
		var center := size/2
		var unit: float = minf(size.x,size.y)*0.28
		if circular:
			draw_circle(center,minf(size.x,size.y)/2,Color(tint,0.05))
		else:
			match glyph:
				"扩":
					for x in [-1,1]:
						for y in [-1,1]:
							var corner := center+Vector2(x,y)*unit
							draw_polyline(PackedVector2Array([corner-Vector2(x,0)*unit*0.55,corner,corner-Vector2(0,y)*unit*0.55]),tint,1.5,true)
				"攻":
					draw_arc(center,unit*0.8,0,TAU,32,tint,1.5,true)
					draw_line(center-Vector2(unit*1.3,0),center+Vector2(unit*1.3,0),tint,1,true)
					draw_line(center-Vector2(0,unit*1.3),center+Vector2(0,unit*1.3),tint,1,true)
				"援":
					draw_line(center-Vector2(unit,0),center+Vector2(unit,0),tint,2,true)
					draw_line(center-Vector2(0,unit),center+Vector2(0,unit),tint,2,true)
				"调":
					draw_polyline(PackedVector2Array([center-Vector2(unit,unit*0.6),center+Vector2(unit,unit*0.6),center+Vector2(unit*0.2,-unit)]),tint,1.5,true)
			return
		var font_size: int = int(size.y*(0.55 if circular else 0.5))
		draw_string(badge_font,Vector2(0,size.y*0.5+font_size*0.36),glyph,HORIZONTAL_ALIGNMENT_CENTER,size.x,font_size,tint)

class FrontierIcon extends Control:
	var kind: String = "home"
	var tint: Color = CYAN

	func _draw() -> void:
		var center := size / 2.0
		var radius: float = minf(size.x,size.y) * 0.43
		draw_circle(center,radius,Color(tint,0.08))
		draw_arc(center,radius,0,TAU,32,Color(tint,0.38),1.2,true)
		var u: float = minf(size.x,size.y) * 0.22
		match kind:
			"home":
				var roof := PackedVector2Array([center+Vector2(-u*1.45,0),center,center+Vector2(u*1.45,0)])
				draw_polyline(roof,tint,2,true)
				draw_rect(Rect2(center+Vector2(-u*0.95,0),Vector2(u*1.9,u*1.25)),tint,false,2,true)
				draw_rect(Rect2(center+Vector2(-u*0.22,u*0.48),Vector2(u*0.44,u*0.77)),tint,false,1.5,true)
			"dungeon":
				draw_line(center+Vector2(-u*1.5,u*1.1),center+Vector2(u*1.5,-u*1.1),tint,2,true)
				draw_line(center+Vector2(-u*1.2,-u*1.25),center+Vector2(u*1.2,u*1.25),tint,2,true)
				draw_polyline(PackedVector2Array([center+Vector2(-u*1.45,-u*0.2),center+Vector2(-u*0.35,-u*1.25),center+Vector2(u*0.35,u*0.2),center+Vector2(u*1.45,-u*0.85)]),Color(tint,0.7),1.2,true)
			"gacha":
				draw_circle(center,u*1.2,tint,false,2,true)
				draw_line(center+Vector2(-u*1.8,0),center+Vector2(u*1.8,0),tint,1.5,true)
				draw_line(center+Vector2(0,-u*1.8),center+Vector2(0,u*1.8),tint,1.5,true)
				draw_circle(center,u*0.32,Color(tint,0.8))
			"ship":
				var hull := PackedVector2Array([center+Vector2(-u*1.65,u*0.25),center+Vector2(-u*0.55,-u*0.65),center+Vector2(u*1.45,-u*0.2),center+Vector2(u*0.6,u*0.8),center+Vector2(-u*1.65,u*0.25)])
				draw_polyline(hull,tint,2,true)
				draw_line(center+Vector2(-u*0.45,-u*0.6),center+Vector2(-u*0.45,-u*1.35),tint,1.5,true)
				draw_line(center+Vector2(-u*0.45,-u*1.35),center+Vector2(u*0.55,-u*0.45),tint,1.5,true)
			"welfare":
				draw_rect(Rect2(center-Vector2(u*1.35,u*0.95),Vector2(u*2.7,u*1.9)),tint,false,2,true)
				draw_line(center+Vector2(0,-u*0.95),center+Vector2(0,u*0.95),tint,1.5,true)
				draw_line(center+Vector2(-u*1.35,0),center+Vector2(u*1.35,0),tint,1.5,true)
				draw_circle(center,u*0.25,Color(tint,0.85))

var game := Rules.new()
var screen_state: String = "start"
var faction_index: int = 0
var mode_index: int = 0
var seed_code: String = "TITAN146"
var sandbox_settings: Dictionary = {"limit":12,"resources":100,"fleets":4,"invasion":15,"relations":0}
var selected_planet: String = ""
var selected_fleet: String = ""
var selected_gate: String = ""
var command: String = ""
var message: String = "选择指令后点击星球。"
var auto_save: bool = true
var save_slot: int = 0
var workshop_type: int = 0
var guide_step: int = 0
## A first-play tutorial that uses the real campaign controls.
var tutorial_active: bool = false
var tutorial_step: int = 0
var tutorial_seen: bool = false
var ui_scale: float = 1.0
var shell: MarginContainer
var scroll: ScrollContainer
var page: VBoxContainer
var map_view: StarMap
var modal: Control
var modal_panel: PanelContainer
var toast: PanelContainer
var font_regular: Font
var font_bold: Font
var rebuild_pending: bool = false
var build_size := Vector2.ZERO
var start_footer: VBoxContainer
var toast_seconds: float = 0.0
var reveal_map_pending: bool = false
var save_directory: String = "user://"
var help_mode: bool = false
var help_overlay: Control
var help_target: Control
var help_press_position := Vector2.ZERO
var help_toggles: Array = []
var help_scroll: ScrollContainer
var help_dragging: bool = false
var replay_map: StarMap
var replay_label: Label
var replay_events: Array = []
var replay_index: int = -1
var replay_timer: float = 0.0
var replay_playing: bool = false
var replay_followup: bool = false
var pending_effects: Array = []
var effect_timer: float = 0.0
var music: Music
var music_settings_path: String = "user://audio.cfg"
var duel_network: Node
var duel_panel_open: bool = false
var frontier_tab: int = 0

func _ready() -> void:
	duel_network = preload("res://duel_network.gd").new()
	duel_network.name = "DuelNetwork"
	add_child(duel_network)
	duel_network.changed.connect(_network_changed)
	music = Music.new()
	music.settings_path = music_settings_path
	add_child(music)
	# Bundled OFL font keeps Chinese text identical on machines without CJK fonts.
	var font_file := load("res://assets/fonts/NotoSansSC.ttf") as FontFile
	var regular := FontVariation.new()
	regular.base_font = font_file
	regular.variation_opentype = {2003265652:400.0}
	font_regular = regular
	var bold := FontVariation.new()
	bold.base_font = font_file
	bold.variation_opentype = {2003265652:600.0}
	font_bold = bold
	var base_theme := Theme.new()
	base_theme.default_font = font_regular
	base_theme.default_font_size = 18
	for type_name in ["Label","LineEdit","SpinBox","CheckBox","CheckButton","OptionButton","PopupMenu"]:
		base_theme.set_color("font_color",type_name,TEXT)
		base_theme.set_color("font_hover_color",type_name,CYAN)
	base_theme.set_stylebox("panel","PopupMenu",_style(PANEL,LINE,1,2))
	base_theme.set_stylebox("hover","PopupMenu",_style(INK,LINE,0,4))
	base_theme.set_stylebox("normal","LineEdit",_style(PANEL,LINE,1,4))
	base_theme.set_stylebox("focus","LineEdit",_style(Color(0,0,0,0),CYAN,2,4))
	base_theme.set_stylebox("panel","TooltipPanel",_style(INK,LINE,1,4))
	base_theme.set_color("font_color","TooltipLabel",TEXT)
	base_theme.set_font_size("font_size","TooltipLabel",16)
	# Native dark checkbox art disappears against the blue panels.
	for state_name in ["checked","unchecked","checked_disabled","unchecked_disabled"]:
		var checked: bool = state_name.begins_with("checked")
		var disabled_icon: bool = state_name.ends_with("disabled")
		var border: String = "60758e" if disabled_icon else "7bbdd3"
		var fill: String = "174d70" if checked else "091c32"
		var mark: String = '<path d="M5 10L8.5 13.5 15 6.5" fill="none" stroke="#e1e9f3" stroke-width="2"/>' if checked else ""
		var icon_image := Image.new()
		icon_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect x="1" y="1" width="18" height="18" rx="2" fill="#%s" stroke="#%s"/>%s</svg>' % [fill,border,mark])
		base_theme.set_icon(state_name,"CheckBox",ImageTexture.create_from_image(icon_image))
	for part in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var scrollbar_style := StyleBoxFlat.new()
		scrollbar_style.bg_color = BG if part == "scroll" else (Color("425a76") if part == "grabber" else CYAN)
		scrollbar_style.set_corner_radius_all(4)
		scrollbar_style.content_margin_left = 4
		scrollbar_style.content_margin_right = 4
		base_theme.set_stylebox(part,"VScrollBar",scrollbar_style)
	theme = base_theme
	RenderingServer.set_default_clear_color(BG)
	resized.connect(_on_resize)
	var onboarding := ConfigFile.new()
	if onboarding.load(save_directory.path_join("onboarding.cfg")) == OK:
		tutorial_seen = bool(onboarding.get_value("tutorial","seen",false))
	_build()

func _process(delta: float) -> void:
	if is_instance_valid(toast) and toast.visible:
		toast_seconds -= delta
		if toast_seconds <= 0: toast.hide()
	if replay_playing and is_instance_valid(replay_map) and not is_instance_valid(help_overlay):
		replay_timer -= delta
		if replay_timer <= 0: _replay_step()
	if not pending_effects.is_empty() and is_instance_valid(map_view):
		effect_timer -= delta
		if effect_timer <= 0:
			map_view.play_effect(pending_effects.pop_front())
			effect_timer = 0.95

func _on_resize() -> void:
	queue_redraw()
	if size.distance_to(build_size) > 2: _schedule_build()
	if is_instance_valid(modal): _layout_modal.call_deferred()
	if is_instance_valid(help_overlay): _layout_help.call_deferred()

func _schedule_build() -> void:
	if rebuild_pending: return
	rebuild_pending = true
	_build.call_deferred()

func _build() -> void:
	rebuild_pending = false
	var old_scroll: int = scroll.scroll_vertical if is_instance_valid(scroll) else 0
	var old_zoom: float = map_view.zoom if is_instance_valid(map_view) else 1.0
	var old_pan: Vector2 = map_view.pan if is_instance_valid(map_view) else Vector2.ZERO
	if is_instance_valid(shell):
		remove_child(shell)
		shell.queue_free()
	map_view = null
	build_size = size
	ui_scale = clampf(minf(size.x,1080) / 960.0,1.0,1.12)
	shell = MarginContainer.new()
	add_child(shell)
	# Rebuilding the page must not cover an already-open confirmation dialog.
	move_child(shell,0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The campaign deck is designed to use a landscape monitor edge to edge;
	# keep the start screen's readable max width while giving the map the room it needs.
	var outer: int = 0 if screen_state == "game" and _desktop_game_layout() else maxi(0,int((size.x-1080)/2))
	shell.add_theme_constant_override("margin_left",outer)
	shell.add_theme_constant_override("margin_right",outer)
	var layout := _vbox(shell,0)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	start_footer = null
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	layout.add_child(scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation",0)
	scroll.add_child(page)
	if screen_state == "start":
		_build_start()
		_build_start_footer(layout)
	else:
		_build_game()
		if tutorial_active: _tutorial_banner(layout)
	_build_help_bar(layout)
	if is_instance_valid(map_view):
		map_view.zoom = old_zoom
		map_view.pan = old_pan
	scroll.set_deferred("scroll_vertical",old_scroll)
	if reveal_map_pending and is_instance_valid(map_view):
		reveal_map_pending = false
		_reveal_map.call_deferred()
	queue_redraw()

func _reveal_map() -> void:
	await get_tree().process_frame
	if is_instance_valid(map_view) and is_instance_valid(scroll):
		scroll.ensure_control_visible(map_view)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),BG)

func _style(bg: Color = PANEL, border: Color = LINE, width: int = 1, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(mini(radius,2))
	style.corner_detail = 8
	style.content_margin_left = 16 * ui_scale
	style.content_margin_right = 16 * ui_scale
	style.content_margin_top = 12 * ui_scale
	style.content_margin_bottom = 12 * ui_scale
	return style

func _vbox(parent: Node, gap: int = 14) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",int(gap * ui_scale))
	parent.add_child(box)
	return box

func _row(parent: Node, gap: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",int(gap * ui_scale))
	parent.add_child(box)
	return box

func _label(parent: Node, value: String, font_size: int = 18, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",int(font_size * ui_scale))
	l.add_theme_color_override("font_color",color)
	l.add_theme_font_override("font",font_bold if bold else font_regular)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, value: String, callback: Callable, primary: bool = false, tint: Color = CYAN) -> Button:
	var button := Button.new()
	button.text = value
	button.clip_text = true
	if value != "": button.custom_minimum_size.x = minf(200*ui_scale,font_bold.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,int(18*ui_scale)).x+32*ui_scale)
	button.custom_minimum_size.y = 66 * ui_scale
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",int(18 * ui_scale))
	button.add_theme_font_override("font",font_bold)
	for state_name in ["normal","hover","pressed","disabled"]:
		var colors: Dictionary = {"normal":ACCENT if primary else INK,"hover":Color("205f80") if primary else Color("173b56"),"pressed":Color("123b58") if primary else Color("0b243b"),"disabled":Color("0b1d30")}
		var style := _style(colors[state_name],CYAN if primary and state_name == "hover" else (tint if state_name == "hover" else LINE),1,4)
		if value != "":
			style.content_margin_top = 8*ui_scale
			style.content_margin_bottom = 30*ui_scale
		button.add_theme_stylebox_override(state_name,style)
	button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),tint,2))
	button.add_theme_color_override("font_color",TEXT)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_color_override("font_pressed_color",TEXT)
	button.add_theme_color_override("font_disabled_color",MUTED)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	if value != "":
		var entry: Array = Help.entry(value)
		if entry.is_empty():
			push_warning("Missing button description: " + value)
		else:
			_describe_button(button,str(entry[0]),str(entry[1]),primary)
			button.custom_minimum_size.x = maxf(button.custom_minimum_size.x,minf(110*ui_scale,font_regular.get_string_size(str(entry[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*ui_scale)).x+24*ui_scale))
	return button

func _describe_button(button: Button, summary: String, detail: String, primary: bool = false) -> void:
	button.set_meta("help_title",button.text)
	button.set_meta("help_detail",detail)
	button.tooltip_text = button.text + "\n" + _wrap_help(detail)
	var caption := button.get_node_or_null("ActionCaption") as Label
	if caption == null:
		caption = Label.new()
		caption.name = "ActionCaption"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_left = 8*ui_scale
		caption.offset_right = -8*ui_scale
		caption.offset_top = -28*ui_scale
		caption.offset_bottom = -7*ui_scale
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.add_theme_font_size_override("font_size",int(14*ui_scale))
	caption.add_theme_color_override("font_color",Color("d2e3f7") if primary and not button.disabled else MUTED)
	caption.text = summary

func _describe_control(control: Control, title: String, detail: String) -> void:
	control.set_meta("help_title",title)
	control.set_meta("help_detail",detail)
	control.tooltip_text = title + "\n" + _wrap_help(detail)

func _wrap_help(detail: String) -> String:
	var lines: PackedStringArray = []
	for paragraph in detail.split("\n"):
		for start in range(0,paragraph.length(),26): lines.append(paragraph.substr(start,26))
	return "\n".join(lines)

func _build_help_bar(parent: Node) -> void:
	var panel := PanelContainer.new()
	var style := _style(BG,LINE,0,0)
	style.border_width_top = 1
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var row := _row(panel,10)
	var toggle := Button.new()
	toggle.text = "返回操作" if help_mode else "？ 说明模式"
	toggle.custom_minimum_size = Vector2(120,34)*ui_scale
	toggle.add_theme_font_size_override("font_size",int(15*ui_scale))
	toggle.add_theme_stylebox_override("normal",_style(ACCENT if help_mode else PANEL,LINE,1,4))
	toggle.add_theme_stylebox_override("hover",_style(INK,CYAN,1,4))
	toggle.add_theme_color_override("font_color",TEXT)
	toggle.add_theme_color_override("font_hover_color",TEXT)
	toggle.set_meta("help_toggle",true)
	_describe_control(toggle,"说明模式","开启后点击任意按钮只查看说明，不执行操作；再次点击此按钮返回正常操作。也可以悬停查看按钮提示。")
	toggle.pressed.connect(func() -> void:
		help_mode = not help_mode
		help_target = null
		for item in help_toggles:
			if is_instance_valid(item): item.text = "返回操作" if help_mode else "？ 说明模式")
	row.add_child(toggle)
	help_toggles = help_toggles.filter(func(item) -> bool: return is_instance_valid(item))
	help_toggles.append(toggle)
	if size.x >= 650: _label(row,"开启后点按钮查看详情 · 悬停也可查看",12,MUTED)
	# Keep access on the main page; opening settings must not discard another modal's draft.
	if parent == shell.get_child(0):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var audio := Button.new()
		audio.text = "音乐设置"
		audio.custom_minimum_size = Vector2(100,34)*ui_scale
		audio.add_theme_font_size_override("font_size",int(15*ui_scale))
		audio.add_theme_stylebox_override("normal",_style(PANEL,LINE,1,2))
		audio.add_theme_stylebox_override("hover",_style(INK,CYAN,1,2))
		_describe_control(audio,"音乐设置","开关原创背景音乐《深蓝守望》并调整音量；设置自动保存在本机，不影响战役进度。")
		audio.pressed.connect(_music_dialog)
		row.add_child(audio)

func _music_dialog() -> void:
	var dialog := _open_modal("音乐设置")
	_label(dialog,"深蓝守望",23,TEXT,true)
	_label(dialog,"原创深空氛围曲 · 1 分 20 秒循环\n缓慢和弦、低频脉冲与电子旋律。",17,MUTED)
	var toggle := CheckBox.new()
	toggle.text = "播放背景音乐"
	toggle.button_pressed = music.enabled
	toggle.custom_minimum_size.y = 48*ui_scale
	dialog.add_child(toggle)
	_describe_control(toggle,"播放背景音乐","勾选播放，取消勾选暂停；恢复时从暂停处继续。开关设置在下次启动时保留。")
	toggle.toggled.connect(func(value: bool) -> void:
		if music.set_enabled(value) != OK: _notify("音乐开关已生效，但无法保存到本机。",true))
	var level := _label(dialog,"音乐音量  %d%%" % roundi(music.volume*100),18,CYAN)
	var slider := HSlider.new()
	slider.name = "MusicVolume"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundi(music.volume*100)
	slider.custom_minimum_size.y = 48*ui_scale
	dialog.add_child(slider)
	_describe_control(slider,"音乐音量","拖动或使用方向键调节音乐音量，0% 静音。音量自动保存在本机，不改变音乐开关状态。")
	slider.value_changed.connect(func(value: float) -> void:
		level.text = "音乐音量  %d%%" % roundi(value)
		if music.set_volume(value/100.0) != OK: _notify("音量已生效，但无法保存到本机。",true))
	_label(dialog,"音乐随游戏离线运行。切换页面和重开战役时连续播放。",16,MUTED)

func _help_hit(node: Node, point: Vector2) -> Control:
	if node is Control:
		if not node.is_visible_in_tree(): return null
		if node.clip_contents and not node.get_global_rect().has_point(point): return null
	var children: Array[Node] = node.get_children()
	children.reverse()
	for child in children:
		var result: Control = _help_hit(child,point)
		if result != null: return result
	if node is Control and node.has_meta("help_detail") and node.get_global_rect().has_point(point): return node
	return null

func _input(event: InputEvent) -> void:
	if is_instance_valid(help_overlay): return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null and focus.has_meta("help_detail") and not focus.has_meta("help_toggle"):
			if event.keycode == KEY_F1 or (help_mode and event.is_action_pressed("ui_accept")):
				_show_help(focus)
				get_viewport().set_input_as_handled()
		return
	if not help_mode: return
	if event is InputEventScreenDrag and is_instance_valid(help_target):
		if event.position.distance_to(help_press_position) > 14: help_dragging = true
		if help_dragging and is_instance_valid(help_scroll): help_scroll.scroll_vertical -= int(event.relative.y)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton or event is InputEventScreenTouch): return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT: return
	var target: Control = _help_hit(modal if is_instance_valid(modal) else shell,event.position)
	if target != null and target.has_meta("help_toggle"): return
	if event is InputEventMouse and event.device == -1:
		get_viewport().set_input_as_handled()
		return
	if event.is_pressed():
		help_target = target
		help_press_position = event.position
		help_dragging = false
		help_scroll = null
		if target == null: return
		var ancestor: Node = target.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				help_scroll = ancestor
				break
			ancestor = ancestor.get_parent()
	elif is_instance_valid(help_target):
		if not help_dragging and target == help_target and event.position.distance_to(help_press_position) < 14:
			if not (event is InputEventScreenTouch and event.canceled): _show_help(help_target)
		help_target = null
	else: return
	get_viewport().set_input_as_handled()

func _show_help(control: Control) -> void:
	if is_instance_valid(help_overlay): return
	help_overlay = Control.new()
	help_overlay.name = "ButtonExplanation"
	add_child(help_overlay)
	help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.06,0.10,0.18,0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "ExplanationPanel"
	panel.add_theme_stylebox_override("panel",_style(PANEL,LINE,1,4))
	help_overlay.add_child(panel)
	var box := _vbox(panel,16)
	_label(box,"操作说明",14,MUTED)
	_label(box,str(control.get_meta("help_title")),26,TEXT,true)
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroller)
	var text_box := _vbox(scroller,12)
	_label(text_box,str(control.get_meta("help_detail")),19,TEXT)
	if control is BaseButton and control.disabled: _label(text_box,"当前不可用，请检查上方的条件或按钮上的状态。",16,RED,true)
	_label(text_box,"查看说明不会执行操作，也不会扣除资源。",14,MUTED)
	_button(box,"收起说明",_close_help,true)
	_layout_help()

func _layout_help() -> void:
	if not is_instance_valid(help_overlay): return
	var panel := help_overlay.get_node("ExplanationPanel") as PanelContainer
	panel.size = Vector2(minf(600,size.x-32),minf(440,size.y-48))
	panel.position = (size-panel.size)/2

func _close_help() -> void:
	if is_instance_valid(help_overlay):
		remove_child(help_overlay)
		help_overlay.queue_free()
	help_overlay = null

func _space(parent: Node, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height * ui_scale
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func _line(parent: Node) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = LINE
	style.thickness = 1
	line.add_theme_stylebox_override("separator",style)
	parent.add_child(line)

func _section(parent: Node, heading: String, subtitle: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	var section_style := _style(PANEL,LINE,0,0)
	panel.add_theme_stylebox_override("panel",section_style)
	parent.add_child(panel)
	var box := _vbox(panel,8 if heading == "" else 12)
	var row := _row(box)
	_label(row,heading,20,TEXT,true)
	if subtitle != "":
		var sub := _label(row,subtitle,15,MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if heading != "": _space(box,4)
	return box

func _option(parent: Node, items: Array, selected: int, callback: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	option.custom_minimum_size.y = 50 * ui_scale
	option.add_theme_font_size_override("font_size",int(18*ui_scale))
	option.add_theme_stylebox_override("normal",_style())
	option.add_theme_stylebox_override("hover",_style(PANEL,CYAN))
	option.add_theme_color_override("font_color",TEXT)
	for item in items: option.add_item(str(item))
	var title: String = "选择选项"
	var detail: String = "展开列表选择一项，当前选项显示在按钮内。"
	if items == Rules.MODES:
		title = "战役模式"
		detail = "选择胜利目标与扩展规则。沙盒可自定义资源、单位和入侵概率。"
		for i in range(items.size()): option.get_popup().set_item_tooltip(i,Rules.MODE_HELP[i])
	elif str(items[0]).begins_with("槽位"):
		title = "存档槽位"
		detail = "选择保存、读取或删除所用的手动槽。切换槽位本身不会读写存档。"
	elif str(items[0]).begins_with("突击"):
		title = "舰队类型"
		detail = "突击擅长进攻，守卫擅长防守，劫掠与侦察节省燃料，运输可携带物资。选择后仍需购买或保存配置。"
	elif items[0] == "楔形":
		title = "舰队标记"
		detail = "选择星图上的舰队图标，只改变外观；保存配置后应用。"
	elif items[0] == "信用点":
		title = "补给种类"
		detail = "选择要装载或卸载的物资，再设置数量并点击装卸按钮。"
	elif items[0] in Rules.FACTIONS:
		title = "外交对象"
		detail = "选择外交行动的目标势力。切换对象不会消耗本轮外交机会。"
	_describe_control(option,title,detail)
	for i in range(items.size()):
		if items != Rules.MODES: option.get_popup().set_item_tooltip(i,_wrap_help(str(items[i])+"："+detail))
	option.select(selected)
	option.item_selected.connect(callback)
	parent.add_child(option)
	return option

func _build_start() -> void:
	var wide: bool = size.x >= 900
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",int(24*ui_scale))
	margin.add_theme_constant_override("margin_right",int(24*ui_scale))
	margin.add_theme_constant_override("margin_top",int(28*ui_scale))
	margin.add_theme_constant_override("margin_bottom",int(24*ui_scale))
	page.add_child(margin)
	var columns: BoxContainer = _row(margin,32) if wide else _vbox(margin,24)
	var box := _vbox(columns,6)
	box.size_flags_stretch_ratio = 0.95
	_label(box,"单人战役",16,MUTED)
	var hero := HeroTitle.new()
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.title_font = font_bold
	hero.custom_minimum_size.y = clampf(size.y*0.10,82,98)*ui_scale
	hero.resized.connect(hero.queue_redraw)
	box.add_child(hero)
	_space(box,8)
	_label(box,"本局星图代码",18,MUTED)
	var code_row := _row(box)
	var code := LineEdit.new()
	code.text = seed_code
	code.max_length = 24
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.custom_minimum_size.y = 52*ui_scale
	code.add_theme_font_size_override("font_size",int(26*ui_scale))
	code.add_theme_stylebox_override("normal",_style(PANEL,LINE,1,4))
	code.add_theme_color_override("font_color",TEXT)
	code.text_changed.connect(func(value: String) -> void: seed_code = value.strip_edges() if not value.strip_edges().is_empty() else "TITAN146")
	code_row.add_child(code)
	_describe_control(code,"星图代码","输入最多 24 个字符，相同代码生成相同初始星图。换一组可随机生成新代码。")
	var change := _button(code_row,"换一组",func() -> void:
		seed_code = "GATE%d" % randi_range(100,9999)
		code.text = seed_code)
	change.size_flags_horizontal = Control.SIZE_SHRINK_END
	var factions := _vbox(columns,14)
	factions.size_flags_stretch_ratio = 1.05
	_label(factions,"选择阵营",21,TEXT,true)
	_label(factions,"其余阵营由电脑控制",16,MUTED)
	for i in range(3):
		_faction_card(factions,i)
	# On desktop, settings share the title column. On mobile they follow factions.
	var advanced := _section(box if wide else columns,"战役模式","")
	_option(advanced,Rules.MODES,mode_index,func(index: int) -> void:
		mode_index = index
		_schedule_build())
	_label(advanced,Rules.MODE_HELP[mode_index],16,MUTED)
	if mode_index == 7:
		for key in ["limit","resources","fleets","invasion","relations"]:
			var names: Dictionary = {"limit":"回合记录长度","resources":"初始资源","fleets":"每队初始单位","invasion":"每轮入侵概率 %","relations":"初始好感"}
			var row := _row(advanced)
			_label(row,str(names[key]),16,MUTED)
			var spin := SpinBox.new()
			spin.min_value = -100 if key == "relations" else 0
			spin.max_value = 999 if key == "resources" else 100
			spin.value = float(sandbox_settings[key])
			spin.value_changed.connect(func(value: float) -> void: sandbox_settings[key] = int(value))
			row.add_child(spin)
			_describe_control(spin,str(names[key]),"调整沙盒的%s；只在开启新战役时应用，不会改变已有存档。" % names[key])
	var systems := _vbox(box if wide else columns,4)
	_label(systems,"银河中心 · 点击图标进入",16,CYAN,true)
	var icon_grid := GridContainer.new()
	icon_grid.columns = 5 if wide else 3
	icon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_grid.add_theme_constant_override("h_separation",int(8*ui_scale))
	icon_grid.add_theme_constant_override("v_separation",int(8*ui_scale))
	systems.add_child(icon_grid)
	_icon_button(icon_grid,"家园","home","升级建筑并领取每轮资源产出",0)
	_icon_button(icon_grid,"副本","dungeon","挑战副本，获得星币、材料与阵营功勋",1)
	_icon_button(icon_grid,"抽奖","gacha","使用星币抽取战舰与工程材料",3)
	_icon_button(icon_grid,"战舰","ship","查看等级、星级、直购与部署",2)
	_icon_button(icon_grid,"福利","welfare","领取签到、舰队援助与远征里程奖励",5)

func _build_start_footer(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(BG,LINE,1,0))
	parent.add_child(panel)
	start_footer = _vbox(panel,8)
	var buttons := _row(start_footer,10)
	_button(buttons,"开启星门",_start_campaign,true)
	_button(buttons,"新手教学",_start_practice_tutorial)
	_button(buttons,"读取本地战役",_load_dialog)
	_net_button(start_footer,"真人联网单挑","选择阵营，与朋友直连单挑",_network_dialog)
	if not tutorial_seen:
		_label(start_footer,"首次开启：先在实战中学习操作，完成后可继续或开始所选模式。",14,CYAN)
	if OS.get_cmdline_args().has("--embedded"):
		var input_hint := _label(start_footer,"按钮无反应？点运行窗口顶部「输入」；「2D / 3D」是调试选择模式。",14,CYAN)
		input_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _faction_card(parent: Node, index: int) -> void:
	var faction: String = Rules.FACTIONS[index]
	var tint := Color(Rules.COLORS[faction])
	var button := _button(parent,"",func() -> void:
		faction_index = index
		_schedule_build(),false,tint)
	button.set_meta("faction_index",index)
	button.custom_minimum_size.y = 116 * ui_scale
	var card_style := _style(INK if index == faction_index else PANEL,LINE,0,0)
	card_style.border_width_bottom = 1
	card_style.border_width_left = 2 if index == faction_index else 0
	if index == faction_index: card_style.border_color = CYAN
	button.add_theme_stylebox_override("normal",card_style)
	button.add_theme_stylebox_override("hover",_style(Color("12334e"),CYAN,1,2))
	button.add_theme_stylebox_override("pressed",_style(INK,CYAN,1,4))
	_describe_control(button,FACTION_TITLES[index],"选择此阵营。%s；%s。仅改变开场选择，点击「开启星门」才创建战役。" % [FACTION_DESCRIPTIONS[index],FACTION_BONUSES[index]])
	var margin := MarginContainer.new()
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",int(16*ui_scale))
	margin.add_theme_constant_override("margin_right",int(16*ui_scale))
	var row := _row(margin,12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := FactionMark.new()
	badge.index = index
	badge.tint = tint
	badge.custom_minimum_size = Vector2(48,48)*ui_scale
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var texts := _vbox(row,6)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(texts,FACTION_TITLES[index],21,TEXT,true)
	_label(texts,FACTION_DESCRIPTIONS[index],16,MUTED)
	_label(texts,("已选择 · " if index == faction_index else "")+FACTION_BONUSES[index],14,tint)

func _start_campaign() -> void:
	if not tutorial_seen:
		_start_practice_tutorial()
		return
	tutorial_active = false
	game.new_game(Rules.FACTIONS[faction_index],mode_index,seed_code,sandbox_settings if mode_index == 7 else {})
	screen_state = "game"
	selected_planet = ""
	selected_fleet = ""
	selected_gate = ""
	command = ""
	message = "轮到你行动。选择指令后点击星球。"
	if is_instance_valid(scroll): scroll.scroll_vertical = 0
	_autosave()
	_schedule_build()

func _open_frontier_hub(tab: int) -> void:
	if game.state.is_empty():
		game.new_game(Rules.FACTIONS[faction_index],mode_index,seed_code,sandbox_settings if mode_index == 7 else {})
		screen_state = "game"
		tutorial_active = false
		selected_planet = ""
		selected_fleet = ""
		selected_gate = ""
		command = ""
		message = "已进入银河中心。"
		_autosave()
		_schedule_build()
	frontier_tab = tab
	_frontier_dialog.call_deferred()

func _build_game() -> void:
	var frontier_nav := _row(page)
	_net_button(frontier_nav,"远征与家园","副本 / 家园 / 抽奖 / 战舰",_frontier_dialog)
	_net_button(frontier_nav,"真人联网单挑","双方通过地址直连，选择阵营进行真人对战",_network_dialog)
	if _desktop_game_layout():
		_build_game_desktop()
		return
	var header := _section(page,"","")
	header.get_child(0).queue_free()
	var nav := _row(header)
	var guide := _button(nav,"新手指南",_tutorial_help)
	var title := _label(nav,"星门纪元\n银河分裂",19,TEXT,true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var restart := _button(nav,"重开",_restart_dialog)
	# On a phone the three navigation controls share the narrow viewport.  Let
	# the row distribute the available width instead of preserving desktop
	# minimums, which otherwise makes the whole page wider than the window.
	if size.x < 600:
		guide.custom_minimum_size.x = 0
		restart.custom_minimum_size.x = 0
		title.custom_minimum_size.x = 0
		title.add_theme_font_size_override("font_size",16)
	var stats := _row(header,0)
	var data: Array = [["剩余行动",str(game.state.ap)],["我的星球",str(game.owned().size())],["星币",str(game.res().credits)],["材料",str(game.res().materials)]]
	for entry in data:
		var col: BoxContainer = _row(stats,8) if size.x >= 800 else _vbox(stats,4)
		var name_label := _label(col,str(entry[0]),17,MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var value_label := _label(col,str(entry[1]),27,TEXT,true)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cycle := _row(header)
	_label(cycle,"战争周期",18,MUTED)
	var cycle_label := _label(cycle,"%d / %s" % [int(game.state.turn),"∞" if game.state.mode == 7 else str(game.state.limit)],24,CYAN,true)
	cycle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_line(page)
	var legend_box := _section(page,"","")
	legend_box.get_child(0).queue_free()
	# Five faction labels cannot fit as one unbroken row on a phone.  A small
	# three-column grid keeps the game page inside the viewport while retaining
	# the same compact legend on desktop.
	var legend: Container = GridContainer.new() if size.x < 600 else _row(legend_box,6)
	if size.x < 600:
		legend.columns = 3
		legend.add_theme_constant_override("h_separation",4)
		legend.add_theme_constant_override("v_separation",2)
		legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		legend_box.add_child(legend)
	for faction in ["帝国","联盟","混沌","无主","外星"]:
		var item := _label(legend,"● " + faction,16,Color(Rules.COLORS[faction]))
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL if size.x < 600 else Control.SIZE_SHRINK_BEGIN
		item.custom_minimum_size.x = (0 if size.x < 600 else 80)*ui_scale
	if int(game.state.invasion) > 0:
		_label(legend_box,"外星警报  ·  入侵 %d 波 / 已摧毁核心 %d" % [int(game.state.invasion),int(game.state.cores_destroyed)],17,RED,true)
	map_view = StarMap.new()
	# Keep the entire galaxy below the HUD in the initial viewport.
	map_view.height_limit = maxf(280,size.y-(590 if tutorial_active else 370)*ui_scale)
	map_view.game = game
	map_view.selected_planet = selected_planet
	map_view.selected_fleet = selected_fleet
	map_view.selected_gate = selected_gate
	map_view.command = command
	if tutorial_active: map_view.tutorial_target = _tutorial_target()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(map_view)
	_describe_control(map_view,"星图","点击星球查看驻军，选中指令后选择目标；拖动空白平移，滚轮或双指缩放，拖动己方舰队可预览移动。")
	map_view.target_selected.connect(_on_target)
	map_view.fleet_dropped.connect(_on_drop)
	map_view.fleet_menu.connect(func(id: String) -> void:
		selected_fleet = id
		_fleet_dialog(id))
	var status := _section(page,"","")
	status.get_child(0).queue_free()
	var status_row := _row(status)
	_label(status_row,"轮到你行动" if game.state.phase == "player" else "战役已结束",16,MUTED)
	var glow := _label(status_row,"框选标记为指令目标",16,CYAN)
	glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var zoom_row := _row(status)
	if size.x >= 600: _label(zoom_row,"拖动空白平移 · 双指 / 滚轮缩放",14,MUTED)
	for spec in [["－",0.85],["＋",1.15]]:
		var button := _button(zoom_row,str(spec[0]),func() -> void: map_view.zoom_by(float(spec[1])))
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var reset := _button(zoom_row,"归位",func() -> void: map_view.reset_view())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	_label(status,"迷雾：? 为未识别兵力；暗色星球和空心舰标是旧情报。侦察可更新。",14,MUTED)
	var intelligence := _row(status,8)
	_button(intelligence,"主动扫描",func() -> void: _confirm_action("主动扫描","1 行动 / 2 情报；需要侦察舰或侦察模块。扫描持续至下一轮，自身也会暴露。","scan",{"fleet":selected_fleet}))
	_button(intelligence,"战况回放",func() -> void: _show_replay(false))
	_button(intelligence,"战役事务",_story_dialog)
	if int(game.state.mode)==8:
		_label(status,"第 %d 章 · %s\n%s" % [int(game.state.series.chapter),Systems.CHAPTERS[int(game.state.series.chapter)-1].name,Systems.CHAPTERS[int(game.state.series.chapter)-1].goal],16,CYAN)
	if str(game.state.story.pending)!="": _label(status,"有待处理事件："+str(Systems.story_info(str(game.state.story.pending)).title),16,ORANGE)
	_line(page)
	var commands := _section(page,"战术指令","选择指令后点击星球")
	var command_grid := GridContainer.new()
	command_grid.columns = 2 if size.x >= 800 else 1
	command_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_grid.add_theme_constant_override("h_separation",int(10*ui_scale))
	command_grid.add_theme_constant_override("v_separation",int(10*ui_scale))
	commands.add_child(command_grid)
	for entry in [["expand","扩","扩张","占领相邻的灰色星球"],["attack","攻","进攻","攻击相邻的敌方星球"],["reinforce","援","增援","让己方星球舰队 +1"],["dispatch","调","舰队调度","选择舰队，再点任意星球"]]:
		_command_card(command_grid,entry)
	var message_panel := PanelContainer.new()
	var message_style := _style(INK,CYAN,0,4)
	message_style.border_width_left = 3
	message_panel.add_theme_stylebox_override("panel",message_style)
	commands.add_child(message_panel)
	_label(message_panel,message,18,MUTED)
	_skills(commands)
	_line(page)
	_diplomacy_section()
	_line(page)
	_workshop_section()
	_line(page)
	_saves_section()
	var finish := _section(page,"","")
	finish.get_child(0).queue_free()
	var end := _button(finish,"结束本轮",_end_turn_dialog,true)
	end.custom_minimum_size.y = 72*ui_scale
	end.disabled = game.state.phase != "player"
	if end.disabled: end.get_node("ActionCaption").add_theme_color_override("font_color",MUTED)
	_line(page)
	var sequence := _section(page,"行动序列","")
	var row := _row(sequence,2)
	for f in ["帝国","联盟","混沌"]:
		var b := _button(row,f,func() -> void: _faction_manual(f),false,Color(Rules.COLORS[f]))
		if f == game.state.player: b.add_theme_color_override("font_color",CYAN)
	_line(page)
	_planet_section()
	_line(page)
	_fleets_section()
	_line(page)
	_gate_section()
	_line(page)
	_campaign_section()
	_line(page)
	_frontier_section()
	_space(page,40)

func _desktop_game_layout() -> bool:
	# A wide monitor has enough horizontal space for a map-first command deck.
	return size.x >= 1050 and size.x / maxf(size.y,1.0) >= 1.35

func _build_game_desktop() -> void:
	var header := _section(page,"","")
	header.get_child(0).queue_free()
	var nav := _row(header,16)
	var guide := _button(nav,"新手指南",_tutorial_help)
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label(nav,"星门纪元  ·  银河分裂",22,TEXT,true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var restart := _button(nav,"重开",_restart_dialog)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats := _row(header,18)
	var data: Array = [["剩余行动",str(game.state.ap),CYAN],["我的星球",str(game.owned().size()),TEXT],["星币",str(game.res().credits),ORANGE],["材料",str(game.res().materials),PURPLE],["战争周期","%d / %s" % [int(game.state.turn),"∞" if game.state.mode == 7 else str(game.state.limit)],CYAN]]
	for entry in data:
		var col := _vbox(stats,2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := _label(col,str(entry[0]),14,MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var value_label := _label(col,str(entry[1]),22,entry[2],true)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var legend := _row(header,10)
	for faction in ["帝国","联盟","混沌","无主","外星"]:
		var item := _label(legend,"● " + faction,14,Color(Rules.COLORS[faction]))
		item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		item.custom_minimum_size.x = 70*ui_scale
	if int(game.state.invasion) > 0:
		var warning := _label(legend,"外星警报  ·  %d 波 / 核心 %d" % [int(game.state.invasion),int(game.state.cores_destroyed)],14,RED,true)
		warning.size_flags_horizontal = Control.SIZE_SHRINK_END

	var body := _row(page,14)
	body.custom_minimum_size.y = maxf(440,(size.y-270*ui_scale))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_col := _vbox(body,0)
	map_col.size_flags_stretch_ratio = 2.35
	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_style := _style(Color("061528"),LINE,1,0)
	map_style.content_margin_left = 0
	map_style.content_margin_right = 0
	map_style.content_margin_top = 0
	map_style.content_margin_bottom = 0
	map_frame.add_theme_stylebox_override("panel",map_style)
	map_col.add_child(map_frame)
	map_view = StarMap.new()
	map_view.height_limit = maxf(360,size.y-270*ui_scale)
	map_view.game = game
	map_view.selected_planet = selected_planet
	map_view.selected_fleet = selected_fleet
	map_view.selected_gate = selected_gate
	map_view.command = command
	if tutorial_active: map_view.tutorial_target = _tutorial_target()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_child(map_view)
	_describe_control(map_view,"星图","点击星球查看驻军，选中指令后选择目标；拖动空白平移，滚轮或双指缩放，拖动己方舰队可预览移动。")
	map_view.target_selected.connect(_on_target)
	map_view.fleet_dropped.connect(_on_drop)
	map_view.fleet_menu.connect(func(id: String) -> void:
		selected_fleet = id
		_fleet_dialog(id))
	var map_hint := _label(map_col,"拖动空白平移  ·  滚轮 / 双指缩放  ·  点击星球查看详情",13,MUTED)
	map_hint.custom_minimum_size.y = 28*ui_scale
	map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var side_col := _vbox(body,10)
	side_col.custom_minimum_size.x = clampf(size.x*0.29,360,430)
	side_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	var side_scroll := ScrollContainer.new()
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_col.add_child(side_scroll)
	var side := _vbox(side_scroll,10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_desktop_tactical_panel(side)
	var end := _button(side_col,"结束本轮",_end_turn_dialog,true)
	end.custom_minimum_size.y = 64*ui_scale
	end.disabled = game.state.phase != "player"
	if end.disabled: end.get_node("ActionCaption").add_theme_color_override("font_color",MUTED)

	_line(page)
	_diplomacy_section()
	_line(page)
	_workshop_section()
	_line(page)
	_saves_section()
	_line(page)
	_planet_section()
	_line(page)
	_fleets_section()
	_line(page)
	_gate_section()
	_line(page)
	_campaign_section()
	_line(page)
	_frontier_section()
	_space(page,40)

func _build_desktop_tactical_panel(parent: Node) -> void:
	var status := _section(parent,"当前战术面板","")
	status.get_child(0).queue_free()
	var status_row := _row(status,6)
	_label(status_row,"轮到你行动" if game.state.phase == "player" else "战役已结束",16,MUTED)
	var glow := _label(status_row,"框选标记为指令目标",14,CYAN)
	glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var zoom_row := _row(status,6)
	_label(zoom_row,"视图",14,MUTED)
	for spec in [["－",0.85],["＋",1.15]]:
		var button := _button(zoom_row,str(spec[0]),func() -> void: map_view.zoom_by(float(spec[1])))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset := _button(zoom_row,"归位",func() -> void: map_view.reset_view())
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(status,"迷雾：? 为未识别兵力；暗色星球和空心舰标是旧情报。侦察可更新。",13,MUTED)
	var intelligence := _row(status,6)
	_button(intelligence,"主动扫描",func() -> void: _confirm_action("主动扫描","1 行动 / 2 情报；需要侦察舰或侦察模块。扫描持续至下一轮，自身也会暴露。","scan",{"fleet":selected_fleet}))
	_button(intelligence,"战况回放",func() -> void: _show_replay(false))
	_button(intelligence,"战役事务",_story_dialog)
	if int(game.state.mode) == 8:
		_label(status,"第 %d 章 · %s\n%s" % [int(game.state.series.chapter),Systems.CHAPTERS[int(game.state.series.chapter)-1].name,Systems.CHAPTERS[int(game.state.series.chapter)-1].goal],14,CYAN)
	if str(game.state.story.pending) != "":
		_label(status,"有待处理事件：" + str(Systems.story_info(str(game.state.story.pending)).title),14,ORANGE)

	var commands := _section(parent,"战术指令","先选指令，再点星图目标")
	var command_grid := GridContainer.new()
	command_grid.columns = 1
	command_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_grid.add_theme_constant_override("h_separation",int(8*ui_scale))
	command_grid.add_theme_constant_override("v_separation",int(8*ui_scale))
	commands.add_child(command_grid)
	for entry in [["expand","扩","扩张","占领相邻的灰色星球"],["attack","攻","进攻","攻击相邻的敌方星球"],["reinforce","援","增援","让己方星球舰队 +1"],["dispatch","调","舰队调度","选择舰队，再点任意星球"]]:
		_command_card(command_grid,entry)
	var message_panel := PanelContainer.new()
	var message_style := _style(INK,CYAN,0,4)
	message_style.border_width_left = 3
	message_panel.add_theme_stylebox_override("panel",message_style)
	commands.add_child(message_panel)
	_label(message_panel,message,15,MUTED)
	_skills(commands)
	var sequence := _section(parent,"行动序列","")
	var sequence_row := _row(sequence,4)
	for faction in ["帝国","联盟","混沌"]:
		var faction_button := _button(sequence_row,faction,func() -> void: _faction_manual(faction),false,Color(Rules.COLORS[faction]))
		faction_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if faction == game.state.player: faction_button.add_theme_color_override("font_color",CYAN)

func _command_card(parent: Node, spec: Array) -> void:
	var button := _button(parent,"",func() -> void:
		command = str(spec[0]) if command != spec[0] else ""
		message = "点击带框选标记的灰色星球完成扩张。" if command == "expand" else ("先选择己方舰队，再拖动或点击目标。" if command == "dispatch" else "选择目标星球，在确认菜单结算。")
		reveal_map_pending = command != ""
		_schedule_build())
	button.custom_minimum_size.y = 88*ui_scale
	button.set_meta("command",str(spec[0]))
	button.add_theme_stylebox_override("normal",_style(INK if command == spec[0] else PANEL,CYAN if command == spec[0] else LINE,1,4))
	button.add_theme_stylebox_override("hover",_style(Color("12334e"),CYAN,1,2))
	button.add_theme_stylebox_override("pressed",_style(INK,CYAN,1,4))
	_describe_control(button,str(spec[2]),str(Help.entry(str(spec[2]))[1]))
	var margin := MarginContainer.new()
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",int(20*ui_scale))
	margin.add_theme_constant_override("margin_right",int(20*ui_scale))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _row(margin,12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := SymbolBadge.new()
	glyph.glyph = str(spec[1])
	glyph.badge_font = font_bold
	glyph.custom_minimum_size = Vector2(40,40)*ui_scale
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var text_box := _vbox(row,7)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(text_box,str(spec[2]),20,TEXT,true)
	_label(text_box,str(Help.entry(str(spec[2]))[0]),16,MUTED)
	var badge := SymbolBadge.new()
	badge.circular = true
	badge.glyph = "→" if spec[0] in ["dispatch","attack"] else "1"
	badge.badge_font = font_regular
	badge.custom_minimum_size = Vector2(24,24)*ui_scale
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)

func _skills(parent: Node) -> void:
	_line(parent)
	var row := _row(parent)
	_label(row,str(game.state.player) + "技能",21,TEXT,true)
	var manual := _button(row,"阵营手册",func() -> void: _faction_manual(str(game.state.player)))
	manual.size_flags_horizontal = Control.SIZE_SHRINK_END
	var passive: Dictionary = {"帝国":"统御秩序：帝国星球防守时战力 +1。","联盟":"自治星域：开局领地 +1，扩张成本更低，购买舰队多 1 单位。","混沌":"游击法则：进攻平局获胜，适合劫掠与灵活机动。"}
	_label(parent,"被动  " + str(passive[game.state.player]),17,MUTED)
	var skills: Dictionary = {"帝国":["星门锁域","选择一颗己方星球，本轮敌人无法攻击它。"],"联盟":["自由贸易","获得 4 信用点，选中星球好感 +8。"],"混沌":["暗网补给","获得 3 情报与 3 燃料。"]}
	var spec: Array = skills[game.state.player]
	_button(parent,"%s    %s" % [spec[0],"就绪" if game.state.skill_turn != game.state.turn else "本轮已使用"],func() -> void:
		command = "skill"
		message = str(spec[1])
		reveal_map_pending = true
		_schedule_build())
	_label(parent,str(spec[1]),16,MUTED)
	var ultimate := _button(parent,"银河重整    %s" % ("已使用" if game.state.ultimate else ("第 4 轮解锁" if int(game.state.turn) < 4 else "就绪")),func() -> void:
		_confirm_action("银河重整","所有己方星球舰队 +1，并额外获得 1 次行动。本局只能使用一次。","ultimate",{}))
	ultimate.disabled = int(game.state.turn) < 4 or bool(game.state.ultimate)
	if ultimate.disabled: ultimate.get_node("ActionCaption").add_theme_color_override("font_color",MUTED)
	_label(parent,"所有己方星球舰队 +1，并额外获得 1 次行动。",16,MUTED)

func _diplomacy_section() -> void:
	var box := _section(page,"外交频道","每轮一次")
	_label(box,"选择一个势力结盟，共同抵抗外星入侵。",17,MUTED)
	var buttons := _row(box)
	for f in ["帝国","联盟","混沌"]:
		if f == game.state.player: continue
		var tint := Color(Rules.COLORS[f])
		var ally: bool = game.friendly(str(game.state.player),f)
		_button(buttons,"%s%s" % ["已与" if ally else "与",f + "结盟"],func() -> void:
			_confirm_action("与%s结盟" % f,"4 信用点；联盟持续 4 轮，彼此停止攻击并开放星门。","diplomacy",{"faction":f,"choice":"结盟"}),false,tint)
		_label(box,"%s  好感 %+d  ·  %s" % [f,int(game.state.relations[f]),_pact_text(f)],16,tint)
		var commander: Dictionary = game.state.commanders[f]
		_label(box,"%s · %s\n%s" % [commander.name,commander.title,commander.detail],16,MUTED)
	_button(box,"外交、交易与协议",_diplomacy_dialog)

func _pact_text(faction: String) -> String:
	var descriptions: Dictionary = {"alliance":"联盟","ceasefire":"停战","access":"通行","protection":"保护","joint":"共同抗敌"}
	var active: Array[String] = []
	for key in game.state.pacts[faction]:
		if int(game.state.pacts[faction][key]) >= int(game.state.turn): active.append("%s %d轮" % [descriptions[key],int(game.state.pacts[faction][key]) - int(game.state.turn) + 1])
	return "未结盟" if active.is_empty() else " / ".join(active)

func _workshop_section() -> void:
	var box := _section(page,"舰队工坊","驻守 / 购买 / 升级")
	_option(box,["突击舰队 · 进攻","守卫舰队 · 防御","开拓舰队 · 扩张","劫掠舰队 · 掠夺","侦察舰队 · 侦察","运输舰队 · 补给"],workshop_type,func(index: int) -> void: workshop_type = index)
	var row: BoxContainer = _row(box,8) if size.x >= 600 else _vbox(box,8)
	_button(row,"购买舰队",func() -> void:
		_confirm_action("购买舰队","8 信用 / 4 材料。先选择己方星球。","buy",{"planet":selected_planet,"type":Rules.TYPES[workshop_type]}))
	_button(row,"升级驻守舰队",_upgrade_dialog)
	_button(row,"配置舰队类型",_configure_dialog)
	_label(box,"购买 8 信用 / 4 材料    升级 6 信用 / 3 材料",15,MUTED)
	_label(box,"先在地图选择己方星球，再购买或升级舰队。",17,MUTED)
	var f: Dictionary = game.fleet(selected_fleet)
	if not f.is_empty():
		_label(box,"选中：%s · %s · LV.%d · %d 单位" % [f.name,f.type,int(f.level),int(f.units)],17,CYAN)
		_button(box,"舰队操作 / 拆分 / 相遇",func() -> void: _fleet_dialog(selected_fleet))

func _saves_section() -> void:
	var box := _section(page,"战役存档","仅保存在本机")
	var slots: Array[String] = []
	for i in range(1,4): slots.append("槽位 %d · %s" % [i,_slot_time(str(i))])
	_option(box,slots,save_slot,func(index: int) -> void: save_slot = index)
	var row := _row(box)
	_button(row,"保存当前进度",func() -> void:
		var slot: String = str(save_slot+1)
		if FileAccess.file_exists(_save_path(slot)):
			_confirm("覆盖存档","确认覆盖槽位 %s？其他槽位和旧版存档不会受影响。" % slot,func() -> void: _save(slot))
		else: _save(slot))
	_button(row,"读取存档",func() -> void: _confirm("读取存档","当前未保存进度会被替换，是否读取？",func() -> void: _load(str(save_slot+1))))
	var extra: BoxContainer = _row(box) if size.x >= 600 else _vbox(box)
	var check := CheckButton.new()
	check.text = "自动存档"
	check.button_pressed = auto_save
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.toggled.connect(func(value: bool) -> void: auto_save = value)
	extra.add_child(check)
	_describe_control(check,"自动存档",str(Help.entry("自动存档")[1]))
	_label(box,"自动存档：开启后在每次成功行动后更新自动槽。",14,MUTED)
	_button(extra,"读取自动存档",func() -> void: _confirm("恢复自动存档","将恢复最近一次已完成行动。",func() -> void: _load("auto")))
	_button(extra,"删除槽位",func() -> void:
		_confirm("删除存档","仅删除当前选择的槽位，不可撤销。",func() -> void:
			var path: String = _save_path(str(save_slot+1))
			if FileAccess.file_exists(path):
				var error: Error = DirAccess.remove_absolute(path)
				_notify("该槽位已删除，无法恢复。" if error == OK else "删除失败。",error != OK)
			else: _notify("此槽位没有存档。")
			_schedule_build()))
	_label(box,"自动存档：" + _slot_time("auto"),14,MUTED)

func _planet_section() -> void:
	var p: Dictionary = game.planet_view(selected_planet)
	var box := _section(page,"星球信息",str(p.get("name","未选择")))
	if p.is_empty():
		_space(box,25)
		var hint := _label(box,"◎\n点击星图中的星球，查看归属、驻军与资源。",22,MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_space(box,25)
		return
	_label(box,"%s  ·  %s%s" % [p.name,p.owner,"首都" if p.capital else "星球"],27,Color(Rules.COLORS[p.owner]),true)
	_label(box,"当前可见" if p.live else ("仅有开局航图" if int(p.seen_turn)==0 else "最后情报：第 %d 轮，可能已发生变化。" % int(p.seen_turn)),16,CYAN)
	if p.detailed:
		_label(box,"%s星球    产出 +%d 信用 / +1 材料 / +1 燃料\n防御 %d    驻军 %d    星门 %d    好感 %+d\n建筑：%s    状态：%s    治理：%s" % [p.type,int(p.income),int(p.known_defense),int(p.known_units),game.neighbors(str(p.id)).size(),int(p.affinity),p.building,p.status,p.policy],17,MUTED)
	else: _label(box,"驻军、防御和设施未识别。派侦察舰靠近，或向其他阵营交换情报。",17,MUTED)
	for f in game.stationed(str(p.id),str(game.state.player)):
		_button(box,"%s · %s · %d 单位 · LV.%d%s" % [f.name,f.type,int(f.units),int(f.level),"  已选择" if f.id == selected_fleet else ""],func() -> void:
			selected_fleet = str(f.id)
			message = "已选择舰队。拖动星球旁的舰队图标，或打开舰队操作。"
			_schedule_build())
	if p.owner == game.state.player:
		var row := _row(box)
		_button(row,"星球治理",func() -> void: _policy_dialog(str(p.id)))
		_button(row,"建设设施",func() -> void:
			var dialog := _open_modal("建设设施")
			_label(dialog,"消耗 1 行动 / 4 材料。",17,MUTED)
			for building in ["护盾阵列","资源基地"]:
				_button(dialog,building + (" · 防御 +2" if building == "护盾阵列" else " · 收入 +2"),func() -> void: _perform("build",{"planet":p.id,"building":building})))

func _fleets_section() -> void:
	var box := _section(page,"太空舰队","驻守与游离编制")
	var list: Array = game.fleet_views().filter(func(f: Dictionary) -> bool: return f.owner == game.state.player or f.station == "")
	if list.is_empty(): _label(box,"暂无舰队。在己方星球购买新舰队。",17,MUTED)
	for f in list:
		var location: String = str(game.planet(str(f.station)).get("name","太空"))
		_button(box,"%s  ·  %s / %s / %s 单位%s" % [f.name,f.owner,location,str(int(f.units)) if int(f.units)>=0 else "?","（第%d轮旧情报）" % int(f.seen_turn) if not f.live else ""],func() -> void:
			if f.owner == game.state.player:
				selected_fleet = str(f.id)
				selected_planet = str(f.station)
				_fleet_dialog(str(f.id))
			elif f.live: _encounter_dialog(selected_fleet,str(f.id))
			else: _ghost_dialog(str(f.id)))

func _gate_section() -> void:
	var g: Dictionary = game.state.fog.gates.get(selected_gate,{})
	var box := _section(page,"星门网络","控制 %d 座" % game.gate_count(str(game.state.player)))
	_label(box,"点击航线中央的菱形节点，争夺、封锁、破坏或修复星门。",17,MUTED)
	if g.is_empty(): return
	_label(box,"%s ⇄ %s\n归属：%s  ·  %s" % [game.planet(str(g.a)).name,game.planet(str(g.b)).name,g.owner,"损坏" if g.broken else ("封锁中" if int(g.blocked) >= int(game.state.turn) else "畅通")],20,CYAN)
	var row := _row(box)
	for choice in ["占领","封锁","破坏","修复"]:
		_button(row,choice,func() -> void:
			_confirm_action("星门" + choice,"1 行动" + (" / 3 材料" if choice == "修复" else ""),"gate",{"gate":g.id,"choice":choice,"fleet":selected_fleet}))

func _campaign_section() -> void:
	var box := _section(page,"战区概览",Rules.MODES[int(game.state.mode)])
	_label(box,Rules.MODE_HELP[int(game.state.mode)],18,TEXT)
	_label(box,"情报 %d    燃料 %d    声望 %d\n地图 %s    外星入侵 %d 次    外交积分 %d" % [int(game.res().intel),int(game.res().fuel),int(game.res().reputation),game.state.seed,int(game.state.invasion),game.diplomacy_score()],17,CYAN)
	if game.state.phase == "finished":
		_label(box,"%s\n%s" % ["战役胜利" if game.state.winner == game.state.player else "战役结束",game.state.result],28,CYAN,true)
	var scores: Array[String] = []
	for faction in Rules.FACTIONS: scores.append("%s %s" % [faction,str(game.score(faction)) if faction==game.state.player or game.state.phase=="finished" else "情报不足"])
	_label(box,"战役积分：" + "  /  ".join(scores),16,MUTED)
	_line(box)
	_label(box,"战争记录",21,TEXT,true)
	for i in range(mini(8,game.state.log.size())): _label(box,str(game.state.log[i]),16,MUTED)
	_button(box,"查看全部战报",func() -> void:
		var dialog := _open_modal("战争记录")
		for line in game.state.log: _label(dialog,str(line),17,MUTED))
	_button(box,"世界观与原始设计内容",_original_brief)

func _frontier_action(action: String, id: String = "", count: int = 1) -> void:
	var result: Dictionary = preload("res://frontier_systems.gd").act(game,action,id,count)
	message = str(result.message)
	if result.ok: _autosave()
	_close_modal()
	_schedule_build()
	var dialog := _open_modal("远征报告")
	_label(dialog,message,18,CYAN if result.ok else RED)
	_net_button(dialog,"返回远征中心","返回远征中心，继续查看家园建筑与战舰机库",_frontier_dialog)

func _frontier_section() -> void:
	var box := _section(page,"远征与家园","建设 · 副本 · 战舰 · 补给 · 阵营")
	_net_button(box,"打开远征中心","副本、建筑、战舰、抽奖、阵营军需",_frontier_dialog)
	_net_button(box,"真人联网单挑","连接朋友的地址并选择阵营进行 1v1",_network_dialog)

func _frontier_dialog() -> void:
	var F = preload("res://frontier_systems.gd")
	F.ensure(game)
	var f: Dictionary = game.state.frontier
	var dialog := _open_modal("远征与家园")
	_label(dialog,"星币 %d / 材料 %d / 燃料 %d / 行动 %d" % [game.res().credits,game.res().materials,game.res().fuel,game.state.ap],17,CYAN)
	var tabs: Array = ["家园建设","副本远征","战舰机库","补给抽奖","阵营军需","福利中心"]
	var select := _option(dialog,tabs,frontier_tab,func(index: int) -> void:
		frontier_tab = index
		_frontier_dialog.call_deferred())
	_describe_control(select,"远征分区","切换家园、副本、机库、抽奖、阵营军需或福利中心；切换不消耗资源。")
	match frontier_tab:
		0:
			_label(dialog,"家园建设 · 每轮自动生产，建筑最高 Lv.5",20,TEXT,true)
			for key in F.BUILDINGS:
				var lv: int = int(f.buildings[key])
				_front_button(dialog,"%s Lv.%d" % [key,lv],"%s；升级：1 行动 / %d 材料 / %d 星币" % [F.BUILDINGS[key],lv*8,lv*4],"building",key)
		1:
			_label(dialog,"副本远征 · 本轮剩余 %d / 3 次" % int(f.attempts),20,TEXT,true)
			_label(dialog,"当前出战 %s · 综合战力 %d（每战浮动 ±3）" % [F.SHIPS[f.selected].name,F.strength(f)],16,CYAN)
			_label(dialog,"自动战斗：战力达到守军值即胜。失败也消耗行动、燃料和次数；升级战舰或指挥中心可以提升战力。",16,MUTED)
			for key in F.DUNGEONS:
				var d: Dictionary = F.DUNGEONS[key]
				_label(dialog,"%s · 已通关 %d 次" % [d.text,int(f.clears.get(key,0))],16,MUTED)
				_front_button(dialog,key,"守军 %d；1 行动 / %d 燃料；胜利 +%d 材料 / +%d 星币 / +%d 功勋" % [d.power,d.fuel,d.materials,d.credits,d.rep],"dungeon",key)
		2:
			_label(dialog,"战舰机库",20,TEXT,true)
			for key in F.SHIPS:
				var ship: Dictionary = F.SHIPS[key]
				_label(dialog,"%s [%s] · 持有 %d · 等级 %d / 5 · 星级 %d / 5%s\n攻击 %d / 装甲 %d / 机动 %d" % [ship.name,ship.rarity,f.ships[key],f.levels[key],f.stars.get(key,0)," · 出战中" if f.selected==key else "",ship.attack,ship.armor,ship.speed],17,CYAN)
				_label(dialog,"等级提升战舰基础战力；每次抽到同名战舰会自动升星，最高 5 星。",14,MUTED)
				_front_button(dialog,"选择出战 · " + key,"选择机库战舰挑战副本，无消耗","select",key)
				_front_button(dialog,"建造 · " + key,"1 行动 / %d 材料 / 8 星币" % int(ship.cost),"build_ship",key)
				_front_button(dialog,"直购 · " + key,"使用 %d 星币 + 1 行动直接购买，不消耗材料" % (int(ship.cost)*4),"buy_ship",key)
				_front_button(dialog,"升级 · " + key,"1 行动 / %d 材料，最高 Lv.5" % (int(f.levels[key])*6),"upgrade_ship",key)
				_front_button(dialog,"部署 · " + key,"消耗 1 艘库存 / 1 行动 / 2 燃料，部署至己方首都","deploy",key)
				_line(dialog)
		3:
			_label(dialog,"补给抽奖 · SSR 保底进度 %d / 20",20,TEXT,true)
			_label(dialog,"使用星币抽取战舰或工程材料。每个卡池都有独立价格与概率；连续 19 次未出 SSR，第 20 次必得。重复战舰会升星，星级最高 5 星。",16,MUTED)
			for banner_id in F.GACHA_BANNERS:
				var banner: Dictionary = F.GACHA_BANNERS[banner_id]
				var material_chance: int = 100-int(banner.ssr)-int(banner.sr)-int(banner.r)
				_label(dialog,"%s · %s" % [banner.title,banner.detail],18,CYAN,true)
				_label(dialog,"概率：SSR %d%% / SR %d%% / R %d%% / 材料 %d%%；材料奖励 %d 份" % [banner.ssr,banner.sr,banner.r,material_chance,banner.materials],14,MUTED)
				_front_button(dialog,"单抽 · %s" % banner_id,"%d 星币；抽取 1 次，逐抽计入 SSR 保底" % int(banner.cost),"draw",banner_id,1)
				_front_button(dialog,"十连 · %s" % banner_id,"%d 星币；连续抽取 10 次，每次独立计算保底" % (int(banner.cost)*10),"draw",banner_id,10)
				_line(dialog)
			_label(dialog,"最近补给记录",18,TEXT,true)
			for line in f.history: _label(dialog,str(line),15,MUTED)
		4:
			_label(dialog,"%s军需部 · 功勋 %d · 军衔 %s" % [game.state.player,int(f.reputation),"先锋" if int(f.reputation)>=30 else ("老兵" if int(f.reputation)>=10 else "新兵")],20,TEXT,true)
			_label(dialog,"阵营在战役开局选择。完成副本获得本阵营功勋，可以兑换军需。军衔按当前功勋显示。真人对战中可以单独选择阵营。",16,MUTED)
			_front_button(dialog,"阵营军需兑换","10 功勋 → 15 材料 + 8 燃料","faction_supply")
			_net_button(dialog,"查看阵营手册","查看本阵营的被动、技能与专属规则",func() -> void: _faction_manual(str(game.state.player)))
		5:
			_label(dialog,"福利中心",20,TEXT,true)
			_label(dialog,"福利按轮次重置。每日签到、舰队援助和远征里程奖会发放星币、战舰、材料与燃料。远征里程奖需要累计完成 3 次副本。",16,MUTED)
			for welfare_id in F.WELFARE:
				var welfare: Dictionary = F.WELFARE[welfare_id]
				var claimed: bool = welfare_id in f.welfare.claimed
				var title: String = str(welfare.title) + (" · 已领取" if claimed else " · 可领取")
				var welfare_button := _net_button(dialog,title,str(welfare.detail),func() -> void: _frontier_action("welfare",welfare_id))
				welfare_button.disabled = claimed
				_label(dialog,str(welfare.detail),14,MUTED)

func _front_button(parent: Node, title: String, detail: String, action: String, id: String = "", count: int = 1) -> void:
	_net_button(parent,title,detail,func() -> void: _frontier_action(action,id,count))
	_label(parent,detail,14,MUTED)

func _icon_button(parent: Node, title: String, kind: String, detail: String, tab: int) -> Button:
	var button := _net_button(parent,title,detail,func() -> void: _open_frontier_hub(tab))
	button.custom_minimum_size = Vector2(0,78*ui_scale)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := FrontierIcon.new()
	icon.kind = kind
	icon.tint = CYAN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(38,38)*ui_scale
	icon.position = Vector2(8,6)*ui_scale
	button.add_child(icon)
	return button

func _network_changed() -> void:
	if duel_panel_open: _refresh_network_panel.call_deferred()

func _refresh_network_panel() -> void:
	if duel_panel_open: _network_dialog()

func _net_button(parent: Node, title: String, detail: String, callback: Callable) -> Button:
	var b := _button(parent,"",callback)
	b.text = title
	b.custom_minimum_size.y = 74*ui_scale
	for state_name in ["normal","hover","pressed","disabled"]:
		var style := b.get_theme_stylebox(state_name).duplicate() as StyleBoxFlat
		style.content_margin_top = 8*ui_scale
		style.content_margin_bottom = 30*ui_scale
		b.add_theme_stylebox_override(state_name,style)
	_describe_button(b,detail,detail)
	return b

func _network_dialog() -> void:
	var dialog := _open_modal("真人阵营单挑 · 联机大厅")
	duel_panel_open = true
	_label(dialog,duel_network.status,20,CYAN,true)
	_net_button(dialog,"返回游戏（保留连接）","关闭此面板，连接继续；可再次打开",func() -> void:
		duel_panel_open = false
		_close_modal())
	if not duel_network.match_state.is_empty():
		var battle: Dictionary = duel_network.match_state
		var mine: int = duel_network.my_id()
		_label(dialog,"第 %d 手 · %s" % [battle.turn,"对局结束" if battle.phase=="ended" else ("轮到你行动" if int(battle.active)==mine else "等待对手行动")],20,TEXT,true)
		for id in battle.players:
			var p: Dictionary = battle.players[id]
			_label(dialog,"%s · %s\n舰体 %d / 60 · 护盾 %d · 能量 %d / 5%s" % ["你" if int(id)==mine else "对手",p.faction,p.hp,p.shield,p.energy," · 技能已用" if p.skill else ""],18,CYAN if int(id)==mine else ORANGE)
		if battle.phase == "ended":
			_label(dialog,"你获胜了！" if int(battle.winner)==mine else "本场战败",25,CYAN)
		else:
			var actions: Dictionary = {"attack":["主炮齐射","伤害 10，无消耗"],"heavy":["重型鱼雷","伤害 19，消耗 3 能量"],"guard":["防御姿态","护盾 +5，下次受到攻击减半"],"repair":["紧急维修","舰体 +12，消耗 2 能量"],"skill":["阵营绝技","每局一次：帝国护盾 +18；联盟维修 +16 / 能量 +2；混沌伤害 23"],"surrender":["认输","立即结束本局"]}
			for action in actions:
				var button := _net_button(dialog,actions[action][0],actions[action][1],func() -> void: duel_network.play(action))
				var me: Dictionary = battle.players[mine]
				button.disabled = int(battle.active)!=mine or (action=="heavy" and int(me.energy)<3) or (action=="repair" and int(me.energy)<2) or (action=="skill" and me.skill)
		for line in battle.log: _label(dialog,str(line),15,MUTED)
	elif duel_network.peer == null:
		_label(dialog,"双方各自选阵营，使用对等旗舰单挑。每次操作后换手，能量 +1；摧毁对方舰体获胜。战役、抽奖资源不带入。",16,MUTED)
		var selected: Array = ["帝国"]
		_option(dialog,Rules.FACTIONS.slice(0,3),0,func(index: int) -> void: selected[0] = Rules.FACTIONS[index])
		_label(dialog,"房主地址（仅加入时填写）",15,MUTED)
		var address := LineEdit.new()
		address.text = "127.0.0.1"
		dialog.add_child(address)
		_describe_control(address,"房主地址","连接房主使用的 IPv4 地址或主机名，同一电脑填写 127.0.0.1。")
		var code := LineEdit.new()
		code.max_length = 16
		code.placeholder_text = "房间口令：4–16 字符，双方填写相同值"
		dialog.add_child(code)
		_describe_control(code,"房间口令","双方填写相同的 4–16 字符口令，校验通过后开始战斗。")
		_label(dialog,"UDP 端口（双方相同）",15,MUTED)
		var port := SpinBox.new()
		port.min_value = 1024
		port.max_value = 65535
		port.value = 24560
		dialog.add_child(port)
		_describe_control(port,"UDP 端口","双方填写同一个端口，默认 24560；跨网需映射对应 UDP 端口。")
		_net_button(dialog,"创建房间","监听所选 UDP 端口，等待一位真人",func() -> void:
			duel_network.open_room(true,"",int(port.value),code.text,selected[0]))
		_net_button(dialog,"连接房主","输入房主 IP、相同端口与口令",func() -> void:
			duel_network.open_room(false,address.text,int(port.value),code.text,selected[0]))
		_label(dialog,"同一电脑测试用 127.0.0.1；局域网填写房主局域网 IP。跨网需要房主公网可达地址与 UDP 端口映射，或同一虚拟局域网。没有自动公网匹配服务。",15,MUTED)
	else:
		var addresses: Array[String] = []
		for address in IP.get_local_addresses():
			if "." in address and not address.begins_with("127."): addresses.append(address)
		_label(dialog,"UDP 端口 %d\n本机地址：%s\n房主把地址、端口与口令发给朋友，对手连接后自动开始。" % [int(duel_network.bound_port)," / ".join(addresses)],16,MUTED)
	if duel_network.peer != null:
		_net_button(dialog,"断开并离开房间","正在对战时离开会结束连接",func() -> void: duel_network.leave())

func _original_brief() -> void:
	var dialog := _open_modal("世界观与原始设计内容")
	_label(dialog,"原始提示词全文存档。网页技术要求已按后续要求改为 Godot 2D；具体操作与数值以游戏确认菜单为准。",17,CYAN)
	_label(dialog,FileAccess.get_file_as_string("res://docs/original-brief.txt"),17,MUTED)

func _on_target(kind: String, id: String) -> void:
	if kind == "ghost":
		_ghost_dialog(id)
		return
	if kind == "gate":
		selected_gate = id
		_schedule_build()
		_gate_dialog(id)
		return
	if kind == "fleet":
		var f: Dictionary = game.fleet(id)
		if f.is_empty(): return
		if f.owner == game.state.player:
			if command == "dispatch" and selected_fleet != "" and selected_fleet != id: _friendly_dialog(selected_fleet,id)
			else:
				selected_fleet = id
				selected_planet = str(f.station)
				message = "已选择%s，拖动舰队或点击目标。" % f.name
				if tutorial_active and tutorial_step == 0 and id == str(game.state.tutorial.fleet): _advance_tutorial()
				_schedule_build()
		else: _encounter_dialog(selected_fleet,id)
		return
	if kind != "planet": return
	var p: Dictionary = game.planet_view(id)
	if p.is_empty(): return
	if command == "dispatch" and selected_fleet != "" and str(game.fleet(selected_fleet).get("station","")) != id:
		_on_drop(selected_fleet,{"kind":"planet","id":id,"planet":id,"x":p.x,"y":p.y,"owner":p.owner})
		return
	selected_planet = id
	if command in ["expand","reinforce","skill"]:
		var title: Dictionary = {"expand":"扩张","reinforce":"增援","skill":"阵营技能"}
		_confirm_action(str(title[command]),"目标：%s · %s。%s" % [p.name,p.owner,"消耗 1 次行动。" if command != "skill" else "每轮一次。"],command,{"planet":id})
	elif command == "attack":
		if p.owner == game.state.player:
			var attackers: Array = game.stationed(id,str(game.state.player))
			selected_fleet = str(attackers[0].id) if not attackers.is_empty() else ""
			message = "已选择进攻编队，请点击敌方星球。" if selected_fleet != "" else "这里没有驻守舰队，请选择其他己方星球。"
		else:
			if selected_fleet == "" or game.fleet(selected_fleet).is_empty(): selected_fleet = str(game.available_source(id).get("id",""))
			_attack_dialog(selected_fleet,id)
	else:
		var list: Array = game.stationed(id,str(game.state.player))
		if not list.is_empty(): selected_fleet = str(list[0].id)
		message = "%s · %s · 驻军 %s%s。详情在星球信息中。" % [p.name,p.owner,str(int(p.known_units)) if int(p.known_units)>=0 else "未识别","（旧情报）" if not p.live else ""]
	if tutorial_active and tutorial_step == 0 and id == str(game.state.tutorial.home):
		_advance_tutorial()
	_schedule_build()

func _on_drop(id: String, target: Dictionary) -> void:
	selected_fleet = id
	if target.kind == "ghost":
		_ghost_dialog(str(target.id))
		return
	if target.kind == "fleet":
		if game.fleet(str(target.id)).owner == game.state.player: _friendly_dialog(id,str(target.id))
		else: _encounter_dialog(id,str(target.id))
	elif target.kind == "planet" and target.owner not in [game.state.player,"无主"] and not game.friendly(str(game.state.player),str(target.owner)):
		_attack_dialog(id,str(target.id))
	elif target.kind == "gate":
		selected_gate = str(target.id)
		_gate_dialog(str(target.id))
	else: _move_dialog(id,target)

func _move_dialog(id: String, target: Dictionary) -> void:
	var f: Dictionary = game.fleet(id)
	var q: Dictionary = game.movement_quote(f,target,true)
	if not q.valid:
		_notify(str(q.reason),true)
		return
	var args: Dictionary = {"fleet":id,"x":target.x,"y":target.y}
	if target.kind == "planet": args.planet = target.id
	var dialog := _open_modal("舰队调度")
	_label(dialog,"%s → %s" % [f.name,game.planet(str(target.get("id",""))).get("name","太空坐标 %d, %d" % [int(target.x),int(target.y)])],22,TEXT,true)
	_label(dialog,"距离 %d · %s\n预计消耗 %d 行动 / %d 燃料\n风险：%s · 到达时间：%s" % [int(q.distance),"星门跃迁" if q.gate else "太空航行",int(q.ap),int(q.fuel),q.risk,q.eta],18,MUTED)
	if q.get("hostile",false): _label(dialog,"敌控区有 20% 概率损失 1 单位；隐匿模块可规避途中拦截。",17,RED)
	if target.kind == "planet" and target.owner == "无主": _label(dialog,"无主星球：本次停留在附近太空，不会直接改变归属。用扩张或进攻占领。",16,ORANGE)
	_button(dialog,"确认驻守" if target.owner == game.state.player and target.kind == "planet" else "确认移动",func() -> void: _perform("move",args),true)
	if target.kind == "planet" and target.owner == "无主": _button(dialog,"改为攻击星球",func() -> void: _attack_dialog(id,str(target.id)))

func _attack_dialog(id: String, planet_id: String) -> void:
	var f: Dictionary = game.fleet(id)
	var p: Dictionary = game.planet_view(planet_id)
	if f.is_empty():
		_notify("请先点击己方星球或太空舰队，选择攻击编队。",true)
		return
	var q: Dictionary = game.movement_quote(f,p,true)
	var dialog := _open_modal("攻击星球 · " + str(p.name))
	var strength: String = "驻军 %d / 防御 %d（第 %d 轮情报）" % [int(p.known_units),int(p.known_defense),int(p.seen_turn)] if p.detailed else "驻军和防御未识别，建议先侦察。"
	_label(dialog,"%s：进攻战力 %d\n%s：%s" % [f.name,game.power(f),p.name,strength],19,TEXT)
	_label(dialog,"预计：" + (("有望占领" if game.power(f)>int(p.known_defense) else "强攻可能失利") if p.current_detail else "缺乏实时情报，无法可靠判断胜负") + "\n行动 %d / 燃料 %d%s" % [int(q.get("ap",1)),int(q.get("fuel",0))," / 情报 2（远程）" if q.get("remote",false) else ""],17,ORANGE)
	for method in ["直接突袭","围困","星门封锁","轨道轰炸","策反行动","诱敌出击"]:
		var descriptions: Dictionary = {"直接突袭":"按战力结算，占领或损失舰队","围困":"两轮内防御 -2、收入减半","星门封锁":"阻断目标周边星门","轨道轰炸":"另耗 2 材料，摧毁建筑、降低好感","策反行动":"另耗 6 / 9 情报，可能失败","诱敌出击":"使一支驻军离开星球"}
		_button(dialog,method,func() -> void:
			_confirm_action(method,str(descriptions[method]) + "。确认对%s执行？" % p.name,"attack",{"fleet":id,"planet":planet_id,"method":method}),method == "直接突袭")
	_label(dialog,"关闭菜单即撤退，不扣除任何资源。",16,MUTED)

func _friendly_dialog(a: String, b: String) -> void:
	var dialog := _open_modal("友方舰队相遇")
	_label(dialog,"需要两支己方舰队相距不超过 100。各项消耗 1 次行动。",17,MUTED)
	var target: Dictionary = game.fleet(b)
	if not target.is_empty():
		_button(dialog,"先移动到友舰附近",func() -> void: _move_dialog(a,{"kind":"space","id":"","x":float(target.x)+45,"y":target.y,"owner":target.owner}))
	for pair in [["merge","合并舰队"],["support","临时增援 · 两轮"],["exchange","交换模块 · 2 材料"]]:
		_button(dialog,str(pair[1]),func() -> void: _confirm_action(str(pair[1]),"确认执行？编制与资源会立即更新。",str(pair[0]),{"fleet":a,"target":b}))
	_button(dialog,"拆分主舰队",func() -> void: _split_dialog(a))

func _encounter_dialog(a: String, b: String) -> void:
	var enemy: Dictionary = game.fleet(b)
	if not enemy.is_empty() and not Systems.fleet_live(game,enemy):
		_ghost_dialog(b)
		return
	var dialog := _open_modal("敌方舰队接触")
	if enemy.is_empty():
		_label(dialog,"目标已经离开。",18,MUTED)
		return
	var revealed: bool = Systems.fleet_detail(game,enemy)
	_label(dialog,"%s · %s\n%s" % [enemy.name if revealed else "未知舰队信号",enemy.owner,"%d 单位 · LV.%d · %s" % [int(enemy.units),int(enemy.level),enemy.type] if revealed else "单位、等级与模块待侦察"],20,RED)
	_label(dialog,"需要先选中己方舰队并接近到距离 180 内。侦察需 2 情报，避让需 3 燃料，所有选择消耗 1 行动。",17,MUTED)
	_button(dialog,"先接近敌舰",func() -> void: _move_dialog(a,{"kind":"space","id":"","x":float(enemy.x)+70,"y":enemy.y,"owner":enemy.owner}))
	for choice in ["立即开战","观察和侦察","避让","威慑","暂时停火"]:
		_button(dialog,choice,func() -> void: _confirm_action(choice,"确认与%s接触？" % enemy.name,"encounter",{"fleet":a,"target":b,"choice":choice}))

func _fleet_dialog(id: String) -> void:
	var f: Dictionary = game.fleet(id)
	if f.is_empty() or f.owner != game.state.player: return
	selected_fleet = id
	var dialog := _open_modal(str(f.name))
	_label(dialog,"%s · %d 单位 · LV.%d\n攻击 %d / 防御 %d · %s\n模块：%s" % [f.type,int(f.units),int(f.level),game.power(f),game.power(f,false),f.state,"、".join(f.modules) if not f.modules.is_empty() else "无"],18,MUTED)
	_button(dialog,"选择并调动",func() -> void:
		_close_modal()
		command = "dispatch"
		message = "拖动所选舰队到目标，或点击目的地。在松手后的菜单确认移动。"
		reveal_map_pending = true
		_schedule_build())
	_button(dialog,"脱离驻守，进入太空",func() -> void:
		_move_dialog(id,{"kind":"space","id":"","owner":"无主","x":float(f.x)+60,"y":float(f.y)-35}))
	_button(dialog,"拆分舰队",func() -> void: _split_dialog(id))
	_button(dialog,"配置名称、类型和模块",_configure_dialog)
	_button(dialog,"选择升级方向",_upgrade_dialog)
	if f.type == "运输" or "运输" in f.modules: _button(dialog,"运输舱 / 装卸补给",func() -> void: _cargo_dialog(id))
	_button(dialog,"调查中央遗迹",func() -> void: _confirm_action("调查未知区域","1 行动 / 2 燃料；需靠近中央遗迹。","explore",{"fleet":id}))
	_button(dialog,"主动扫描",func() -> void: _confirm_action("主动扫描","1 行动 / 2 情报；侦察舰或侦察模块可扫描周围区域，自己也会暴露。","scan",{"fleet":id}))
	var near: bool = false
	for other in game.state.fleets:
		if not Systems.fleet_live(game,other): continue
		if other.id == id or game.position_of(f).distance_to(game.position_of(other)) > 180: continue
		near = true
		_button(dialog,"接触 " + (str(other.name) if Systems.fleet_detail(game,other) else str(other.owner)+"舰队信号"),func() -> void:
			if other.owner == game.state.player: _friendly_dialog(id,str(other.id))
			else: _encounter_dialog(id,str(other.id)))
	if not near: _label(dialog,"附近没有可接触舰队。",16,MUTED)

func _split_dialog(id: String) -> void:
	var f: Dictionary = game.fleet(id)
	if f.is_empty(): return
	var dialog := _open_modal("拆分舰队")
	if int(f.units) <= 1:
		_label(dialog,"至少 2 个单位才能拆分。",18,MUTED)
		return
	var info := _label(dialog,"新分队 1 / 原舰队 %d" % (int(f.units)-1),20,CYAN)
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = int(f.units)-1
	slider.step = 1
	slider.value = 1
	slider.custom_minimum_size.y = 48
	slider.value_changed.connect(func(value: float) -> void: info.text = "新分队 %d / 原舰队 %d" % [int(value),int(f.units)-int(value)])
	dialog.add_child(slider)
	_describe_control(slider,"拆分数量","拖动滑块设置新分队的单位数；原队与新队都至少保留 1 单位，点确认拆分才执行。")
	_label(dialog,"消耗 1 次行动。等级和模块保留，每支舰队至少 1 单位。",17,MUTED)
	_button(dialog,"确认拆分",func() -> void: _perform("split",{"fleet":id,"units":int(slider.value)}),true)

func _configure_dialog() -> void:
	var f: Dictionary = game.fleet(selected_fleet)
	if f.is_empty() or f.owner != game.state.player:
		_notify("请先选择己方驻守舰队或太空舰队。",true)
		return
	var id: String = selected_fleet
	var dialog := _open_modal("舰队配置")
	var name_edit := LineEdit.new()
	name_edit.text = str(f.name)
	name_edit.max_length = 24
	name_edit.custom_minimum_size.y = 44
	_label(dialog,"舰队名称 · 最多 24 个字符",14,MUTED)
	dialog.add_child(name_edit)
	_describe_control(name_edit,"舰队名称","编辑编队名称，点击保存配置才应用。")
	_label(dialog,"舰队类型 · 决定战斗与航行特长",14,MUTED)
	var kind := _option(dialog,Rules.TYPES,Rules.TYPES.find(str(f.type)),func(_index: int) -> void: pass)
	_label(dialog,"星图标记 · 仅改变外观",14,MUTED)
	var icon := _option(dialog,["楔形","菱形"],0 if f.icon == "楔形" else 1,func(_index: int) -> void: pass)
	var color := ColorPickerButton.new()
	color.color = Color(str(f.color))
	color.custom_minimum_size.y = 44
	color.edit_alpha = false
	_label(dialog,"舰队涂装 · 点击色块选择颜色",14,MUTED)
	dialog.add_child(color)
	_describe_control(color,"舰队涂装","选择舰队在星图中的颜色，不改变战力或阵营，保存配置后生效。")
	_label(dialog,"模块槽 %d · 高级模块需 LV.2\n改装花费：2 信用 +（2 + 模块数量）材料" % mini(5,int(f.level)+1),17,MUTED)
	var checks: Array[CheckBox] = []
	for module in Rules.MODULES:
		var check := CheckBox.new()
		check.text = module
		check.button_pressed = module in f.modules
		check.custom_minimum_size.y = 38
		dialog.add_child(check)
		_describe_control(check,module,str(Help.MODULE_HELP[module])+" 勾选只编辑草案，点击保存配置才支付费用并应用。")
		_label(dialog,str(Help.MODULE_HELP[module]),14,MUTED)
		checks.append(check)
	_button(dialog,"保存配置",func() -> void:
		var modules: Array[String] = []
		for check in checks:
			if check.button_pressed: modules.append(check.text)
		_perform("configure",{"fleet":id,"name":name_edit.text,"type":Rules.TYPES[kind.selected],"icon":icon.get_item_text(icon.selected),"color":color.color.to_html(false),"modules":modules}),true)

func _upgrade_dialog() -> void:
	var f: Dictionary = game.fleet(selected_fleet)
	if f.is_empty() or f.owner != game.state.player:
		_notify("请先选择己方舰队。",true)
		return
	var id: String = selected_fleet
	var dialog := _open_modal("舰队升级 · LV.%d" % int(f.level))
	_label(dialog,"每次升级 6 信用 / 3 材料。等级、战力和模块槽增加，并选择一项专精。最高 LV.5。",17,MUTED)
	var descriptions: Dictionary = {"attack":"进攻战力 +1","defense":"防守战力 +1","speed":"每次太空移动少耗 1 燃料","gate":"通过星门免燃料","range":"远程攻击少耗 1 情报","sensor":"遗迹扫描距离 +60","cargo":"运输舱容量 +8","repair":"每轮修复 1 个受损单位","retreat":"被拦截概率降低 15%","influence":"威慑战力 +2"}
	for key in Rules.UPGRADES:
		_button(dialog,"%s · %s" % [Rules.UPGRADES[key],descriptions[key]],func() -> void:
			_confirm_action("升级" + str(Rules.UPGRADES[key]),"6 信用 / 3 材料。" + str(descriptions[key]),"upgrade",{"fleet":id,"direction":key}))

func _cargo_dialog(id: String) -> void:
	var f: Dictionary = game.fleet(id)
	if f.is_empty(): return
	var dialog := _open_modal("运输舱与补给")
	var status: Array[String] = []
	for key in ["credits","materials","intel","fuel"]: status.append("%s %d" % [Rules.RESOURCE_NAMES[key],int(f.get("cargo",{}).get(key,0))])
	_label(dialog,"舰载物资：" + " / ".join(status),18,MUTED)
	_label(dialog,"在己方星球装卸。被击毁后物资丢失，敌方可掠夺。",17,ORANGE)
	var resources: Array[String] = ["credits","materials","intel","fuel"]
	var choice := _option(dialog,["信用点","材料","情报","燃料"],1,func(_index: int) -> void: pass)
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = int(f.units)*4 + int(f.get("upgrades",{}).get("cargo",0))*8
	amount.value = 1
	amount.custom_minimum_size.y = 48
	_label(dialog,"装卸数量 · 点击数字或箭头调整",14,MUTED)
	dialog.add_child(amount)
	_describe_control(amount,"装卸数量","输入或调整本次装卸数量；还需点击装载或卸载按钮才会转移物资。")
	var row := _row(dialog)
	_button(row,"装载补给",func() -> void: _perform("cargo",{"fleet":id,"resource":resources[choice.selected],"amount":int(amount.value),"unload":false}),true)
	_button(row,"卸载补给",func() -> void: _perform("cargo",{"fleet":id,"resource":resources[choice.selected],"amount":int(amount.value),"unload":true}))

func _policy_dialog(id: String) -> void:
	var dialog := _open_modal("星球治理")
	for entry in [["直接统治","收入较高，好感 -10"],["自治管理","产出减半，好感 +15"],["保护协议","2 信用，好感 +20，每轮维持 1 信用"],["掠夺开发","立即 +10 信用，好感 -45、声望 -8，可能叛乱"],["重建星球","4 材料，好感 +25、产出 +1"]]:
		var action_button := _button(dialog,str(entry[0]),func() -> void: _confirm_action(str(entry[0]),str(entry[1]),"policy",{"planet":id,"policy":entry[0]}))
		_describe_button(action_button,str(entry[1]),"治理选中的己方星球："+str(entry[1])+"。每颗星球每轮只能调整一次，确认后应用。")

func _gate_dialog(id: String) -> void:
	var g: Dictionary = game.gate(id)
	if g.is_empty(): return
	var dialog := _open_modal("星门 · " + id)
	_label(dialog,"%s ⇄ %s\n需要邻接己方领地或附近的己方舰队。" % [game.planet(str(g.a)).name,game.planet(str(g.b)).name],19,MUTED)
	for choice in ["占领","封锁","破坏","修复"]:
		_button(dialog,choice,func() -> void: _confirm_action("星门" + choice,"消耗 1 行动" + (" / 3 材料。" if choice == "修复" else "。"),"gate",{"gate":id,"choice":choice,"fleet":selected_fleet}))

func _diplomacy_dialog() -> void:
	var dialog := _open_modal("外交、交易与协议")
	_label(dialog,"每轮一次。普通交易无需行动点；所有结果会改变资源、关系或协议。",17,MUTED)
	var factions: Array[String] = []
	for faction in ["帝国","联盟","混沌"]:
		if faction != game.state.player: factions.append(faction)
	var commander_hint := _label(dialog,str(game.state.commanders[factions[0]].detail),16,CYAN)
	var select := _option(dialog,factions,0,func(index: int) -> void: commander_hint.text = str(game.state.commanders[factions[index]].detail))
	var options: Dictionary = {"结盟":"4 信用，4 轮联盟与通行；好感要求：帝国 0 / 联盟 -25 / 混沌 15","提出停战":"3 轮停止交战","赠送资源":"4 信用，好感 +20","资源交易":"4 信用兑换 4 材料；好感要求：联盟 -40，其他 -25","交换情报":"2 材料兑换 4 情报，并获得对方当前掌握的航图报告；不会持续追踪","请求援军":"3 信用；盟友或好感 ≥25","开放星门":"2 信用，4 轮通行权","保护协议":"3 信用，好感 +15","共同抗敌":"2 情报，声望 +5、好感 +20","交换领地":"双方交换一颗非首都星球，好感 ≥25","取消协议":"撤销所有协议，好感 -10","宣布背叛":"撤销协议，好感 -40、声望 -10"}
	for choice in options:
		var action_button := _button(dialog,str(choice),func() -> void: _confirm_action(str(choice),str(options[choice]),"diplomacy",{"faction":factions[select.selected],"choice":choice}))
		_describe_button(action_button,str(options[choice]),"与所选势力进行外交："+str(options[choice])+"。每轮一次外交，确认后才应用。")

func _faction_manual(faction: String) -> void:
	var dialog := _open_modal(faction + " · 阵营手册")
	var text: Dictionary = {"帝国":"残余正统人类帝国\n定位：防守反击、高科技、精锐舰队。\n统御秩序：星球防守战力 +1。星门锁域保护己方星球。\n限制：舰队上限 12、远程多消耗燃料、扩张成本较高。","联盟":"自由星域联盟\n定位：快速扩张、策反渗透、人海战术。\n开局多一颗星球，扩张费用更低，购买舰队多 1 单位，策反成本更低。\n好感下降后可能发生叛乱，注意保护领地。","混沌":"破碎星域议会\n定位：游击、交易、掠夺和残局得分。\n进攻平局获胜，暗网技能补给情报与燃料；劫掠舰队降低远程消耗。\n正面交战仍应避开强大的守卫舰队。"}
	_label(dialog,str(text.get(faction,"外星远征军不完全遵守普通外交规则。")),19,MUTED)
	_line(dialog)
	_label(dialog,"公元 4729 年，人类研发星门传送技术。统一银河的帝国收回军事与星门权，边境星球因此反抗。百年内战后，帝国据守核心，联盟控制边境，破碎星域成为盗匪、商会与流亡军队的家园。\n\n如今正值星门破碎纪元 100 年。未知星门中，新的敌人正在接近。",17,MUTED)

# The reference manual remains available after onboarding, but it is never
# used as the first-play tutorial. Progress comes only from successful actions.
func _start_practice_tutorial() -> void:
	_close_modal()
	game.new_game(Rules.FACTIONS[faction_index],0,seed_code)
	var home: String = game.capital_for(str(game.state.player))
	var expansion: String = {"帝国":"p14","联盟":"p13","混沌":"p3"}[str(game.state.player)]
	var enemy: String = {"帝国":"p15","联盟":"p8","混沌":"p6"}[str(game.state.player)]
	var fleet_id: String = str(game.stationed(home,str(game.state.player))[0].id)
	var rival: String = "联盟" if game.state.player != "联盟" else "帝国"
	game.planet(enemy).owner = rival
	game.planet(enemy).militia = 0
	game.spawn_fleet(rival,enemy,2,"守卫","前线守备队")
	game.update_gates()
	game.refresh_intel()
	game.state.tutorial = {"active":true,"step":0,"home":home,"expand":expansion,"enemy":enemy,"fleet":fleet_id}
	tutorial_active = true
	tutorial_step = 0
	screen_state = "game"
	selected_planet = ""
	selected_fleet = ""
	selected_gate = ""
	command = ""
	message = "舰桥已就绪。先点击星图中标注「当前目标」的首都。"
	if is_instance_valid(scroll): scroll.scroll_vertical = 0
	_autosave()
	_schedule_build()

func _tutorial_target() -> String:
	var t: Dictionary = game.state.tutorial
	match tutorial_step:
		0,2,9: return str(t.home)
		1,4,5: return str(t.expand)
		6,7: return str(t.enemy)
	return ""

func _tutorial_instruction() -> Array:
	var t: Dictionary = game.state.tutorial
	var home: String = str(game.planet(str(t.home)).name)
	var expansion: String = str(game.planet(str(t.expand)).name)
	var enemy: String = str(game.planet(str(t.enemy)).name)
	return [
		["接管你的舰队","点击星图中高亮的「%s」，选中首都驻军。" % home,"定位星图"],
		["建立第一个据点","点击「扩张」，再点灰色星球「%s」，确认占领。消耗 1 行动和信用点。" % expansion,"选择扩张"],
		["为出航补充兵力","点击「增援」，再点「%s」并确认。驻军增加 1 单位，用完本轮最后 1 次行动。" % home,"选择增援"],
		["完成一个回合","点击「结束本轮」并确认。观察顶部行动恢复为 2，领地产出加入储备。" ,"结束本轮"],
		["通过星门调动","先点「%s」选择主力，再点「舰队调度」，然后点「%s」确认驻守。也可拖动舰标到目标。" % [home,expansion],"选择调度"],
		["升级主力舰队","主力已抵达。打开升级菜单，选择「攻击」专精并确认；花费 6 信用 / 3 材料。","升级主力"],
		["夺取前线星球","点击「进攻」，选择「%s」，比较战力后选择「直接突袭」并确认。" % enemy,"选择进攻"],
		["治理新领地","占领还需要治理。为「%s」选择「自治管理」并确认，提高当地好感。" % enemy,"治理新领地"],
		["用外交获取情报","打开外交菜单，选择「交换情报」并确认。用 2 材料换取 4 情报及对方航图。","打开外交"],
		["使用阵营技能","选择当前阵营技能，再点击高亮首都并确认。主动技能每轮只能使用一次。","选择技能"],
		["保存你的战果","选择一个手动存档槽，点击「保存当前进度」。教学进度也会随战局保存。","前往存档"],
		["你已完成第一次实战","已掌握扩张、增援、回合、调度、升级、进攻、治理、外交与存档。继续这场战役，或按开场选择开启新战役。","继续这场战役"]
	][tutorial_step]

func _tutorial_banner(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(INK,CYAN,1,4))
	parent.add_child(panel)
	var box := _vbox(panel,6)
	var entry: Array = _tutorial_instruction()
	_label(box,"实战教学  %d / 11 · %s" % [mini(tutorial_step+1,11),entry[0]],18,CYAN,true)
	_label(box,str(entry[1]),16,TEXT)
	var row: BoxContainer = _row(box,8) if size.x >= 600 else _vbox(box,6)
	var action := _button(row,str(entry[2]),_tutorial_focus,true)
	_describe_button(action,"当前教学目标",str(entry[1])+" 只有真实操作成功后才进入下一步。")
	if tutorial_step == 11:
		_button(row,"开启所选战役",func() -> void:
			_mark_tutorial_seen()
			_start_campaign())
	else:
		_button(row,"跳过教学",_skip_tutorial)
		_label(box,"敌军暂缓行动 · 完成操作后自动推进",13,MUTED)

func _tutorial_focus() -> void:
	match tutorial_step:
		0:
			_reveal_map()
		1,2,6:
			command = {1:"expand",2:"reinforce",6:"attack"}[tutorial_step]
			if tutorial_step == 6: selected_fleet = str(game.state.tutorial.fleet)
			reveal_map_pending = true
			_schedule_build()
		3: _end_turn_dialog()
		4:
			# Selecting the fleet is part of the exercise, not done by the hint.
			command = "dispatch"
			reveal_map_pending = true
			_schedule_build()
		5:
			selected_fleet = str(game.state.tutorial.fleet)
			_upgrade_dialog()
		7: _policy_dialog(str(game.state.tutorial.enemy))
		8: _diplomacy_dialog()
		9:
			command = "skill"
			reveal_map_pending = true
			_schedule_build()
		10: _reveal_section("战役存档")
		11: _finish_tutorial()

func _reveal_section(title: String) -> void:
	var labels := page.find_children("*","Label",true,false)
	for label in labels:
		if label.text == title:
			scroll.ensure_control_visible(label)
			return

func _tutorial_allows(action: String, args: Dictionary) -> bool:
	var t: Dictionary = game.state.tutorial
	match tutorial_step:
		1: return action == "expand" and args.get("planet") == t.expand
		2: return action == "reinforce" and args.get("planet") == t.home
		4: return action == "move" and args.get("fleet") == t.fleet and args.get("planet") == t.expand
		5: return action == "upgrade" and args.get("fleet") == t.fleet and args.get("direction") == "attack"
		6: return action == "attack" and args.get("fleet") == t.fleet and args.get("planet") == t.enemy and args.get("method") == "直接突袭"
		7: return action == "policy" and args.get("planet") == t.enemy and args.get("policy") == "自治管理"
		8: return action == "diplomacy" and args.get("choice") == "交换情报"
		9: return action == "skill" and args.get("planet") == t.home
	return false

func _advance_tutorial() -> void:
	tutorial_step = mini(11,tutorial_step+1)
	game.state.tutorial.step = tutorial_step
	if tutorial_step == 4:
		selected_fleet = ""
		selected_planet = ""
	if tutorial_step == 5:
		selected_fleet = str(game.state.tutorial.fleet)
		selected_planet = str(game.state.tutorial.expand)
	_autosave()
	reveal_map_pending = true
	_schedule_build()

func _mark_tutorial_seen() -> void:
	tutorial_seen = true
	var preferences := ConfigFile.new()
	preferences.set_value("tutorial","seen",true)
	var error: Error = preferences.save(save_directory.path_join("onboarding.cfg"))
	if error != OK: _notify("教学已完成，但首次游玩偏好保存失败。",true)

func _finish_tutorial() -> void:
	_mark_tutorial_seen()
	tutorial_active = false
	game.state.tutorial.active = false
	command = ""
	message = "教学结束。敌方将在下一次结束本轮时行动；继续扩张并争夺首都。"
	_autosave()
	_schedule_build()

func _skip_tutorial() -> void:
	_confirm("跳过实战教学","结束引导并继续当前标准战役，敌方从下次结束本轮开始行动。",_finish_tutorial)

func _tutorial_help() -> void:
	if tutorial_active:
		_tutorial_focus()
		return
	var dialog := _open_modal("新手指南")
	_label(dialog,"实战教学会创建一场新的教学战役。当前战局请先保存。",18,TEXT)
	_button(dialog,"开始实战教学",func() -> void:
		_confirm("开始实战教学","用新的教学战役替换当前进度；已保存的槽位保留。",_start_practice_tutorial),true)
	_button(dialog,"查看规则手册",func() -> void: _show_guide(0))

func _show_guide(step: int) -> void:
	guide_step = clampi(step,0,GUIDE.size()-1)
	var dialog := _open_modal("新手指南   %d / %d" % [guide_step+1,GUIDE.size()])
	_label(dialog,str(GUIDE[guide_step][0]),28,CYAN,true)
	_label(dialog,str(GUIDE[guide_step][1]),21,TEXT)
	_space(dialog,20)
	var row := _row(dialog)
	var previous := _button(row,"上一步",func() -> void: _show_guide(guide_step-1))
	previous.disabled = guide_step == 0
	if previous.disabled: previous.get_node("ActionCaption").add_theme_color_override("font_color",MUTED)
	_button(row,"完成" if guide_step == GUIDE.size()-1 else "下一步",func() -> void:
		if guide_step == GUIDE.size()-1: _close_modal()
		else: _show_guide(guide_step+1),true)

func _end_turn_dialog() -> void:
	if tutorial_active and tutorial_step != 3:
		_notify("先完成当前教学目标，再结束本轮。",true)
		return
	_confirm("结束本轮","还有 %d 次行动未用。结束后结算资源、AI 行动、战争事件与外星威胁。" % int(game.state.ap),func() -> void:
		var result: Dictionary = game.end_turn()
		if result.ok and tutorial_active: _advance_tutorial()
		_after_action(result)
		if result.ok and not tutorial_active: _show_replay(true))

func _restart_dialog() -> void:
	_confirm("重新选择阵营","返回开场界面。已有存档不会删除，当前未保存进度会丢失。",func() -> void:
		screen_state = "start"
		tutorial_active = false
		selected_planet = ""
		selected_fleet = ""
		command = ""
		scroll.scroll_vertical = 0
		_schedule_build())

func _perform(action: String, args: Dictionary) -> void:
	if tutorial_active and not _tutorial_allows(action,args):
		_notify("先完成当前目标；也可以点击「跳过教学」自由游玩。",true)
		return
	var result: Dictionary = game.act(action,args)
	if result.ok and tutorial_active: _advance_tutorial()
	_after_action(result)
	if result.ok:
		pending_effects = result.get("visuals",[]).duplicate(true)
		effect_timer = 0.0
	if result.ok and action == "attack":
		var p: Dictionary = game.planet(str(args.get("planet","")))
		if not p.is_empty() and p.status == "待治理": _policy_dialog(str(p.id))

func _after_action(result: Dictionary) -> void:
	message = str(result.message)
	if result.ok:
		_close_modal()
		command = ""
		if game.fleet(selected_fleet).is_empty(): selected_fleet = ""
		_autosave()
		_schedule_build()
	_notify(message,not bool(result.ok))
	if result.ok and game.state.phase == "finished": _result_dialog()

func _result_dialog() -> void:
	var dialog := _open_modal("战役结算")
	_label(dialog,"%s获胜" % game.state.winner,32,CYAN,true)
	_label(dialog,str(game.state.result),21,TEXT)
	if int(game.state.mode)==8 and game.state.winner==game.state.player and int(game.state.series.chapter)<3:
		_button(dialog,"进入下一章",func() -> void:
			var result: Dictionary = game.advance_series()
			selected_planet = ""
			selected_fleet = ""
			selected_gate = ""
			_after_action(result),true)
	for faction in Rules.FACTIONS: _label(dialog,"%s：%d 分" % [faction,game.score(faction)],18,Color(Rules.COLORS[faction]))
	_button(dialog,"返回阵营选择",func() -> void:
		_close_modal()
		screen_state = "start"
		scroll.scroll_vertical = 0
		_schedule_build(),true)

func _ghost_dialog(id: String) -> void:
	var report: Dictionary = game.state.fog.fleets.get(id,{})
	if report.is_empty():
		_notify("这条舰队信号已经失效。",true)
		return
	var dialog := _open_modal("旧舰队信号")
	_label(dialog,"%s\n%s · 最后确认于第 %d 轮" % [report.get("name","未知舰队"),report.get("owner","未知势力"),int(report.get("seen_turn",0))],24,CYAN,true)
	_label(dialog,"当前位置只是最后一次发现的位置。敌方可能已经移动、增援或撤离；使用侦察舰或主动扫描更新信息。",18,MUTED)
	_button(dialog,"主动扫描附近区域",func() -> void: _confirm_action("主动扫描","1 行动 / 2 情报；需要侦察舰或侦察模块。","scan",{"fleet":selected_fleet}))

func _story_dialog() -> void:
	var id: String = str(game.state.story.pending)
	if id == "":
		var dialog := _open_modal("战役事务")
		_label(dialog,"当前没有待处理的剧情事件。已完成事务：%d 条。" % game.state.story.history.size(),18,MUTED)
		for entry in game.state.story.history: _label(dialog,str(entry),16,CYAN)
		return
	var info: Dictionary = Systems.story_info(id)
	var dialog := _open_modal(str(info.title))
	_label(dialog,str(info.body),19,TEXT)
	for i in range(info.choices.size()):
		var choice: Array = info.choices[i]
		var button := _button(dialog,str(choice[0]),func() -> void: _perform("story",{"choice":i}),i==0)
		_describe_button(button,str(choice[1]).split("；")[0],str(choice[1])+"\n确认后会记录这项选择，剧情不会重复出现。",i==0)
		_label(dialog,str(choice[1]),16,MUTED)

func _show_replay(auto_play: bool = false) -> void:
	var events: Array = game.state.replay.get("events",[])
	var dialog := _open_modal("回合战况回放")
	# Fill regular windows; keep scrolling available if the window becomes short.
	dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replay_events = events
	replay_index = -1
	replay_label = _label(dialog,"本轮共 %d 个可见战况事件。隐藏行动不会被凭空显示，只保留最后发现的位置。" % events.size(),18,MUTED)
	var controls := GridContainer.new()
	controls.columns = 2
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog.add_child(controls)
	_button(controls,"上一个事件",func() -> void:
		replay_playing = false
		_replay_step(-1))
	_button(controls,"下一个事件",func() -> void:
		replay_playing = false
		_replay_step(1),true)
	_button(controls,"自动播放",func() -> void:
		if replay_index >= replay_events.size()-1: replay_index = -1
		replay_playing = true
		replay_timer = 0.0)
	_button(controls,"跳过回放",func() -> void: _close_modal())
	for button in controls.get_children(): button.custom_minimum_size.y = 64*ui_scale
	replay_map = StarMap.new()
	replay_map.game = game
	replay_map.read_only = true
	replay_map.height_limit = maxf(140,modal_panel.size.y-460*ui_scale)
	replay_map.display_frame = game.state.replay.initial
	replay_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(replay_map)
	replay_followup = auto_play
	if events.is_empty(): _label(dialog,"敌方没有在你已知范围内留下可见变化。",17,MUTED)
	if auto_play and not events.is_empty():
		replay_playing = true
		replay_timer = 0.0

func _replay_step(direction: int = 1) -> void:
	if replay_events.is_empty(): return
	replay_index = clampi(replay_index + direction,0,replay_events.size()-1)
	var event: Dictionary = replay_events[replay_index]
	if is_instance_valid(replay_label): replay_label.text = "第 %d / %d\n%s" % [replay_index+1,replay_events.size(),event.text]
	if is_instance_valid(replay_map):
		replay_map.display_frame = event.frame
		replay_map.play_effect(event)
	replay_timer = 0.95
	if replay_index >= replay_events.size()-1: replay_playing = false

func _post_round() -> void:
	if is_instance_valid(modal): return
	if tutorial_active: return
	if game.state.phase=="finished": _result_dialog()
	elif str(game.state.story.pending)!="": _story_dialog()

func _save_path(slot: String) -> String:
	return save_directory.path_join("campaign_%s.json" % ("auto" if slot == "auto" else "slot_" + slot))

func _slot_time(slot: String) -> String:
	if not FileAccess.file_exists(_save_path(slot)): return "空"
	var file := FileAccess.open(_save_path(slot),FileAccess.READ)
	if file == null: return "无法读取"
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return "损坏"
	var data: Variant = parser.data
	return str(data.get("saved_at","未知时间")) if data is Dictionary else "损坏"

func _save(slot: String) -> void:
	var finishing: bool = tutorial_active and tutorial_step == 10
	if finishing:
		tutorial_step = 11
		game.state.tutorial.step = 11
	var error: String = game.save_game(slot,save_directory)
	if finishing:
		if error != "":
			tutorial_step = 10
			game.state.tutorial.step = 10
		else:
			_mark_tutorial_seen()
			_autosave()
			reveal_map_pending = true
	_notify("本地存档已保存。" if error == "" else error,error != "")
	_schedule_build()

func _autosave() -> void:
	if not auto_save: return
	var error: String = game.save_game("auto",save_directory)
	if error != "": _notify(error,true)

func _load(slot: String) -> void:
	var error: String = game.load_game(slot,save_directory)
	if error != "":
		_notify(error,true)
		return
	_close_modal()
	tutorial_active = bool(game.state.get("tutorial",{}).get("active",false))
	tutorial_step = int(game.state.get("tutorial",{}).get("step",0))
	screen_state = "game"
	selected_planet = ""
	selected_fleet = ""
	selected_gate = ""
	command = ""
	if tutorial_active:
		selected_fleet = str(game.state.tutorial.fleet)
		selected_planet = str(game.fleet(selected_fleet).get("station",""))
	message = "本地存档已读取，完整战区状态恢复。"
	scroll.scroll_vertical = 0
	_schedule_build()
	_notify(message)

func _load_dialog() -> void:
	var dialog := _open_modal("读取本地战役")
	for slot in ["1","2","3","auto"]:
		_button(dialog,"%s · %s" % ["自动存档" if slot == "auto" else "槽位 " + slot,_slot_time(slot)],func() -> void: _load(slot))
	_label(dialog,"旧版 star_gate_save.json 不会被覆盖。它只记录部分数值，无法恢复完整战役。",16,MUTED)

func _confirm_action(title: String, body: String, action: String, args: Dictionary) -> void:
	_confirm(title,body,func() -> void: _perform(action,args))

func _confirm(title: String, body: String, callback: Callable) -> void:
	var dialog := _open_modal(title)
	_label(dialog,body,20,TEXT)
	_space(dialog,12)
	var confirm_button := _button(dialog,"确认执行",func() -> void:
		_close_modal()
		callback.call(),true)
	_describe_button(confirm_button,"确认 · "+title,body+"\n确认将执行「"+title+"」，取消则不改变战局。",true)
	_button(dialog,"取消",_close_modal)

func _open_modal(title: String) -> VBoxContainer:
	replay_followup = false
	_close_modal()
	modal = Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.06,0.10,0.18,0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	modal_panel = panel
	modal.add_child(panel)
	_layout_modal()
	panel.add_theme_stylebox_override("panel",_style(PANEL,LINE,1,4))
	var frame := _vbox(panel,16)
	var header := _row(frame)
	_label(header,title,24,CYAN,true)
	var close := _button(header,"关闭",_close_modal)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_line(frame)
	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroller)
	_build_help_bar(frame)
	return _vbox(scroller,14)

func _layout_modal() -> void:
	if not is_instance_valid(modal_panel): return
	var panel_size := Vector2(minf(700,size.x-36),minf(760,size.y-48))
	modal_panel.size = panel_size
	modal_panel.position = (size-modal_panel.size)/2
	if is_instance_valid(replay_map):
		replay_map.height_limit = maxf(140,panel_size.y-460*ui_scale)
		replay_map.custom_minimum_size.y = replay_map.height_limit

func _close_modal() -> void:
	duel_panel_open = false
	var follow: bool = replay_followup
	replay_followup = false
	replay_playing = false
	replay_map = null
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null
	modal_panel = null
	if follow: _post_round.call_deferred()

func _notify(value: String, error: bool = false) -> void:
	if is_instance_valid(toast):
		remove_child(toast)
		toast.queue_free()
	toast = PanelContainer.new()
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 20
	toast.offset_right = -20
	toast.offset_top = -90
	toast.offset_bottom = -20
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override("panel",_style(INK,RED if error else CYAN,1,4))
	_label(toast,value,18,RED if error else TEXT)
	toast_seconds = 6.0

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(help_overlay): _close_help()
		elif help_mode:
			help_mode = false
			for item in help_toggles:
				if is_instance_valid(item): item.text = "？ 说明模式"
		elif is_instance_valid(modal): _close_modal()
		else:
			command = ""
			_schedule_build()

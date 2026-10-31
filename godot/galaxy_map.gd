extends Control

signal target_selected(kind: String, id: String)
signal fleet_dropped(id: String, target: Dictionary)
signal fleet_menu(id: String)

const Rules = preload("res://game_state.gd")
var game: Rules
var selected_planet: String = ""
var selected_fleet: String = ""
var selected_gate: String = ""
var command: String = ""
var tutorial_target: String = ""
var zoom: float = 1.0
var pan := Vector2.ZERO
var drag_id: String = ""
var press_pos := Vector2.ZERO
var pointer := Vector2.ZERO
var down: bool = false
var moved: bool = false
var held: float = 0.0
var touches: Dictionary = {}
var was_pinch: bool = false
var font: Font
var last_width: float = 0.0
var height_limit: float = 900.0
var display_frame: Dictionary = {}
var read_only: bool = false
var visual_event: Dictionary = {}
var visual_time: float = 0.0

func play_effect(event: Dictionary) -> void:
	visual_event = event
	visual_time = 0.9
	queue_redraw()

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	font = get_theme_default_font()
	resized.connect(_resize)
	get_window().focus_exited.connect(_cancel_gesture)
	_resize()

func _resize() -> void:
	if not is_equal_approx(last_width,size.x):
		last_width = size.x
		custom_minimum_size.y = minf(height_limit,maxf(400,size.x * 0.83))
	queue_redraw()

func _process(delta: float) -> void:
	if visual_time > 0:
		visual_time = maxf(0,visual_time-delta)
		queue_redraw()
	if down and not moved:
		held += delta
		if held >= 0.6 and drag_id != "":
			var id: String = drag_id
			down = false
			drag_id = ""
			fleet_menu.emit(id)

func world_scale() -> float:
	# Uniform fit in both axes: a short, wide window must not crop the bottom.
	return maxf(0.001,minf(size.x / 1000.0,size.y / 1040.0)) * zoom

func _cancel_gesture() -> void:
	down = false
	moved = false
	drag_id = ""
	touches.clear()
	was_pinch = false
	held = 0.0
	queue_redraw()

func to_screen(world: Vector2) -> Vector2:
	return (world - Vector2(500,410)) * world_scale() + size * 0.5 + pan

func to_world(screen: Vector2) -> Vector2:
	return (screen - size * 0.5 - pan) / world_scale() + Vector2(500,410)

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func zoom_by(amount: float, center: Vector2 = Vector2(-1,-1)) -> void:
	if center.x < 0: center = size * 0.5
	var world: Vector2 = to_world(center)
	zoom = clampf(zoom * amount,0.72,2.5)
	pan += center - to_screen(world)
	queue_redraw()

func fleet_point(f: Dictionary) -> Vector2:
	var pos: Vector2 = game.position_of(f)
	var screen: Vector2 = to_screen(pos)
	# Screen-space spacing keeps a larger garrison marker clear of its planet at every zoom.
	if f.station != "":
		var planet_radius: float = 27*clampf(world_scale(),0.43 if read_only else 0.70,1.4)
		screen += Vector2(1,-1).normalized()*(planet_radius+fleet_radius()+9)
	return screen

func fleet_radius() -> float:
	return 20.0*clampf(minf(size.x/900.0,size.y/747.0),0.55 if read_only else 0.80,1.15)

func hit_at(screen: Vector2) -> Dictionary:
	var radius: float = clampf(world_scale() * 24,15,35)
	# Only the selected garrison gets a draggable icon; free fleets are always visible.
	for f in game.fleet_views():
		if (f.station == "" or f.id == selected_fleet) and fleet_point(f).distance_to(screen) < fleet_radius()*1.42+4:
			return {"kind":"fleet" if f.live else "ghost","id":f.id,"x":f.x,"y":f.y,"owner":f.owner}
	for p in game.state.planets:
		if to_screen(game.position_of(p)).distance_to(screen) < radius + 8:
			return {"kind":"planet","id":p.id,"planet":p.id,"x":p.x,"y":p.y,"owner":game.planet_view(str(p.id)).owner}
	for g in game.state.gates:
		var mid: Vector2 = (game.position_of(game.planet(str(g.a))) + game.position_of(game.planet(str(g.b)))) / 2
		if to_screen(mid).distance_to(screen) < maxf(10,world_scale() * 10):
			return {"kind":"gate","id":g.id,"x":mid.x,"y":mid.y,"owner":g.owner}
	var point: Vector2 = to_world(screen)
	return {"kind":"space","id":"","x":clampf(point.x,25,975),"y":clampf(point.y,30,790),"owner":"无主"}

func _begin(pos: Vector2) -> void:
	down = true
	moved = false
	held = 0.0
	press_pos = pos
	pointer = pos
	var hit: Dictionary = hit_at(pos)
	drag_id = ""
	if hit.kind == "fleet" and hit.owner == game.state.player: drag_id = str(hit.id)
	elif hit.kind == "planet" and hit.id == selected_planet:
		var f: Dictionary = game.fleet(selected_fleet)
		if not f.is_empty() and f.station == hit.id and f.owner == game.state.player: drag_id = selected_fleet

func _motion(pos: Vector2) -> void:
	if not down: return
	if pos.distance_to(press_pos) > 7: moved = true
	if moved and drag_id == "": pan += pos - pointer
	pointer = pos
	pan.x = clampf(pan.x,-size.x * zoom,size.x * zoom)
	pan.y = clampf(pan.y,-size.y * zoom,size.y * zoom)
	queue_redraw()

func _release(pos: Vector2) -> void:
	if not down: return
	down = false
	var hit: Dictionary = hit_at(pos)
	var id: String = drag_id
	drag_id = ""
	if was_pinch:
		was_pinch = false
	elif moved and id != "": fleet_dropped.emit(id,hit)
	elif not moved:
		if hit.kind == "space" and selected_fleet != "" and command == "dispatch": fleet_dropped.emit(selected_fleet,hit)
		else: target_selected.emit(str(hit.kind),str(hit.id))
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if game == null or read_only: return
	if event is InputEventMouse and event.device == -1: return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed: zoom_by(1.1,button.position)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed: zoom_by(1.0 / 1.1,button.position)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed: _begin(button.position)
			else: _release(button.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_motion((event as InputEventMouseMotion).position)
		if down: accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.canceled:
			_cancel_gesture()
			accept_event()
			return
		if touch.pressed:
			touches[touch.index] = touch.position
			if touches.size() == 1: _begin(touch.position)
			else:
				was_pinch = true
				drag_id = ""
		else:
			touches.erase(touch.index)
			if touches.is_empty(): _release(touch.position)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if not touches.has(drag.index): return
		if touches.size() >= 2:
			var values: Array = touches.values()
			var before: float = (values[0] as Vector2).distance_to(values[1])
			touches[drag.index] = drag.position
			values = touches.values()
			var after: float = (values[0] as Vector2).distance_to(values[1])
			if before > 1: zoom_by(after / before,(values[0] + values[1]) / 2)
		else:
			touches[drag.index] = drag.position
			_motion(drag.position)
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_by((event as InputEventMagnifyGesture).factor,(event as InputEventMagnifyGesture).position)
		accept_event()

func _text(at: Vector2, value: String, font_size: int, color: Color, width: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(font,at + Vector2(0,font_size * 0.8),value,align,width,font_size,color)

func _draw() -> void:
	if game == null or font == null or game.state.is_empty() or size.x < 2 or size.y < 2: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("061528"))
	# Sparse stars and world-coordinate ticks keep navigation legible while panning.
	for i in range(55):
		var point := Vector2(fposmod(i*137.713+17,size.x),fposmod(i*i*17.917+29,size.y))
		var glow: float = 0.10+float(i%5)*0.035
		draw_circle(point,1.0 if i%13 == 0 else 0.6,Color(0.72,0.81,0.94,glow))
	draw_rect(Rect2(Vector2(8,8),size-Vector2(16,16)),Color("203d57"),false,1)
	if not read_only:
		for coordinate in range(0,1001,100):
			var x: float = to_screen(Vector2(coordinate,0)).x
			if x > 30 and x < size.x-30:
				draw_line(Vector2(x,8),Vector2(x,13),Color("42647e"),1)
				if coordinate%200==0: _text(Vector2(x-18,16),str(coordinate),10,Color("6f8da5"),36)
			var y: float = to_screen(Vector2(0,coordinate)).y
			if y > 40 and y < size.y-30:
				draw_line(Vector2(size.x-13,y),Vector2(size.x-8,y),Color("42647e"),1)
				if coordinate%200==0: _text(Vector2(size.x-41,y-5),str(coordinate),10,Color("6f8da5"),26)
	var shown: Dictionary = game.observer_frame() if display_frame.is_empty() else display_frame
	for g in shown.gates:
		var a: Vector2 = to_screen(game.position_of(game.planet(str(g.a))))
		var b: Vector2 = to_screen(game.position_of(game.planet(str(g.b))))
		var line_color: Color = Color(Color(Rules.COLORS.get(g.owner,"7d8594")).lightened(0.2),0.45) if g.owner != "无主" else Color("304c66")
		if g.broken: line_color = Color("af5b61")
		if int(g.blocked) >= int(shown.turn): line_color = Color("b78b4e")
		if g.broken: draw_dashed_line(a,b,line_color,1,5,true)
		else: draw_line(a,b,line_color,1,true)
		var mid: Vector2 = (a+b) / 2
		var r: float = 4 if g.id != selected_gate else 8
		var shape := PackedVector2Array([mid+Vector2(0,-r),mid+Vector2(r,0),mid+Vector2(0,r),mid+Vector2(-r,0),mid+Vector2(0,-r)])
		draw_colored_polygon(shape,Color("091c32"))
		draw_polyline(shape,Color("9ac8f4") if g.id == selected_gate else Color(line_color,0.85),1,true)
	var font_scale: float = clampf(minf(size.x / 900.0,size.y / 747.0),0.55 if read_only else 0.70,1.15)
	for p in shown.planets:
		var pos: Vector2 = to_screen(game.position_of(p))
		var c := Color(Rules.COLORS[p.owner]).lightened(0.28)
		if not p.live: c = c.darkened(0.45)
		var r: float = (27 if p.capital else 24) * clampf(world_scale(),0.43 if read_only else 0.70,1.4)
		var highlight: bool = p.id == selected_planet
		if command == "expand" and p.owner == "无主" and not game.available_source(str(p.id)).is_empty(): highlight = true
		if command in ["reinforce","skill"] and p.owner == game.state.player: highlight = true
		if command == "attack" and p.owner not in [game.state.player,"无主"] and not game.protected_from(str(p.owner)): highlight = true
		if p.id == tutorial_target:
			draw_arc(pos,r+12,0,TAU,64,Color("d0a26a"),2,true)
			var tip := pos+Vector2(0,-r-16)
			draw_line(tip+Vector2(0,-17),tip,Color("d0a26a"),2,true)
			draw_polyline(PackedVector2Array([tip+Vector2(-5,-5),tip,tip+Vector2(5,-5)]),Color("d0a26a"),2,true)
			_text(pos+Vector2(-42,-r-52),"当前目标",13,Color("e0b982"),84)
		if p.capital:
			draw_arc(pos,r+6,0,TAU,64,Color(c,0.4),1,true)
			draw_line(pos+Vector2(-5,-r-11),pos+Vector2(5,-r-11),c,2,true)
		draw_circle(pos,r,Color("0b2137"))
		draw_arc(pos,r,0,TAU,64,Color(c,0.8),1.3,true)
		draw_arc(pos,r*0.73,-2.8,0.5,32,Color(c,0.2),1,true)
		draw_circle(pos,3,c)
		if not p.live:
			draw_line(pos+Vector2(-r*0.4,r*0.4),pos+Vector2(r*0.4,-r*0.4),Color(c,0.5),1,true)
		if highlight:
			for x in [-1,1]:
				for y in [-1,1]:
					var corner := pos+Vector2(x,y)*(r+7)
					draw_polyline(PackedVector2Array([corner-Vector2(x*7,0),corner,corner-Vector2(0,y*7)]),Color("7bbdd3"),1.5,true)
		draw_circle(pos+Vector2(r*0.58,r*0.48),10*font_scale,Color("102e49"))
		_text(pos+Vector2(r*0.58-18,r*0.48-6),str(int(p.known_units)) if int(p.known_units)>=0 else "?",int(14*font_scale),Color("e1e9f3"),36)
		_text(pos + Vector2(-65,r+10),str(p.name),int(18 * font_scale),Color("e1e9f3"),130)
		var report: String = "实时" if p.current_detail else ("待侦察" if p.live and not p.detailed else ("旧航图" if int(p.seen_turn)==0 else "第%d轮情报" % int(p.seen_turn)))
		if not read_only: _text(pos + Vector2(-75,r+34),"%s · %s" % ["首都" if p.capital else p.owner,report],int(14 * font_scale),c,150)
		if game.state.mode == 3 and p.id == game.state.escort_goal: _text(pos + Vector2(-50,-r-28),"护航终点",int(13 * font_scale),Color("9ac8f4"),100)
		if game.state.mode == 8 and int(game.state.series.chapter)==1 and p.id=="p6": _text(pos+Vector2(-50,-r-28),"本章目标",int(13*font_scale),Color("9ac8f4"),100)
	for f in shown.fleets:
		if f.station != "" and f.id != selected_fleet: continue
		var pos: Vector2 = fleet_point(f)
		var c := Color(str(f.color)).lightened(0.3)
		if f.owner != game.state.player and not game.friendly(str(f.owner),str(game.state.player)): c = Color("e1847b")
		if not f.live: c = Color("667a94")
		var r: float = fleet_radius()
		if f.id == selected_fleet: draw_circle(pos,r+7,Color(c,0.2))
		var shape := PackedVector2Array([pos+Vector2(0,-r),pos+Vector2(r,r),pos+Vector2(0,r*0.5),pos+Vector2(-r,r)])
		if f.icon == "菱形": shape = PackedVector2Array([pos+Vector2(0,-r),pos+Vector2(r,0),pos+Vector2(0,r),pos+Vector2(-r,0)])
		if f.live:
			draw_colored_polygon(shape,Color("0b2137"))
			var outline := shape.duplicate()
			outline.append(outline[0])
			draw_polyline(outline,c,2,true)
			draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-r*0.70),pos+Vector2(r*0.33,r*0.32),pos+Vector2(-r*0.33,r*0.32)]),c)
		else:
			shape.append(shape[0])
			draw_polyline(shape,c,1,true)
		draw_line(pos+Vector2(0,-r*0.75),pos+Vector2(0,r*0.35),Color("e1e9f3"),1,true)
		draw_circle(pos+Vector2(0,r+3),3,Color(0.47,0.77,1.0,0.25))
		var units: String = str(int(f.units)) if int(f.units)>=0 else "?"
		if f.id == selected_fleet:
			# A fixed readout avoids covering the planet beneath the enlarged garrison.
			var fleet_name: String = str(f.name)
			if fleet_name.length()>18: fleet_name = fleet_name.left(18)+"…"
			_text(Vector2(22,35),"已选舰队  %s · %s" % [fleet_name,units],int(14*font_scale),c,size.x-44,HORIZONTAL_ALIGNMENT_LEFT)
		else:
			_text(pos+Vector2(-78,r+9),"%s · %s%s" % [f.name,units,"" if f.live else "（旧）"],int(13 * font_scale),c,156)
		if f.get("core",false): _text(pos + Vector2(-50,-r-20),"入侵核心",int(12 * font_scale),Color("b8a0d0"),100)
	if visual_time > 0 and not visual_event.is_empty():
		var t: float = 1.0-visual_time/0.9
		var from: Vector2 = to_screen(Vector2(visual_event.from[0],visual_event.from[1]))
		var to: Vector2 = to_screen(Vector2(visual_event.to[0],visual_event.to[1]))
		match str(visual_event.kind):
			"move":
				var current: Vector2 = from.lerp(to,smoothstep(0,1,t))
				draw_line(from,current,Color("81aad7"),2,true)
				var r: float = fleet_radius()
				draw_colored_polygon(PackedVector2Array([current+Vector2(0,-r),current+Vector2(r*0.8,r*0.7),current+Vector2(-r*0.8,r*0.7)]),Color("d2e3f7"))
			"battle":
				for i in range(4):
					var offset := Vector2(36,0).rotated(i*TAU/4)
					draw_line(to+offset,to+offset*(1-t),Color(0.88,0.54,0.5,1-t),2,true)
				draw_arc(to,8+30*t,0,TAU,40,Color(0.88,0.54,0.5,1-t),2,true)
			"capture","contact":
				draw_arc(to,18+40*t,0,TAU,48,Color(0.55,0.76,0.95,1-t),2,true)
	if down and moved and drag_id != "":
		var f: Dictionary = game.fleet(drag_id)
		if not f.is_empty():
			var target: Dictionary = hit_at(pointer)
			var q: Dictionary = game.movement_quote(f,target,true)
			var c: Color = Color("8ebcc2")
			if target.owner == "外星": c = Color("b8a0d0")
			elif target.owner not in [game.state.player,"无主"]: c = Color("e1847b")
			elif q.get("remote",false): c = Color("e6b66d")
			if q.get("remote",false): draw_dashed_line(fleet_point(f),pointer,c,2,10,true)
			else: draw_line(fleet_point(f),pointer,c,2,true)
			draw_arc(pointer,18,0,TAU,32,c,2,true)
			var message: String = "%d 行动 / %d 燃料 / %s" % [int(q.get("ap",0)),int(q.get("fuel",0)),q.get("risk","")] if q.valid else str(q.reason)
			_text(Vector2(16,size.y-32),message,16,c,size.x-32,HORIZONTAL_ALIGNMENT_LEFT)

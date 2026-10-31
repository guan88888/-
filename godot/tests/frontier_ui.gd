extends SceneTree
const Scene = preload("res://Main.tscn")
var failures: int = 0
func expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int = 8) -> void:
	for i in range(n): await process_frame
func button_with_text(root_node: Node, title: String) -> Button:
	for button in root_node.find_children("*","Button",true,false):
		if button.text == title: return button as Button
	return null
func _run() -> void:
	root.size = Vector2i(1080,900)
	root.content_scale_size = Vector2i.ZERO
	var ui = Scene.instantiate()
	ui.auto_save = false
	ui.save_directory = OS.get_cache_dir().path_join("frontier-ui-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ui.save_directory)
	ui.music_settings_path = ui.save_directory.path_join("audio.cfg")
	root.add_child(ui)
	await frames()
	for title in ["家园","副本","抽奖","战舰","福利"]:
		var entry := button_with_text(ui,title)
		expect(entry != null,"start page has system icon entry: "+title)
	ui.game.new_game("联盟",7,"UI",{"resources":500})
	ui.game.state.ap = 20
	ui.screen_state = "game"
	ui._build()
	ui._frontier_dialog()
	await frames()
	expect(ui.modal_panel.size.x <= root.size.x,"desktop modal fits")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/19-frontier-desktop.png")
	ui._frontier_action("draw","",10)
	await frames()
	expect(int(ui.game.state.frontier.draws)==10,"UI draw dispatch works")
	ui._frontier_dialog()
	root.size = Vector2i(390,844)
	await frames(18)
	expect(ui.modal_panel.size.x <= root.size.x,"mobile modal fits")
	var scrollers: Array = ui.modal.find_children("*","ScrollContainer",true,false)
	for scroller in scrollers:
		expect(scroller.get_h_scroll_bar().max_value <= scroller.size.x+1,"mobile content does not overflow horizontally")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/20-frontier-mobile.png")
	for tab in range(6):
		ui.frontier_tab = tab
		ui._frontier_dialog()
		await frames()
		for button in ui.modal.find_children("*","BaseButton",true,false):
			expect(str(button.get_meta("help_detail","")).length()>=10,"new button explains its action: "+button.text)
		for scroller in ui.modal.find_children("*","ScrollContainer",true,false):
			expect(scroller.get_h_scroll_bar().max_value<=scroller.size.x+1,"all tabs fit mobile width")
		if tab == 3:
			var draw_button: Button
			for button in ui.modal.find_children("*","Button",true,false):
				if button.text == "单抽 · standard": draw_button = button
			expect(is_instance_valid(draw_button),"standard banner single draw is present")
			var outer = draw_button.get_parent().get_parent() as ScrollContainer
			outer.ensure_control_visible(draw_button)
			await frames()
			var old_draws: int = int(ui.game.state.frontier.draws)
			for pressed in [true,false]:
				var event := InputEventMouseButton.new()
				event.position = draw_button.get_global_rect().get_center()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				Input.parse_input_event(event)
				await frames(2)
			expect(int(ui.game.state.frontier.draws)==old_draws+1,"actual mouse click executes draw exactly once")
			ui._frontier_dialog()
			await frames()
		if tab == 5:
			var welfare_button: Button
			for button in ui.modal.find_children("*","Button",true,false):
				if button.text.begins_with("每日签到"): welfare_button = button
			expect(is_instance_valid(welfare_button),"daily welfare is present")
			var old_credits: int = int(ui.game.res().credits)
			welfare_button.emit_signal("pressed")
			await frames()
			expect(int(ui.game.res().credits) == old_credits+50,"welfare grants star coins")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/frontier-tab-%d.png" % tab)
	ui._network_dialog()
	await frames()
	expect(ui.duel_panel_open,"network panel tracks visibility")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/21-network-mobile.png")
	ui._close_modal()
	expect(not ui.duel_panel_open,"close disables automatic reopening")
	ui.queue_free()
	await frames()
	print("Frontier UI: %d failures" % failures)
	quit(1 if failures else 0)

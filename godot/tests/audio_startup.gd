extends SceneTree
## Exercise the real window-close path, allowing the mixer to release the Ogg decoder.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.35).timeout
	if not scene.music.player.playing:
		push_error("Background music did not start")
		quit(1)
		return
	print("PASS: main scene music startup; requesting native window close")
	root.close_requested.emit()

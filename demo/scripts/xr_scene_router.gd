extends Node

## Scene replacement that keeps an already-presenting XR viewport continuous.
##
## Godot's normal change_scene_to_file() removes the old scene before adding the
## new one. Each sample owns an XRPrefab, so that order briefly releases the
## outgoing OpenXR bootstrap and exposes the compositor's previous launcher
## frame. This router adds the incoming scene first, lets its XR bootstrap claim
## the viewport, then releases the outgoing scene.

signal scene_change_failed(scene_path: String, message: String)

const MENU_SCENE := "res://scenes/launcher.tscn"

var _changing := false


func change_scene_to_file(scene_path: String) -> void:
	if _changing:
		return
	_changing = true
	_replace_scene.call_deferred(scene_path)


func _replace_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail(scene_path, "could not load scene")
		return

	var incoming := packed.instantiate()
	if incoming == null:
		_fail(scene_path, "could not instantiate scene")
		return

	var tree := get_tree()
	var outgoing := tree.current_scene

	# add_child() runs _ready() immediately. By the time the outgoing scene is
	# freed, both OpenXR bootstraps are present and the old owner knows not to
	# disable XR rendering.
	tree.root.add_child(incoming)
	tree.current_scene = incoming
	_ensure_menu_control(incoming, scene_path)
	if is_instance_valid(outgoing):
		# free() deletes IMMEDIATELY, and immediate deletion is illegal while the
		# parent is mid add/remove -- which the root is here, because the
		# add_child() above is still unwinding. On device (Quest 3 APK) it did not
		# degrade, it FAILED: 'Parent node is busy adding/removing children'. The
		# outgoing scene then stayed in the tree for the rest of the session, so
		# every scene change stacked another whole rig -- XR bootstrap,
		# interactors and all -- into the interaction groups the live rig scans.
		# Disable it now so it cannot act during its last frame, and let the tree
		# delete it at a point where deletion is legal.
		outgoing.process_mode = Node.PROCESS_MODE_DISABLED
		outgoing.queue_free()

	_changing = false


## Every streamed scene gets a way back, injected here rather than added to each
## scene file: a headset user who enters a showcase with no menu control has to
## take the headset off to get out, which makes testing scene-by-scene painful.
## The launcher itself is skipped -- it IS the menu.
func _ensure_menu_control(scene: Node, scene_path: String) -> void:
	if scene_path == MENU_SCENE:
		return
	if scene is Node3D and _find_menu_control(scene) == null:
		scene.add_child(BackToMenuButton.new())


func _find_menu_control(root: Node) -> Node:
	if root is BackToMenuButton:
		return root
	for child in root.get_children():
		var found := _find_menu_control(child)
		if found != null:
			return found
	return null


func _fail(scene_path: String, message: String) -> void:
	_changing = false
	push_error("XRSceneRouter: %s: %s" % [message, scene_path])
	scene_change_failed.emit(scene_path, message)

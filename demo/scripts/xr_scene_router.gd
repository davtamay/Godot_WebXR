extends Node

## Scene replacement that keeps an already-presenting XR viewport continuous.
##
## Godot's normal change_scene_to_file() removes the old scene before adding the
## new one. Each sample owns an XRPrefab, so that order briefly releases the
## outgoing OpenXR bootstrap and exposes the compositor's previous launcher
## frame. This router adds the incoming scene first, lets its XR bootstrap claim
## the viewport, then releases the outgoing scene.

signal scene_change_failed(scene_path: String, message: String)

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
	if is_instance_valid(outgoing):
		outgoing.free()

	_changing = false


func _fail(scene_path: String, message: String) -> void:
	_changing = false
	push_error("XRSceneRouter: %s: %s" % [message, scene_path])
	scene_change_failed.emit(scene_path, message)

extends SceneTree

## Headless test runner for the XR Interaction Toolkit addon.
## Run: c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd
## Exit code 0 = all checks passed, 1 = at least one failure.

const XRInteractionLayerMask := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_layers.gd")
const XRInputAdapter := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_input_adapter.gd")
const XRHandGestureProvider := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_gesture_provider.gd")
const XRInteractionManager := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_manager.gd")
const XRBaseInteractable := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactable.gd")
const XRBaseInteractor := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactor.gd")
const XRRayInteractor := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_ray_interactor.gd")
const WebXRInputAdapter := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd")
const XRGrabInteractable := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_grab_interactable.gd")
const XRInteractorLineVisual := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interactor_line_visual.gd")
const XRReticleVisual := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_reticle_visual.gd")
const XRUICanvasInteractable := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_ui_canvas_interactable.gd")

var _checks := 0
var _failures := 0

func _initialize() -> void:
    await _run_all()

func _run_all() -> void:
    print("== XR Interaction Toolkit tests ==")
    _test_layer_mask()
    _test_hand_ray_geometry()
    _test_manager_registry_and_arbitration()
    await _test_interactable_late_collider_registration()
    _test_interactor_hover_and_select()
    _test_ray_grab_distance_clamp()
    await _test_ray_hover_and_grab_integration()
    _test_webxr_adapter_inert_on_desktop()
    _test_grab_follow()
    _test_visuals_follow_ray_state()
    _test_ui_canvas_mapping()
    print("%d checks, %d failures" % [_checks, _failures])
    quit(1 if _failures > 0 else 0)

func check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS: " + message)
    else:
        _failures += 1
        printerr("FAIL: " + message)

func _test_layer_mask() -> void:
    check(XRInteractionLayerMask.overlaps(1, 1), "layer 1 overlaps layer 1")
    check(XRInteractionLayerMask.overlaps(0b0110, 0b0100), "masks sharing one bit overlap")
    check(not XRInteractionLayerMask.overlaps(0b0011, 0b0100), "disjoint masks do not overlap")
    check(not XRInteractionLayerMask.overlaps(0, 0), "zero masks never overlap")

func _test_hand_ray_geometry() -> void:
    check(XRHandGestureProvider.get_hand_ray_pose(null).is_empty(), "null tracker yields empty pose")

    var tracker := XRHandTracker.new()
    tracker.has_tracking_data = true
    var valid := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
    _set_joint(tracker, XRHandTracker.HAND_JOINT_WRIST, Vector3.ZERO, valid)
    _set_joint(tracker, XRHandTracker.HAND_JOINT_PALM, Vector3(0, 0, -0.05), valid)
    _set_joint(tracker, XRHandTracker.HAND_JOINT_THUMB_TIP, Vector3(0.01, 0, -0.15), valid)
    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), valid)

    var pose := XRHandGestureProvider.get_hand_ray_pose(tracker)
    check(not pose.is_empty(), "valid joints yield a ray pose")
    if not pose.is_empty():
        check((pose["direction"] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "direction points palm to cursor")
        var expected_origin := Vector3(0, 0, -0.15) + Vector3(0, 0, -1) * XRHandGestureProvider.RAY_ORIGIN_FORWARD_OFFSET
        check((pose["origin"] as Vector3).is_equal_approx(expected_origin), "origin is cursor nudged forward along the ray")

    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), 0)
    check(XRHandGestureProvider.get_hand_ray_pose(tracker).is_empty(), "invalid index tip yields empty pose")
    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), valid)

    tracker.has_tracking_data = false
    check(not XRHandGestureProvider.get_hand_ray_pose(tracker).is_empty(), "valid joints seed a ray before tracker-level data flips")
    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), 0)
    check(XRHandGestureProvider.get_hand_ray_pose(tracker).is_empty(), "invalid joints yield empty pose")
    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), valid)

    var forward := Vector3(1, 0, 0)
    var ray_basis := XRHandGestureProvider.basis_from_forward(forward)
    check((-ray_basis.z).is_equal_approx(forward), "basis_from_forward points -Z along the ray")
    var up_basis := XRHandGestureProvider.basis_from_forward(Vector3.UP)
    check((-up_basis.z).is_equal_approx(Vector3.UP), "basis_from_forward survives the straight-up singularity")

    tracker.has_tracking_data = true
    _set_joint(tracker, XRHandTracker.HAND_JOINT_WRIST, Vector3.ZERO, 0)
    _set_joint(tracker, XRHandTracker.HAND_JOINT_PALM, Vector3(0, 0, -0.05), valid)
    check(not XRHandGestureProvider.get_hand_ray_pose(tracker).is_empty(), "palm can seed hand ray before wrist is valid")

func _set_joint(tracker: XRHandTracker, joint: int, position: Vector3, flags: int) -> void:
    tracker.set_hand_joint_transform(joint, Transform3D(Basis.IDENTITY, position))
    tracker.set_hand_joint_flags(joint, flags)

func _test_manager_registry_and_arbitration() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    var body := StaticBody3D.new()
    interactable.add_child(body)
    root.add_child(interactable)

    check(manager.get_interactable_for_collider(body) == interactable, "collider resolves to its interactable")
    check(manager.get_interactable_for_collider(null) == null, "null collider resolves to null")

    var interactor_a := XRBaseInteractor.new()
    var interactor_b := XRBaseInteractor.new()
    root.add_child(interactor_a)
    root.add_child(interactor_b)

    check(manager.request_select(interactor_a, interactable), "first select is granted")
    check(interactor_a.get_selected() == interactable, "interactor tracks its selection")
    check(interactable.get_selecting_interactor() == interactor_a, "interactable tracks its selector")
    check(not manager.request_select(interactor_b, interactable), "second interactor refused: interactable is exclusive")
    check(not manager.request_select(interactor_a, interactable), "interactor cannot select twice")
    check(manager.request_deselect(interactor_a), "deselect succeeds")
    check(not interactable.is_selected(), "interactable is free after deselect")
    check(interactor_a.get_selected() == null, "interactor is free after deselect")
    check(manager.request_select(interactor_b, interactable), "freed interactable can be selected by another interactor")
    manager.request_deselect(interactor_b)

    interactable.interaction_layers = 2
    interactor_a.interaction_layers = 1
    check(not manager.request_select(interactor_a, interactable), "disjoint interaction layers refuse select")
    interactable.interaction_layers = 1

    root.remove_child(interactable)
    check(manager.get_interactable_for_collider(body) == null, "collider unregistered when interactable exits tree")

    interactor_a.free()
    interactor_b.free()
    interactable.free()
    manager.free()

func _test_interactable_late_collider_registration() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)
    var body := StaticBody3D.new()
    interactable.add_child(body)
    await process_frame

    check(manager.get_interactable_for_collider(body) == interactable, "collider added after parented interactable is registered")

    interactable.free()
    manager.free()

func _test_interactor_hover_and_select() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)
    var interactor := XRBaseInteractor.new()
    root.add_child(interactor)

    var events: Array[String] = []
    interactor.hover_entered.connect(func(i) -> void: events.append("in:" + str(i == interactable)))
    interactor.hover_exited.connect(func(i) -> void: events.append("out:" + str(i == interactable)))
    interactable.select_entered.connect(func(_i) -> void: events.append("sel"))
    interactable.select_exited.connect(func(_i) -> void: events.append("desel"))

    interactor._set_hovered(interactable)
    check(interactable.is_hovered(), "interactable reports hovered")
    interactor._set_hovered(interactable)
    interactor._set_hovered(null)
    check(not interactable.is_hovered(), "interactable reports unhovered")
    check(events == (["in:true", "out:true"] as Array[String]), "hover signals fire once per transition, got %s" % str(events))

    events.clear()
    var adapter := FakeAdapter.new()
    root.add_child(adapter)
    interactor.call("set_input_adapter", adapter)
    interactor.set("hand", XRInputAdapter.Hand.RIGHT)
    interactor._set_hovered(interactable)

    adapter.select_started.emit(XRInputAdapter.Hand.LEFT)
    check(interactor.get_selected() == null, "select for the other hand is ignored")
    adapter.select_started.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_selected() == interactable, "select via adapter selects the hovered interactable")
    adapter.select_ended.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_selected() == null, "select end releases the selection")
    check("sel" in events and "desel" in events, "interactable select signals fired, got %s" % str(events))

    interactor._set_hovered(null)
    adapter.select_started.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_selected() == null, "select with nothing hovered is a no-op")

    adapter.free()
    interactor.free()
    interactable.free()
    manager.free()

class FakeAdapter extends XRInputAdapter:
    var pose := {}

    func get_aim_pose(_hand: int) -> Dictionary:
        return pose

class FakeInteractor extends XRBaseInteractor:
    var attach := Transform3D.IDENTITY

    func get_attach_pose() -> Transform3D:
        return attach

func _test_ray_grab_distance_clamp() -> void:
    var ray := XRRayInteractor.new()
    var interactable := XRBaseInteractable.new()

    ray._hover_distance = 2.0
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, 2.0), "grab distance = hover distance in range")
    ray._notify_select_released(interactable)

    ray._hover_distance = 0.05
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, ray.min_grab_distance), "grab distance clamps up to min_grab_distance")
    ray._notify_select_released(interactable)

    ray._hover_distance = 100.0
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, ray.max_distance), "grab distance clamps down to max_distance")
    ray._notify_select_released(interactable)

    interactable.free()
    ray.free()

func _test_ray_hover_and_grab_integration() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var interactable := XRBaseInteractable.new()
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    body.add_child(shape)
    interactable.add_child(body)
    root.add_child(interactable)
    interactable.position = Vector3(0, 0, -2)

    var adapter := FakeAdapter.new()
    adapter.pose = {"origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    root.add_child(adapter)

    var ray := XRRayInteractor.new()
    root.add_child(ray)
    ray.call("set_input_adapter", adapter)
    ray.set("hand", XRInputAdapter.Hand.LEFT)

    await physics_frame
    await physics_frame

    check(ray.get_hovered() == interactable, "ray hovers the box straight ahead")
    var state: Dictionary = ray.get_ray_state()
    check(state.get("valid", false), "ray state is valid with a tracked pose")
    check(state.get("hit", false), "ray state reports a hit")
    check((state["end"] as Vector3).is_equal_approx(Vector3(0, 0, -1.5)), "hit point is on the near face")

    adapter.select_started.emit(XRInputAdapter.Hand.LEFT)
    check(ray.get_selected() == interactable, "select grabs the hovered box")
    check(is_equal_approx(ray._grab_distance, 1.5), "grab distance captured from hover distance")
    var attach := ray.get_attach_pose()
    check(attach.origin.is_equal_approx(Vector3(0, 0, -1.5)), "attach pose sits at grab distance on the ray")

    adapter.pose = {"origin": Vector3(0, 0.5, 0), "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    await physics_frame
    await physics_frame
    check(ray.get_attach_pose().origin.is_equal_approx(Vector3(0, 0.5, -1.5)), "attach pose follows the moving ray at fixed grab distance")

    adapter.pose = {}
    await physics_frame
    check(ray.get_selected() == interactable, "selection survives pose loss")
    check(ray.get_attach_pose().origin.is_equal_approx(Vector3(0, 0.5, -1.5)), "attach pose frozen during pose loss")
    check(not ray.get_ray_state().get("valid", true), "ray state invalid during pose loss")

    adapter.pose = {"origin": Vector3(0, 0.5, 0), "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    adapter.select_ended.emit(XRInputAdapter.Hand.LEFT)
    check(ray.get_selected() == null, "release clears the selection")

    ray.free()
    adapter.free()
    interactable.free()
    manager.free()

func _test_webxr_adapter_inert_on_desktop() -> void:
    var adapter := WebXRInputAdapter.new()
    root.add_child(adapter)
    check(adapter.get_aim_pose(XRInputAdapter.Hand.LEFT).is_empty(), "no aim pose without a WebXR session")
    check(adapter.get_aim_pose(XRInputAdapter.Hand.RIGHT).is_empty(), "no aim pose for either hand")
    check(adapter.get_source_kind(XRInputAdapter.Hand.LEFT) == XRInputAdapter.SourceKind.NONE, "source kind NONE on desktop")
    check(not adapter.is_hand_active(XRInputAdapter.Hand.LEFT), "hand inactive on desktop")
    adapter.free()

func _test_grab_follow() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var grab := XRGrabInteractable.new()
    root.add_child(grab)
    grab.transform = Transform3D(Basis.IDENTITY, Vector3(1, 1, -2))
    var interactor := FakeInteractor.new()
    root.add_child(interactor)

    check(grab.get_target() == grab, "default target is the interactable itself")

    interactor.attach = Transform3D(Basis.IDENTITY, Vector3(1, 1, -1))
    grab._notify_select_entered(interactor)
    interactor.attach.origin = Vector3(0, 2, -1)
    grab._physics_process(1.0 / 60.0)
    check(grab.global_position.is_equal_approx(Vector3(0, 2, -2)), "INSTANT keeps the grab offset while following")

    interactor.attach = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 2, -1))
    grab._physics_process(1.0 / 60.0)
    check(grab.global_transform.basis.is_equal_approx(Basis.IDENTITY), "rotation preserved with track_rotation off")

    grab._notify_select_exited(interactor)
    interactor.attach.origin = Vector3(9, 9, 9)
    grab._physics_process(1.0 / 60.0)
    check(not grab.global_position.is_equal_approx(Vector3(8, 9, 8)), "released object stops following")

    grab.movement_type = XRGrabInteractable.MovementType.KINEMATIC_SMOOTH
    grab.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    interactor.attach = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    grab._notify_select_entered(interactor)
    interactor.attach.origin = Vector3(0, 0, -1)
    grab._physics_process(1.0 / 60.0)
    var after_one := grab.global_position
    check(after_one.z < -0.01 and after_one.z > -1.0, "KINEMATIC_SMOOTH moves partway toward the target")
    for i in range(300):
        grab._physics_process(1.0 / 60.0)
    check(grab.global_position.is_equal_approx(Vector3(0, 0, -1)), "KINEMATIC_SMOOTH converges on the target")
    grab._notify_select_exited(interactor)

    interactor.free()
    grab.free()
    manager.free()

func _test_visuals_follow_ray_state() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var ray := XRRayInteractor.new()
    var line := XRInteractorLineVisual.new()
    var reticle := XRReticleVisual.new()
    ray.add_child(line)
    ray.add_child(reticle)
    root.add_child(ray)

    line._process(0.016)
    reticle._process(0.016)
    check(not line.visible, "line hidden while the ray is invalid")
    check(not reticle.visible, "reticle hidden while the ray is invalid")

    ray._ray_state = {"valid": true, "origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "end": Vector3(0, 0, -3), "hit": true, "hovered": null}
    line._process(0.016)
    reticle._process(0.016)
    check(line.visible, "line visible with a valid ray")
    check(reticle.visible, "reticle visible on a hit")
    check(reticle.global_position.is_equal_approx(Vector3(0, 0, -3)), "reticle sits at the hit point")

    ray._ray_state = {"valid": true, "origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "end": Vector3(0, 0, -6), "hit": false, "hovered": null}
    line._process(0.016)
    reticle._process(0.016)
    check(line.visible, "line visible on a miss (full length)")
    check(not reticle.visible, "reticle hidden on a miss")

    ray.free()
    manager.free()

func _test_ui_canvas_mapping() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var ui := XRUICanvasInteractable.new()
    ui.panel_size = Vector2(2, 1)
    ui.viewport_pixel_size = Vector2i(200, 100)
    root.add_child(ui)

    check(ui.map_local_point_to_viewport(Vector3.ZERO).is_equal_approx(Vector2(100, 50)), "UI panel center maps to viewport center")
    check(ui.map_local_point_to_viewport(Vector3(-1, 0.5, 0)).is_equal_approx(Vector2(0, 0)), "UI panel top-left maps to viewport origin")
    check(ui.map_local_point_to_viewport(Vector3(1, -0.5, 0)).is_equal_approx(Vector2(200, 100)), "UI panel bottom-right maps to viewport max")

    var centered_ray := ui.map_ray_to_viewport(Vector3(0, 0, 1), Vector3(0, 0, -1))
    check(not centered_ray.is_empty() and (centered_ray["position"] as Vector2).is_equal_approx(Vector2(100, 50)), "UI ray maps to center")
    check(centered_ray.get("inside", false), "UI ray reports inside panel bounds")
    check(ui.map_ray_to_viewport(Vector3(0, 0, 1), Vector3.RIGHT).is_empty(), "UI ray parallel to panel is ignored")

    ui.free()
    manager.free()

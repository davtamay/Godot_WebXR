extends SceneTree

## Headless test runner for the XR Interaction Toolkit addon.
## Run: c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd
## Exit code 0 = all checks passed, 1 = at least one failure.

const XRInteractionLayerMask := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_layers.gd")
const XRInputAdapter := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_input_adapter.gd")
const XRHandGestureProvider := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_gesture_provider.gd")
const XRHandTrackerResolver := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_tracker_resolver.gd")
const XRInteractionManager := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_manager.gd")
const XRBaseInteractable := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactable.gd")
const XRBaseInteractor := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactor.gd")
const XRDirectInteractor := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_direct_interactor.gd")
const XRRayInteractor := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_ray_interactor.gd")
const XRSocketInteractor := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_socket_interactor.gd")
const WebXRInputAdapter := preload("res://addons/godot_webxr_kit/runtime/webxr_input_adapter.gd")
const XRGrabInteractable := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_grab_interactable.gd")
const XRInteractorLineVisual := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interactor_line_visual.gd")
const XRReticleVisual := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_reticle_visual.gd")
const XRUICanvasInteractable := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_ui_canvas_interactable.gd")
const XRScreenRayInteractor := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_screen_ray_interactor.gd")
const WebXRHandVisualizer := preload("res://addons/godot_xr_hands/runtime/hand_visualizer.gd")
const WebXRDepthMeshVisualizer := preload("res://addons/godot_webxr_kit/runtime/webxr_depth_mesh_visualizer.gd")
const PrincipledMaterial := preload("res://addons/godot_blender_principled/runtime/principled_material.gd")
const StrictParityEnvironment := preload("res://addons/godot_blender_principled/runtime/strict_parity_environment.gd")

var _checks := 0
var _failures := 0

func _initialize() -> void:
    await _run_all()

func _run_all() -> void:
    print("== XR Interaction Toolkit tests ==")
    _test_layer_mask()
    _test_principled_material_aliases()
    _test_strict_parity_environment()
    _test_material_collection_import()
    _test_hand_ray_geometry()
    _test_hand_tracker_resolver_validity()
    _test_hand_visualizer_fallback_shape()
    _test_hand_bone_basis_no_shear()
    await _test_depth_mesh_visualizer_builds_fake_snapshot()
    _test_manager_registry_and_arbitration()
    await _test_interactable_late_collider_registration()
    _test_interactor_hover_and_select()
    _test_interactor_activate_use_events()
    _test_ray_grab_distance_clamp()
    _test_ray_motion_distance_manipulation()
    _test_motion_distance_accumulates_slow_motion()
    _test_collider_refresh_preserves_selection()
    _test_reentrant_deselect_during_select_entered()
    _test_interactor_exit_tree_clears_hover()
    _test_stale_manager_recovery()
    await _test_direct_hover_and_grab_integration()
    await _test_ray_hover_and_grab_integration()
    _test_ray_suppressed_by_direct_interactor()
    _test_webxr_adapter_inert_on_desktop()
    _test_webxr_adapter_browser_bridge_pose_math()
    _test_hand_select_stabilization_math()
    _test_grab_follow()
    _test_grab_throw_on_release()
    _test_grab_throw_sample_window()
    _test_grab_throw_angular_velocity()
    _test_two_hand_grab_rotate_and_scale()
    _test_grab_track_position_toggle()
    await _test_socket_interactor_auto_selects_and_snaps()
    await _test_socket_filters_delay_and_takeover()
    _test_visuals_follow_ray_state()
    await _test_screen_ray_hover_and_select()
    _test_ui_canvas_mapping()
    await _test_ui_canvas_drag_slider()
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

func _test_principled_material_aliases() -> void:
    var m := PrincipledMaterial.new()
    m.base_color = Color(0.2, 0.4, 0.6, 0.8)
    check(m.albedo_color.is_equal_approx(Color(0.2, 0.4, 0.6, 0.8)), "base_color aliases albedo_color")

    m.normal_strength = 0.8
    check(is_equal_approx(m.normal_scale, 0.8), "normal_strength aliases normal_scale")
    check(m.normal_enabled, "setting normal_strength enables normal mapping")

    m.emission_color = Color(1, 0.5, 0)
    check(m.emission_enabled, "setting emission_color enables emission")
    check(m.emission.is_equal_approx(Color(1, 0.5, 0)), "emission_color aliases emission")
    m.emission_strength = 3.0
    check(is_equal_approx(m.emission_energy_multiplier, 3.0), "emission_strength aliases emission_energy_multiplier")

    m.alpha_mode = PrincipledMaterial.AlphaMode.MASK
    check(m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "alpha_mode MASK -> alpha scissor")
    m.alpha_mode = PrincipledMaterial.AlphaMode.BLEND
    check(m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "alpha_mode BLEND -> alpha")
    m.alpha_mode = PrincipledMaterial.AlphaMode.OPAQUE
    check(m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "alpha_mode OPAQUE -> opaque")

    m.ior = 1.5
    check(is_equal_approx(m.metallic_specular, 0.5), "ior 1.5 maps to metallic_specular 0.5")

    # Defaults must apply at construction (material is a Resource -> _init, not _ready).
    var fresh := PrincipledMaterial.new()
    check(is_equal_approx(fresh.metallic, 0.0) and is_equal_approx(fresh.roughness, 0.5) and is_equal_approx(fresh.metallic_specular, 0.5), "Blender-matching defaults apply on construction")
    check(fresh.albedo_color.is_equal_approx(fresh.base_color), "base_color default reaches albedo_color on construction (not left white)")

    # roughness/metallic are native StandardMaterial3D props (Blender names already match)
    m.roughness = 0.7
    m.metallic = 0.0
    check(is_equal_approx(m.roughness, 0.7) and is_equal_approx(m.metallic, 0.0), "native roughness/metallic pass through unchanged")

func _collect_collection_materials() -> Array:
    var packed: PackedScene = load("res://addons/godot_blender_principled/samples/assets/MaterialCollection.glb")
    var root_node := packed.instantiate()
    var out := []
    var stack := [root_node]
    while not stack.is_empty():
        var n = stack.pop_back()
        if n is MeshInstance3D and n.mesh:
            for i in n.mesh.get_surface_count():
                var mat: Material = n.mesh.surface_get_material(i)
                if mat and not out.has(mat):
                    out.append(mat)
        for c in n.get_children():
            stack.append(c)
    root_node.free()
    return out

func _test_material_collection_import() -> void:
    var mats := _collect_collection_materials()
    check(mats.size() >= 8, "material collection imported multiple materials, got %d" % mats.size())

    var all_standard := true
    var has_scissor := false
    var has_dielectric := false
    var has_metal := false
    for m in mats:
        if not (m is StandardMaterial3D):
            all_standard = false
        if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
            has_scissor = true
        if is_equal_approx(m.metallic, 0.0):
            has_dielectric = true
        if m.metallic >= 0.99:
            has_metal = true
    check(all_standard, "all imported materials are StandardMaterial3D (glTFast-equivalent path)")
    check(has_scissor, "a cutout material imported as alpha scissor (MASK survived glTF)")
    check(has_dielectric, "a dielectric material imported with metallic 0")
    check(has_metal, "a metal material imported with metallic 1")

func _test_strict_parity_environment() -> void:
    var env: Environment = StrictParityEnvironment.parity_environment()
    check(env.tonemap_mode == Environment.TONE_MAPPER_LINEAR, "parity uses Linear tonemap (= Blender Standard view)")
    check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "parity ambient is a flat color")
    check(env.ambient_light_color.is_equal_approx(Color(0.05, 0.05, 0.05)), "parity ambient is 0.05 gray")
    check(not env.ssao_enabled and not env.sdfgi_enabled and not env.glow_enabled, "parity kills GI/SSAO/glow")

    var nice: Environment = StrictParityEnvironment.nice_environment()
    check(nice.tonemap_mode == Environment.TONE_MAPPER_AGX, "nice look uses AgX tonemap (= Blender default AgX)")

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

func _test_hand_tracker_resolver_validity() -> void:
    var tracked_only := XRHandTracker.new()
    _set_joint(
        tracked_only,
        XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP,
        Vector3(0.08, 1.1, -0.25),
        XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
    )
    check(
        not XRHandTrackerResolver.joint_position_valid(tracked_only, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP),
        "tracked-only hand joint is not treated as position-valid"
    )

    var default_joint := XRHandTracker.new()
    _set_joint(
        default_joint,
        XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP,
        Vector3.ZERO,
        XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
    )
    check(
        not XRHandTrackerResolver.joint_position_valid(default_joint, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP),
        "zero/default hand joint is ignored as stale startup data"
    )

    var valid_joint := XRHandTracker.new()
    _set_joint(
        valid_joint,
        XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP,
        Vector3(0.08, 1.1, -0.25),
        XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID
    )
    check(
        XRHandTrackerResolver.joint_position_valid(valid_joint, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP),
        "nonzero position-valid hand joint is accepted"
    )

    var matching_but_empty := XRHandTracker.new()
    matching_but_empty.hand = XRPositionalTracker.TRACKER_HAND_RIGHT
    matching_but_empty.has_tracking_data = true

    var live_joints := XRHandTracker.new()
    live_joints.hand = XRPositionalTracker.TRACKER_HAND_RIGHT
    live_joints.has_tracking_data = true
    var valid := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
    _set_joint(live_joints, XRHandTracker.HAND_JOINT_PALM, Vector3(0.08, 1.1, -0.2), valid)
    _set_joint(live_joints, XRHandTracker.HAND_JOINT_WRIST, Vector3(0.08, 1.02, -0.15), valid)
    _set_joint(live_joints, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(0.1, 1.18, -0.38), valid)

    var empty_score: int = XRHandTrackerResolver._score_tracker(
        matching_but_empty,
        XRPositionalTracker.TRACKER_HAND_RIGHT,
        "right",
        "/user/hand_tracker/right"
    )
    var live_score: int = XRHandTrackerResolver._score_tracker(
        live_joints,
        XRPositionalTracker.TRACKER_HAND_RIGHT,
        "right",
        "right-live-joints"
    )
    check(live_score > empty_score, "live hand joints outrank same-hand tracker metadata")

func _test_hand_visualizer_fallback_shape() -> void:
    var visualizer := WebXRHandVisualizer.new()
    var left_thumb: Vector3 = visualizer.call("_fallback_joint_offset", XRInputAdapter.Hand.LEFT, XRHandTracker.HAND_JOINT_THUMB_TIP)
    var right_thumb: Vector3 = visualizer.call("_fallback_joint_offset", XRInputAdapter.Hand.RIGHT, XRHandTracker.HAND_JOINT_THUMB_TIP)
    var right_index: Vector3 = visualizer.call("_fallback_joint_offset", XRInputAdapter.Hand.RIGHT, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)

    check(left_thumb.x < 0.0, "left fallback thumb is mirrored to negative X")
    check(right_thumb.x > 0.0, "right fallback thumb is mirrored to positive X")
    check(right_index.z < -0.1, "fallback fingers extend forward from the hand pose")
    var wrapped_status: String = visualizer.call("_format_world_status", "Hand tracking: Left, Right | L 25 browser joints frame=10 | R 25 browser joints frame=10.")
    check(wrapped_status.split("\n").size() == 3, "world hand tracking diagnostics wrap into multiple lines")
    visualizer.free()

func _test_hand_bone_basis_no_shear() -> void:
    # A diagonal (non-axis-aligned) bone is where parent-frame scaling shears.
    var from_position := Vector3(0.1, 1.2, -0.3)
    var to_position := Vector3(0.13, 1.24, -0.28)
    var radius := 0.006
    var delta := to_position - from_position
    var length := delta.length()
    var basis: Basis = WebXRHandVisualizer.bone_basis(from_position, to_position, radius)

    check(is_equal_approx(basis.y.length(), length), "bone long axis (Y) spans the full joint distance")
    check((basis.y.normalized()).is_equal_approx(delta.normalized()), "bone Y axis points from joint to joint")
    check(is_equal_approx(basis.x.length(), radius), "bone X axis carries the radius")
    check(is_equal_approx(basis.z.length(), radius), "bone Z axis carries the radius")
    # No shear: the three columns stay mutually perpendicular after scaling.
    check(absf(basis.x.dot(basis.y)) < 0.0000001, "bone X/Y stay perpendicular (no shear)")
    check(absf(basis.y.dot(basis.z)) < 0.0000001, "bone Y/Z stay perpendicular (no shear)")
    check(absf(basis.x.dot(basis.z)) < 0.0000001, "bone X/Z stay perpendicular (no shear)")

    var degenerate: Basis = WebXRHandVisualizer.bone_basis(from_position, from_position, radius)
    check(is_equal_approx(degenerate.y.length(), 0.0), "coincident joints collapse the bone instead of exploding")

func _test_depth_mesh_visualizer_builds_fake_snapshot() -> void:
    var visualizer := WebXRDepthMeshVisualizer.new()
    root.add_child(visualizer)
    await process_frame

    var samples := []
    for y in range(3):
        for x in range(3):
            samples.append({
                "valid": true,
                "d": 1.0,
                "x": float(x) * 0.1,
                "y": float(y) * 0.1,
                "z": -1.0,
            })

    var message: String = visualizer.call("_build_depth_mesh_from_snapshot", {
        "sampleWidth": 3,
        "sampleHeight": 3,
        "samples": samples,
        "usage": "cpu-optimized",
        "dataFormat": "float32",
    })
    check(message.find("9 pts") >= 0, "depth mesh builds from fake depth samples")
    check(message.find("8 tris") >= 0, "depth mesh triangulates fake depth grid")
    visualizer.free()

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

func _test_interactor_activate_use_events() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)
    var interactor := XRBaseInteractor.new()
    root.add_child(interactor)
    var adapter := FakeAdapter.new()
    root.add_child(adapter)
    interactor.call("set_input_adapter", adapter)
    interactor.set("hand", XRInputAdapter.Hand.RIGHT)
    interactor._set_hovered(interactable)

    var events: Array[String] = []
    interactable.activate_entered.connect(func(_i) -> void: events.append("use"))
    interactable.activate_exited.connect(func(_i) -> void: events.append("end"))
    interactable.activated.connect(func(_i) -> void: events.append("alias_use"))
    interactable.deactivated.connect(func(_i) -> void: events.append("alias_end"))

    adapter.activate_started.emit(XRInputAdapter.Hand.LEFT)
    check(interactor.get_activated() == null, "activate for the other hand is ignored")
    adapter.activate_started.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_activated() == null, "selected-only interactable does not activate from hover")

    adapter.select_started.emit(XRInputAdapter.Hand.RIGHT)
    adapter.activate_started.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_activated() == interactable, "activate via adapter uses the selected interactable")
    check(interactable.is_activated(), "interactable reports activated")
    check(events == (["use", "alias_use"] as Array[String]), "activate signals fire once per transition, got %s" % str(events))

    adapter.select_ended.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_activated() == null, "deselect auto-releases activation")
    check(not interactable.is_activated(), "interactable reports deactivated after deselect")
    check("end" in events and "alias_end" in events, "deactivate signals fired, got %s" % str(events))

    var hover_use := XRBaseInteractable.new()
    hover_use.activation_mode = XRBaseInteractable.ActivationMode.HOVERED_OR_SELECTED
    root.add_child(hover_use)
    interactor._set_hovered(hover_use)
    adapter.activate_started.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_activated() == hover_use, "hover-capable interactable activates without selection")
    adapter.activate_ended.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_activated() == null, "activate end releases hover-capable use target")

    hover_use.free()
    adapter.free()
    interactor.free()
    interactable.free()
    manager.free()

class FakeAdapter extends XRInputAdapter:
    var pose := {}
    var grip_pose := {}

    func get_aim_pose(_hand: int) -> Dictionary:
        return pose

    func get_grip_pose(_hand: int) -> Dictionary:
        return grip_pose if not grip_pose.is_empty() else pose

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
    check(is_equal_approx(ray._grab_distance, 0.05), "close grab keeps the true hover distance (no pop to min_grab_distance)")
    ray._notify_select_released(interactable)

    ray._hover_distance = 100.0
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, ray.max_distance), "grab distance clamps down to max_distance")
    ray._notify_select_released(interactable)

    interactable.free()
    ray.free()

func _test_ray_motion_distance_manipulation() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var adapter := FakeAdapter.new()
    adapter.pose = {"origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    root.add_child(adapter)

    var ray := XRRayInteractor.new()
    ray.distance_motion_scale = 1.0
    ray.max_distance_change_per_second = 4.0
    root.add_child(ray)
    ray.call("set_input_adapter", adapter)
    ray._update_ray(0.016)

    var interactable := XRBaseInteractable.new()
    ray._hover_distance = 3.0
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, 3.0), "motion distance manipulation starts at hover distance")

    adapter.pose = {"origin": Vector3(0, 0, 0.5), "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    ray._update_ray(1.0)
    check(is_equal_approx(ray._grab_distance, 2.5), "pulling the ray hand back brings the held object closer")

    adapter.pose = {"origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    ray._update_ray(1.0)
    check(is_equal_approx(ray._grab_distance, 3.0), "pushing the ray hand forward moves the held object away")

    ray._notify_select_released(interactable)
    interactable.free()
    ray.free()
    adapter.free()
    manager.free()

func _test_motion_distance_accumulates_slow_motion() -> void:
    var ray := XRRayInteractor.new()
    ray.distance_motion_scale = 1.0
    root.add_child(ray)
    var interactable := XRBaseInteractable.new()

    ray._hover_distance = 3.0
    ray._notify_select_granted(interactable)
    ray._last_ray_origin = Vector3.ZERO
    ray._last_ray_direction = Vector3(0, 0, -1)
    ray._has_last_ray_pose = true

    # 2 mm-per-frame pull: each step is below the 6 mm deadzone and must
    # accumulate instead of being discarded.
    var origin := Vector3.ZERO
    for i in range(10):
        origin += Vector3(0, 0, 0.002)
        ray._apply_motion_distance_manipulation(origin, Vector3(0, 0, -1), 1.0 / 60.0)
        ray._last_ray_origin = origin
    check(ray._grab_distance < 3.0 - 0.01, "slow per-frame hand motion accumulates into a pull, got %.4f" % ray._grab_distance)

    ray._notify_select_released(interactable)
    interactable.free()
    ray.free()

func _test_collider_refresh_preserves_selection() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    var body := StaticBody3D.new()
    interactable.add_child(body)
    root.add_child(interactable)
    var interactor := FakeInteractor.new()
    root.add_child(interactor)

    check(manager.request_select(interactor, interactable), "collider refresh test: select granted")
    var extra_body := StaticBody3D.new()
    interactable.add_child(extra_body)
    check(interactor.get_selected() == interactable, "adding a child collider mid-grab keeps the selection")
    check(interactable.is_selected(), "interactable stays selected across a collider refresh")
    check(manager.get_interactable_for_collider(extra_body) == interactable, "collider added mid-grab resolves to the interactable")
    manager.request_deselect(interactor)

    interactor.free()
    interactable.free()
    manager.free()

func _test_reentrant_deselect_during_select_entered() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)
    var interactor := FakeInteractor.new()
    root.add_child(interactor)

    interactable.select_entered.connect(func(i) -> void: manager.request_deselect(i))
    check(not manager.request_select(interactor, interactable), "reentrant deselect makes request_select report failure")
    check(interactor.get_selected() == null, "interactor not left selected after a reentrant deselect")
    check(not interactable.is_selected(), "interactable not left selected after a reentrant deselect")

    interactor.free()
    interactable.free()
    manager.free()

func _test_interactor_exit_tree_clears_hover() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)
    var interactor := FakeInteractor.new()
    root.add_child(interactor)

    var exits: Array = []
    interactable.hover_exited.connect(func(i) -> void: exits.append(i))
    interactor._set_hovered(interactable)
    check(interactable.is_hovered(), "exit-tree test: hovered before removal")
    root.remove_child(interactor)
    check(not interactable.is_hovered(), "interactor leaving the tree clears hover on the interactable")
    check(exits.size() == 1 and exits[0] == interactor, "hover_exited reaches the interactable when the interactor exits")

    interactor.free()
    interactable.free()
    manager.free()

func _test_stale_manager_recovery() -> void:
    # Scenario A: manager freed and rebuilt BEFORE the first select.
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactor := FakeInteractor.new()
    root.add_child(interactor)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)

    root.remove_child(manager)
    manager.free()
    var manager2 := XRInteractionManager.new()
    root.add_child(manager2)

    interactor._set_hovered(interactable)
    interactor._try_select()
    check(interactor.get_selected() == interactable, "select recovers after the manager was freed and rebuilt")
    check(manager2._selections.get(interactor) == interactable, "the rebuilt manager owns the recovered selection")

    # Scenario B: manager dies MID-GRAB; release must not wedge the interactor.
    root.remove_child(manager2)
    manager2.free()
    var manager3 := XRInteractionManager.new()
    root.add_child(manager3)

    interactor._release_select()
    check(interactor.get_selected() == null, "release with a dead manager cleans up locally")
    check(not interactable.is_selected(), "interactable is released despite the dead manager")
    interactor._set_hovered(interactable)
    interactor._try_select()
    check(interactor.get_selected() == interactable, "interactor can select again after stale-manager recovery")
    manager3.request_deselect(interactor)

    interactor.free()
    interactable.free()
    manager3.free()

func _test_direct_hover_and_grab_integration() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var grab := XRGrabInteractable.new()
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    body.add_child(shape)
    grab.add_child(body)
    root.add_child(grab)
    grab.position = Vector3(0, 0, -0.1)

    var adapter := FakeAdapter.new()
    adapter.grip_pose = {"origin": Vector3.ZERO, "basis": Basis.IDENTITY}
    root.add_child(adapter)

    var direct := XRDirectInteractor.new()
    direct.hover_radius = 0.35
    root.add_child(direct)
    direct.call("set_input_adapter", adapter)
    direct.set("hand", XRInputAdapter.Hand.LEFT)

    await physics_frame
    await physics_frame

    check(direct.get_hovered() == grab, "direct interactor hovers a nearby object")
    adapter.select_started.emit(XRInputAdapter.Hand.LEFT)
    check(direct.get_selected() == grab, "direct interactor selects the nearby object")

    adapter.grip_pose = {"origin": Vector3(0, 0.25, 0), "basis": Basis.IDENTITY}
    await physics_frame
    await physics_frame
    check(direct.get_attach_pose().origin.is_equal_approx(Vector3(0, 0.25, 0)), "direct attach pose follows the hand grip")
    check(grab.global_position.is_equal_approx(Vector3(0, 0.25, -0.1)), "direct-grabbed object follows the hand with its grab offset")

    adapter.select_ended.emit(XRInputAdapter.Hand.LEFT)
    check(direct.get_selected() == null, "direct interactor releases selection")

    direct.free()
    adapter.free()
    grab.free()
    manager.free()

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

func _test_ray_suppressed_by_direct_interactor() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var rig := Node3D.new()
    root.add_child(rig)

    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)

    var adapter := FakeAdapter.new()
    adapter.pose = {"origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    root.add_child(adapter)

    var direct := XRDirectInteractor.new()
    direct.name = "Direct"
    rig.add_child(direct)

    var ray := XRRayInteractor.new()
    ray.suppress_interactor_path = NodePath("../Direct")
    rig.add_child(ray)
    ray.call("set_input_adapter", adapter)

    direct._set_hovered(interactable)
    ray.call("_update_ray")
    check(not ray.get_ray_state().get("valid", true) and ray.get_ray_state().get("suppressed", false), "far ray suppressed while linked direct interactor hovers")

    direct._set_hovered(null)
    direct._notify_select_granted(interactable)
    ray.call("_update_ray")
    check(not ray.get_ray_state().get("valid", true) and ray.get_ray_state().get("suppressed", false), "far ray suppressed while linked direct interactor selects")

    direct._notify_select_released(interactable)
    ray.call("_update_ray")
    check(ray.get_ray_state().get("valid", false), "far ray valid when linked direct interactor is inactive")

    ray.free()
    direct.free()
    adapter.free()
    interactable.free()
    rig.free()
    manager.free()

func _test_webxr_adapter_inert_on_desktop() -> void:
    var adapter := WebXRInputAdapter.new()
    root.add_child(adapter)
    check(adapter.get_aim_pose(XRInputAdapter.Hand.LEFT).is_empty(), "no aim pose without a WebXR session")
    check(adapter.get_aim_pose(XRInputAdapter.Hand.RIGHT).is_empty(), "no aim pose for either hand")
    check(adapter.get_source_kind(XRInputAdapter.Hand.LEFT) == XRInputAdapter.SourceKind.NONE, "source kind NONE on desktop")
    check(not adapter.is_hand_active(XRInputAdapter.Hand.LEFT), "hand inactive on desktop")
    check(not adapter.prefer_hand_ray, "runtime aim pose is preferred over joint hand ray by default")
    check(not adapter.stabilize_hand_select, "hand ray select stabilization defaults off")
    adapter.free()

func _test_webxr_adapter_browser_bridge_pose_math() -> void:
    var origin := Node3D.new()
    root.add_child(origin)
    origin.global_position = Vector3(10, 0, 0)

    var adapter := WebXRInputAdapter.new()
    adapter.set("_origin", origin)
    adapter.set("_browser_hand_snapshot", {
        "hands": {
            "right": {
                "targetRay": {"x": 1.0, "y": 2.0, "z": 3.0, "dx": 0.0, "dy": 0.0, "dz": -1.0},
                "joints": {
                    "wrist": {"x": 1.0, "y": 0.0, "z": 0.0},
                    "index-finger-metacarpal": {"x": 1.0, "y": 0.0, "z": -0.02},
                    "middle-finger-metacarpal": {"x": 1.0, "y": 0.0, "z": -0.03},
                    "ring-finger-metacarpal": {"x": 1.0, "y": 0.0, "z": -0.04},
                    "pinky-finger-metacarpal": {"x": 1.0, "y": 0.0, "z": -0.05},
                    "thumb-tip": {"x": 1.0, "y": 0.0, "z": -0.10},
                    "index-finger-tip": {"x": 1.0, "y": 0.0, "z": -0.12},
                },
            },
        },
    })

    var aim_pose := adapter.get_aim_pose(XRInputAdapter.Hand.RIGHT)
    check(not aim_pose.is_empty(), "browser bridge target ray yields an aim pose")
    check((aim_pose["origin"] as Vector3).is_equal_approx(Vector3(11, 2, 3)), "browser bridge aim pose is converted to global space")
    check((aim_pose["direction"] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "browser bridge aim direction is preserved")
    check(adapter.get_source_kind(XRInputAdapter.Hand.RIGHT) == XRInputAdapter.SourceKind.HAND, "browser bridge reports hand source kind")

    var grip_pose := adapter.get_grip_pose(XRInputAdapter.Hand.RIGHT)
    check(not grip_pose.is_empty(), "browser bridge joints yield a grip fallback")
    check((grip_pose["origin"] as Vector3).is_equal_approx(Vector3(11, 0, -0.028)), "browser bridge grip fallback averages palm joints in global space")

    var pinch_distance: float = adapter.call("_browser_pinch_distance", XRInputAdapter.Hand.RIGHT)
    check(is_equal_approx(pinch_distance, 0.02), "browser bridge pinch distance reads thumb/index tips")

    adapter.free()
    origin.free()

func _test_hand_select_stabilization_math() -> void:
    var adapter := WebXRInputAdapter.new()
    var pose := {
        "origin": Vector3(1, 2, 3),
        "direction": Vector3(0, 0, -1),
        "basis": Basis.IDENTITY,
    }
    var translated: Dictionary = adapter.call("_offset_pose_by_anchor_delta", pose, Vector3.ZERO, Vector3(0.25, -0.5, 0.0))
    check((translated["origin"] as Vector3).is_equal_approx(Vector3(1.25, 1.5, 3)), "select-stabilized hand ray translates with palm movement")
    check((translated["direction"] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "select-stabilized hand ray keeps aim direction")
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

func _test_grab_throw_on_release() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var grab := XRGrabInteractable.new()
    grab.target_path = NodePath("Body")
    root.add_child(grab)

    var body := RigidBody3D.new()
    body.name = "Body"
    grab.add_child(body)

    var interactor := FakeInteractor.new()
    interactor.attach = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    root.add_child(interactor)

    grab._notify_select_entered(interactor)
    interactor.attach.origin = Vector3(0, 0, -1.0)
    grab._physics_process(0.1)
    grab._notify_select_exited(interactor)

    check(body.linear_velocity.z < -9.0, "throw-on-release applies sampled attach velocity to rigid body")

    interactor.free()
    grab.free()
    manager.free()

func _test_grab_throw_sample_window() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var grab := XRGrabInteractable.new()
    grab.target_path = NodePath("Body")
    grab.throw_sample_frames = 2
    root.add_child(grab)

    var body := RigidBody3D.new()
    body.name = "Body"
    grab.add_child(body)

    var interactor := FakeInteractor.new()
    interactor.attach = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    root.add_child(interactor)

    grab._notify_select_entered(interactor)
    interactor.attach.origin = Vector3(0, 0, -1.0)
    grab._physics_process(0.1)
    interactor.attach.origin = Vector3(0, 0, -1.2)
    grab._physics_process(0.1)
    grab._notify_select_exited(interactor)

    check(is_equal_approx(body.linear_velocity.z, -6.0), "throw sample window averages recent linear velocity")

    interactor.free()
    grab.free()
    manager.free()

func _test_grab_throw_angular_velocity() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var grab := XRGrabInteractable.new()
    grab.target_path = NodePath("Body")
    grab.track_rotation = true
    root.add_child(grab)

    var body := RigidBody3D.new()
    body.name = "Body"
    grab.add_child(body)

    var interactor := FakeInteractor.new()
    interactor.attach = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    root.add_child(interactor)

    grab._notify_select_entered(interactor)
    interactor.attach = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
    grab._physics_process(0.1)
    grab._notify_select_exited(interactor)

    check(body.angular_velocity.y > 10.0, "throw-on-release applies sampled angular velocity to rigid body")

    interactor.free()
    grab.free()
    manager.free()

func _test_two_hand_grab_rotate_and_scale() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var grab := XRGrabInteractable.new()
    grab.two_hand_grab_enabled = true
    grab.two_hand_rotate = true
    grab.two_hand_scale = true
    root.add_child(grab)
    grab.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)

    var left := FakeInteractor.new()
    left.interaction_layers = 1
    left.attach = Transform3D(Basis.IDENTITY, Vector3(-0.5, 0, 0))
    root.add_child(left)

    var right := FakeInteractor.new()
    right.interaction_layers = 1
    right.attach = Transform3D(Basis.IDENTITY, Vector3(0.5, 0, 0))
    root.add_child(right)

    check(manager.request_select(left, grab), "two-hand grab first hand selects")
    check(manager.request_select(right, grab), "two-hand grab accepts a second hand")
    check(grab.get_selecting_interactors().size() == 2, "two-hand grab tracks both selecting interactors")

    left.attach.origin = Vector3(0, 0, -0.5)
    right.attach.origin = Vector3(0, 0, 0.5)
    grab._physics_process(1.0 / 60.0)
    check((grab.global_transform.basis * Vector3.RIGHT).is_equal_approx(Vector3(0, 0, 1)), "two-hand grab rotates object with hand span")

    manager.request_deselect(right)
    check(grab.get_selecting_interactors().size() == 1, "two-hand grab releases one hand while keeping the other")
    manager.request_deselect(left)

    grab.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    left.attach.origin = Vector3(-0.5, 0, 0)
    right.attach.origin = Vector3(0.5, 0, 0)
    check(manager.request_select(left, grab), "two-hand scale first hand selects")
    check(manager.request_select(right, grab), "two-hand scale second hand selects")
    left.attach.origin = Vector3(-1.0, 0, 0)
    right.attach.origin = Vector3(1.0, 0, 0)
    grab._physics_process(1.0 / 60.0)
    check(grab.global_transform.basis.get_scale().is_equal_approx(Vector3(2, 2, 2)), "two-hand grab scales object by hand distance")

    manager.request_deselect(right)
    manager.request_deselect(left)
    right.free()
    left.free()
    grab.free()
    manager.free()

func _test_grab_track_position_toggle() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var grab := XRGrabInteractable.new()
    grab.track_position = false
    root.add_child(grab)
    grab.global_position = Vector3(3, 0, 0)

    var interactor := FakeInteractor.new()
    interactor.attach = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    root.add_child(interactor)

    manager.request_select(interactor, grab)
    interactor.attach.origin = Vector3(0, 2, -1)
    grab._physics_process(1.0 / 60.0)
    check(grab.global_position.is_equal_approx(Vector3(3, 0, 0)), "grab track_position false keeps world position")
    manager.request_deselect(interactor)

    interactor.free()
    grab.free()
    manager.free()

func _test_socket_interactor_auto_selects_and_snaps() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var socket := XRSocketInteractor.new()
    socket.socket_radius = 0.6
    socket.position = Vector3.ZERO
    root.add_child(socket)

    var grab := XRGrabInteractable.new()
    grab.snap_to_attach = true
    grab.position = Vector3(0.25, 0, 0)

    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    body.add_child(shape)
    grab.add_child(body)
    root.add_child(grab)

    await physics_frame
    await physics_frame

    check(socket.get_hovered() == grab, "socket interactor hovers the closest compatible interactable")
    check(socket.get_selected() == grab, "socket interactor auto-selects a compatible interactable")

    grab._physics_process(1.0 / 60.0)
    check(grab.global_position.is_equal_approx(socket.global_position), "socket-selected snap interactable moves to socket attach pose")

    socket.release_selected()
    socket.free()
    grab.free()
    manager.free()

func _test_socket_filters_delay_and_takeover() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var socket := XRSocketInteractor.new()
    socket.socket_radius = 0.8
    socket.require_snap_to_attach = true
    socket.accepted_groups = [&"socket_snap"]
    socket.hover_select_delay = 0.25
    socket.position = Vector3.ZERO
    root.add_child(socket)

    var ignored := XRGrabInteractable.new()
    ignored.position = Vector3(0.1, 0, 0)
    _add_box_collider(ignored)
    root.add_child(ignored)

    var accepted := XRGrabInteractable.new()
    accepted.snap_to_attach = true
    accepted.add_to_group(&"socket_snap")
    accepted.position = Vector3(0.25, 0, 0)
    _add_box_collider(accepted)
    root.add_child(accepted)

    await physics_frame
    await physics_frame

    socket.call("_update_socket", 0.1)
    check(socket.get_hovered() == accepted, "socket filters out non-snap/non-group interactables")
    check(socket.get_selected() == null, "socket hover delay prevents immediate auto-select")

    socket.call("_update_socket", 0.25)
    check(socket.get_selected() == accepted, "socket selects after hover delay")
    check(socket.get_socket_state().get("state") == &"occupied", "socket state reports occupied after select")

    var hand := FakeInteractor.new()
    root.add_child(hand)
    check(manager.request_select(hand, accepted), "hand interactor can take over a socket-held interactable")
    check(socket.get_selected() == null, "socket yielded selection during hand takeover")
    check(hand.get_selected() == accepted, "hand owns selection after socket takeover")

    manager.request_deselect(hand)
    socket.call("_update_socket", 0.016)
    check(socket.get_selected() == null, "socket respects reselect delay after takeover")

    hand.free()
    accepted.free()
    ignored.free()
    socket.free()
    manager.free()

func _add_box_collider(parent: Node) -> void:
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    body.add_child(shape)
    parent.add_child(body)

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

func _test_screen_ray_hover_and_select() -> void:
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

    var screen_ray := XRScreenRayInteractor.new()
    root.add_child(screen_ray)

    await physics_frame
    await physics_frame

    screen_ray.update_from_ray(Vector3.ZERO, Vector3(0, 0, -1))
    check(screen_ray.get_hovered() == interactable, "screen ray hovers the box straight ahead")

    screen_ray.call("_try_select")
    check(screen_ray.get_selected() == interactable, "screen ray selects the hovered interactable")
    check(interactable.is_selected(), "screen-selected interactable reports selected")

    screen_ray.update_from_ray(Vector3(0, 0.4, 0), Vector3(0, 0, -1))
    check(screen_ray.get_attach_pose().origin.is_equal_approx(Vector3(0, 0.4, -1.5)), "screen ray selected attach follows the pointer ray")

    screen_ray.call("_release_select")
    check(screen_ray.get_selected() == null, "screen ray releases selection")

    interactable.activation_mode = XRBaseInteractable.ActivationMode.HOVERED_OR_SELECTED
    screen_ray.call("_try_activate")
    check(screen_ray.get_activated() == interactable, "screen ray activates a hovered use target")
    screen_ray.call("_release_activate")
    check(screen_ray.get_activated() == null, "screen ray releases activation")

    screen_ray.free()
    interactable.free()
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

func _test_ui_canvas_drag_slider() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    var ui := XRUICanvasInteractable.new()
    ui.viewport_path = NodePath("Viewport")

    var viewport := SubViewport.new()
    viewport.name = "Viewport"
    viewport.size = Vector2i(200, 100)
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

    var slider := HSlider.new()
    slider.name = "Slider"
    slider.position = Vector2(0, 25)
    slider.size = Vector2(200, 50)
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.value = 0.0
    viewport.add_child(slider)
    ui.add_child(viewport)
    root.add_child(ui)
    await process_frame

    ui.call("_push_mouse_motion", Vector2(20, 50))
    ui.call("_push_mouse_button", Vector2(20, 50), true)
    ui.call("_push_mouse_motion", Vector2(180, 50))
    await process_frame
    ui.call("_push_mouse_button", Vector2(180, 50), false)
    await process_frame

    check(slider.value > 80.0, "UI canvas drag updates an HSlider value, got %.2f" % slider.value)

    ui.free()
    manager.free()

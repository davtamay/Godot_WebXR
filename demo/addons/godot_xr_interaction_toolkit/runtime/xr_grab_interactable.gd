class_name XRGrabInteractable
extends "res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactable.gd"

## Interactable that follows its selecting interactor's attach pose.
## Movement modes: INSTANT (set transform), KINEMATIC_SMOOTH (exponential
## lerp), VELOCITY_TRACKED (drive RigidBody3D.linear_velocity; falls back to
## INSTANT for non-rigid targets). Phase 4 adds throw estimation and two-hand.

enum MovementType { INSTANT, KINEMATIC_SMOOTH, VELOCITY_TRACKED }

## Node3D to move. Empty = this node.
@export var target_path: NodePath
## Optional grip-point child. Only used when snap_to_attach is true.
@export var attach_transform_path: NodePath
## true: the attach point snaps onto the interactor's attach pose (XRITK-style
## grip). false (default): the object keeps its pose relative to the ray point.
@export var snap_to_attach := false
@export var movement_type := MovementType.INSTANT
@export var smoothing_speed := 12.0
## false (default): position-only follow, world rotation preserved; stable for
## hand rays. true: follow the attach pose's rotation too.
@export var track_rotation := false
@export var max_tracked_speed := 20.0

var _grab_offset := Transform3D.IDENTITY
var _grabbing: Node

func get_target() -> Node3D:
    if target_path.is_empty():
        return self
    return get_node_or_null(target_path) as Node3D

func _notify_select_entered(interactor) -> void:
    super(interactor)
    _grabbing = interactor
    _grab_offset = _compute_grab_offset(interactor)

func _notify_select_exited(interactor) -> void:
    super(interactor)
    _grabbing = null

func _physics_process(delta: float) -> void:
    if _grabbing == null:
        return

    var target := get_target()
    if target == null:
        return

    var desired: Transform3D = _grabbing.get_attach_pose() * _grab_offset
    if not track_rotation:
        desired.basis = target.global_transform.basis
    _apply_movement(target, desired, delta)

func _compute_grab_offset(interactor) -> Transform3D:
    var target := get_target()
    if target == null:
        return Transform3D.IDENTITY
    if snap_to_attach:
        var attach_node := get_node_or_null(attach_transform_path) as Node3D
        if attach_node:
            return attach_node.global_transform.affine_inverse() * target.global_transform
    return interactor.get_attach_pose().affine_inverse() * target.global_transform

func _apply_movement(target: Node3D, desired: Transform3D, delta: float) -> void:
    match movement_type:
        MovementType.INSTANT:
            target.global_transform = desired
        MovementType.KINEMATIC_SMOOTH:
            var weight := 1.0 - exp(-smoothing_speed * delta)
            var xf := target.global_transform
            xf.origin = xf.origin.lerp(desired.origin, weight)
            if track_rotation:
                xf.basis = xf.basis.orthonormalized().slerp(desired.basis.orthonormalized(), weight)
            target.global_transform = xf
        MovementType.VELOCITY_TRACKED:
            var body := target as RigidBody3D
            if body == null:
                target.global_transform = desired
                return
            var velocity := (desired.origin - body.global_position) / maxf(delta, 0.0001)
            body.linear_velocity = velocity.limit_length(max_tracked_speed)

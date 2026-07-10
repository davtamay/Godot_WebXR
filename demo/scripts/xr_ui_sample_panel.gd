extends Control

@onready var _state_label: Label = %StateLabel
@onready var _value_label: Label = %ValueLabel
@onready var _slider: HSlider = %DemoSlider
@onready var _progress: ProgressBar = %DemoProgress
@onready var _toggle: CheckBox = %DemoToggle
@onready var _depth_button: Button = %DepthButton

var _click_count := 0

func _ready() -> void:
    %PrimaryButton.pressed.connect(_on_primary_pressed)
    _depth_button.pressed.connect(_on_depth_pressed)
    %ResetButton.pressed.connect(_on_reset_pressed)
    _slider.value_changed.connect(_on_slider_changed)
    _toggle.toggled.connect(_on_toggle_changed)
    _sync_value_label()

func _on_primary_pressed() -> void:
    _click_count += 1
    _state_label.text = "Button pressed: %d" % _click_count

func _on_reset_pressed() -> void:
    _click_count = 0
    _slider.value = 50.0
    _toggle.button_pressed = false
    _state_label.text = "UI reset"
    for node in get_tree().get_nodes_in_group("webxr_depth_mesh_visualizer"):
        if node.has_method("clear_depth_mesh"):
            node.clear_depth_mesh()
    _sync_value_label()

func _on_depth_pressed() -> void:
    var bridges := get_tree().get_nodes_in_group("webxr_mesh_bridge")
    if bridges.is_empty():
        _state_label.text = "Room mesh bridge missing."
        return

    var bridge = bridges[0]
    bridge.set_visualize(not bridge.auto_visualize)
    _state_label.text = bridge.get_status()

func _on_slider_changed(value: float) -> void:
    _progress.value = value
    _sync_value_label()

func _on_toggle_changed(enabled: bool) -> void:
    _state_label.text = "Toggle: %s" % ("on" if enabled else "off")

func _sync_value_label() -> void:
    _value_label.text = "Slider: %d" % int(_slider.value)

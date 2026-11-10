extends SceneTree


func _initialize() -> void:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var presets: Dictionary = {}
	for section in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			presets[str(config.get_value(section, "name", ""))] = section
	var errors: Array[String] = []
	for name in ["Web", "WebNoThreads", "WebThreads"]:
		if not presets.has(name):
			errors.append("Missing preset: " + name)
	if errors.is_empty():
		var base: String = presets.Web
		for name in ["WebNoThreads", "WebThreads"]:
			var section: String = presets[name]
			for suffix in ["", ".options"]:
				var keys: Dictionary = {}
				for key in config.get_section_keys(base + suffix):
					keys[key] = true
				for key in config.get_section_keys(section + suffix):
					keys[key] = true
				for key in keys:
					if key in ["name", "export_path", "variant/thread_support", "progressive_web_app/ensure_cross_origin_isolation_headers"]:
						continue
					if config.get_value(base + suffix, key, null) != config.get_value(section + suffix, key, null):
						errors.append("%s differs on %s" % [name, key])
		for name in ["Web", "WebNoThreads", "WebThreads"]:
			var options: String = presets[name] + ".options"
			if config.get_value(options, "variant/thread_support") != (name == "WebThreads"):
				errors.append("Wrong thread selection: " + name)
			if config.get_value(options, "progressive_web_app/ensure_cross_origin_isolation_headers") != (name == "WebThreads"):
				errors.append("Wrong hosting requirements: " + name)
			if not config.get_value(options, "webxr/uses_webxr") or not config.get_value(options, "webgpu/enabled"):
				errors.append("XR/WebGPU disabled: " + name)
	for message in errors:
		printerr(message)
	print("Thread preset parity: ", "PASS" if errors.is_empty() else "FAIL")
	quit(0 if errors.is_empty() else 1)

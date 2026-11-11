extends Node
func _ready() -> void:
 var wave := AudioStreamWAV.new()
 wave.format = AudioStreamWAV.FORMAT_16_BITS
 wave.mix_rate = 48000
 wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
 wave.loop_end = 48000
 var samples := PackedByteArray()
 samples.resize(96000)
 for i in range(48000):
  samples.encode_s16(i * 2, int(sin(TAU * 440.0 * i / 48000.0) * 12000.0))
 wave.data = samples
 var player := AudioStreamPlayer.new()
 player.stream = wave
 player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
 add_child(player)
 player.play()
 JavaScriptBridge.eval("window.audioFixtureReady=true;window.audioFixtureVersion=" + JSON.stringify(Engine.get_version_info()))

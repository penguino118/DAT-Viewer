extends Control

@export var overlay : Node
@export var stream_vo : AudioStreamPlayer
@export var stream_bgm : AudioStreamPlayer

@onready var fps_label = %FrameLabel
@onready var check = %RunningCheck
@onready var bgm_check = %BGMCheck
@onready var vo_check = %VOCheck
@onready var timeline = %Timeline
@onready var file_dialog = $FileDialog
@onready var color_picker = $ColorPicker
@onready var overlay_group = %OverGroupSpin

@onready var screen_container = %ScreenContainer

var update_timeline = true
var ui_currframe = 0
var timeline_pos = 0
var scene_length = 1

func stream_all_stop():
	stream_bgm.stop()
	stream_vo.stop()


func stream_all_play(frame):
	stream_bgm.play(frame / 59.94)
	stream_vo.play(frame / 59.94)
	
	
func _process(_delta):
	
	ui_currframe = overlay.dat_currframe
	scene_length = overlay.scene_length
	
	if ui_currframe >= overlay.scene_length:
		stream_all_stop()
		update_timeline = false
		overlay.dat_running = false
		check.button_pressed = false
	fps_label.text = "Current Frame: %06d" % [ui_currframe]
	
	if update_timeline:
		timeline_pos = ui_currframe / scene_length
		timeline.value = timeline_pos


func _on_h_slider_drag_started():
	update_timeline = false
	stream_all_stop()
	if check.button_pressed:
		overlay.dat_running = false


func _on_h_slider_drag_ended(_value_changed):
	var new_frame = int(timeline.value * scene_length)
	overlay.hide_all_overlays(new_frame)
	overlay.dat_currframe = new_frame
	update_timeline = true
	if check.button_pressed:
		overlay.dat_running = true
		stream_all_play(overlay.dat_currframe)


func _on_check_button_toggled(button_pressed):
	if button_pressed == true:
		if ui_currframe >= overlay.scene_length:
			overlay.dat_currframe = 0
			ui_currframe = 0
		update_timeline = true
		overlay.dat_running = true
		stream_all_play(overlay.dat_currframe)
	elif button_pressed == false:
		overlay.dat_running = false
		stream_all_stop()


func _on_bgm_check_toggled(button_pressed):
	if not button_pressed:
		stream_bgm.volume_db = -80
	else:
		stream_bgm.volume_db = 0


func _on_vo_check_toggled(button_pressed):
	if not button_pressed:
		stream_vo.volume_db = -80
	else:
		stream_vo.volume_db = 0


func _on_open_dat_pressed():
	file_dialog.clear_filters()
	file_dialog.set_filters(PackedStringArray(["*.dat ; Overlays"]))
	file_dialog.popup()


func _on_open_pgm_pressed():
	file_dialog.clear_filters()
	file_dialog.set_filters(PackedStringArray(["*.pgm, *.btr ; Textures"]))
	file_dialog.popup()


func _on_open_bgm_pressed():
	file_dialog.clear_filters()
	file_dialog.set_filters(PackedStringArray(["*.wav ; BGM Track"]))
	file_dialog.popup()


func _on_open_vo_pressed():
	file_dialog.clear_filters()
	file_dialog.set_filters(PackedStringArray(["*.wav ; Voice Track"]))
	file_dialog.popup()


func _on_file_dialog_file_selected(path):
	var filter = file_dialog.filters[0]
	if filter == "*.dat ; Overlays":
		overlay.clear_current()
		overlay.process_dat(path)
		overlay_group.max_value = overlay.group_count
	elif filter == "*.pgm, *.btr ; Textures":
		overlay.P2TX_Manager.textures.clear()
		overlay.P2TX_Manager.PGM = path
		#overlay.P2TX_Manager.process_pgm(path)
	elif filter == "*.wav ; BGM Track":
		stream_bgm.stop()
		stream_bgm.stream = load(path)
		if check.button_pressed:
			stream_bgm.play(overlay.dat_currframe / 59.94)
	elif filter == "*.wav ; Voice Track":
		stream_vo.stop()
		stream_vo.stream = load(path)
		if check.button_pressed:
			stream_vo.play(overlay.dat_currframe / 59.94)


func _on_color_changed(color):
	var bg = screen_container.get_node("BG")
	bg.color = color


func _on_colpick_pressed():
	color_picker.visible = !color_picker.visible


func _on_over_group_spin_value_changed(value):
	var index = value-1
	timeline_pos = 0
	overlay.clear_for_group(index)

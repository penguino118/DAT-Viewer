extends Node

@export var P2TX_Manager : Node
@export var Screen_container : Control
@export_file('*.dat') var DAT
@export_file('*.pgm') var PGM
@onready var tween 

var P2TX_shader = preload("res://P2TX.gdshader")
var P2TX_additive_shader = preload("res://P2TX_AddBlend.gdshader")

var dat_running = false
var dat_currpath = ""
var dat_currframe = 0
var dat_curroverlay = 0
var dat_currgroup = 0

var image_array = []
var image_count = 0
var group_count = 0
var scene_length = 0

var group_dict = {
	"0" = {
		"appear_array" = [],
		"trans_array" = [],
		"length" = 0,
		"effdict" = {}
	}
}

enum EffTypes {
	XPos = 3,
	YPos = 4,
	DualPos = 5,
	XScale = 6,
	YScale = 7,
	MergeScale = 8,
	DualScale = 9,
	Rotation = 10,
	Height = 11,
	Ghost = 32,
	Fade = 55
	}

var textures

func clear_current():
	var appear = group_dict[str(dat_currgroup)]["appear_array"]
	if appear != null:
		for overlay in appear:
			var node = overlay[0]
			node.queue_free()
	dat_currframe = 0
	dat_curroverlay = 0
	image_array.clear()
	group_dict.clear()


func clear_for_group(index:int):
	var appear = group_dict[str(dat_currgroup)]["appear_array"]
	if appear != null:
		for overlay in appear:
			var node = overlay[0]
			if node == null: return
			node.queue_free()
	dat_currframe = 0
	dat_curroverlay = 0
	dat_currgroup = index


func process_dat(path : String):
	var bytes = FileAccess.open(path, FileAccess.READ)#FileAccess.get_file_as_bytes(path)
	textures = P2TX_Manager.process_pgm()
	bytes.seek(0x4)
	image_count = bytes.get_32()
	group_count = bytes.get_32()

	for x in range(image_count):
		var xsize = bytes.get_float()
		var ysize = bytes.get_float()
		image_array.append(Vector2(xsize, ysize))
		
	for group in range(group_count):
		get_overlay_groups(bytes, textures, group)


func get_overlay_groups(bytes : FileAccess, pgm_textures, group_index):
	group_dict[str(group_index)] = {}
	group_dict[str(group_index)]["length"] = bytes.get_float()
	group_dict[str(group_index)]["appear_array"] = []
	group_dict[str(group_index)]["effdict"] = {}
	scene_length = group_dict[str(group_index)]["length"]
	
	var _metadata1 = bytes.get_float() #unknown
	var _metadata2 = bytes.get_float() #unknown
	var _metadata3 = bytes.get_float() #unknown
	var _metadata4 = bytes.get_float() #unknown
	
	var overlay_count = bytes.get_32()
	print("Group ", group_index," overlay count: ", overlay_count)
	for v in range(overlay_count):
		var _type = bytes.get_32()
		var texture = bytes.get_32()
		var origin_offset_x = 1.0-bytes.get_float()
		var origin_offset_y = 1.0-bytes.get_float()
		var screen_pos_x = bytes.get_float()
		var screen_pos_y = bytes.get_float()
		var width = bytes.get_float()
		var height = bytes.get_float()
		bytes.seek(bytes.get_position()+0x04)
		var color_data = bytes.get_32()
		var colors = []
		if color_data >= 1:
			for x in range(4):
				var alpha = bytes.get_float()
				var red = bytes.get_float()
				var green = bytes.get_float()
				var blue = bytes.get_float()
				colors.append(Color(red, green, blue, alpha))
		var start_frame = bytes.get_float()
		var end_frame = bytes.get_float()
		var uv_start_X = bytes.get_float()
		var uv_start_Y = bytes.get_float()
		var uv_end_X = bytes.get_float() - uv_start_X
		var uv_end_Y = bytes.get_float() - uv_start_Y
		var add_blend = bytes.get_32()
		bytes.seek(bytes.get_position()+0x04)
		
		var SPRITE_NODE = Sprite2D.new()
		SPRITE_NODE.name = str(v)
		SPRITE_NODE.texture = pgm_textures[texture]
		SPRITE_NODE.centered = false
		SPRITE_NODE.texture_repeat = 1
		if uv_start_X == 0 and uv_start_Y == 0:
			SPRITE_NODE.offset = Vector2(origin_offset_x, origin_offset_y)
			SPRITE_NODE.region_enabled = true
			SPRITE_NODE.region_rect = Rect2(uv_start_X, uv_start_Y, uv_end_X, uv_end_Y)
		else:
			SPRITE_NODE.offset = Vector2(origin_offset_x+uv_start_X, origin_offset_y+uv_start_Y)
			SPRITE_NODE.region_enabled = true
			SPRITE_NODE.region_rect = Rect2(uv_start_X, uv_start_Y, uv_end_X, uv_end_Y)
		SPRITE_NODE.scale = Vector2(width, height)
		SPRITE_NODE.position = Vector2(screen_pos_x, screen_pos_y)
		SPRITE_NODE.material = ShaderMaterial.new()
		
		if add_blend == 1:
			SPRITE_NODE.material.shader = P2TX_additive_shader
		else:
			SPRITE_NODE.material.shader = P2TX_shader
		
		if colors.size() == 4:
			SPRITE_NODE.material.set_shader_parameter("UppL_COL", colors[0])
			SPRITE_NODE.material.set_shader_parameter("UppR_COL", colors[1])
			SPRITE_NODE.material.set_shader_parameter("BotL_COL", colors[2])
			SPRITE_NODE.material.set_shader_parameter("BotR_COL", colors[3])
			
		Screen_container.add_child(SPRITE_NODE)
		Screen_container.move_child(SPRITE_NODE, 0)
		SPRITE_NODE.visible = false
		group_dict[str(group_index)]["appear_array"].append([SPRITE_NODE, start_frame, end_frame])
		
		var eff_set_size = bytes.get_32()
		if eff_set_size >= 1:
			for x in range(eff_set_size):
				var eff_type = bytes.get_32()
				var _eff_no = bytes.get_32()
				var eff_size = bytes.get_32()
				var eff_val_dict = {}
				for y in range(eff_size):
					var eff_time = bytes.get_float()
					var eff_value_no = bytes.get_32()
					var eff_val = {}
					eff_val["time"] = eff_time
					var values = []
					for z in range(eff_value_no):
						var eff_value = bytes.get_float()
						values.append(eff_value)
					eff_val["values"] = values
					eff_val_dict[y] = eff_val
					group_dict[str(group_index)]["effdict"][group_dict[str(group_index)]["effdict"].size()] = {
						"type" = eff_type,
						"node" = SPRITE_NODE,
						"values" = eff_val_dict,
					}


func _process(_delta):
	if dat_running:
		scene_length = group_dict[str(dat_currgroup)]["length"]
		
		if dat_currframe > scene_length:
			dat_currframe = 0
			
		for overlay in group_dict[str(dat_currgroup)]["appear_array"]:
			if overlay[0] == null:
				return
			if overlay[1] == dat_currframe:
				overlay[0].show()
			elif overlay[2] == dat_currframe:
				overlay[0].hide()
		
		for eff in group_dict[str(dat_currgroup)]["effdict"]:
			var effect = group_dict[str(dat_currgroup)]["effdict"][eff]
			
			var type = effect["type"]
			var node = effect["node"]
			var values = effect["values"]
			for index in range(values.size()-1):
				var eff_dict_1
				var eff_dict_2

				eff_dict_1 = values[(index)]
				eff_dict_2 = values[(index+1)]

				if eff_dict_1 == null or eff_dict_2 == null:
					return
				
				var init_time = eff_dict_1["time"]
				var end_time = eff_dict_2["time"]
				var init_value = eff_dict_1["values"]
				var end_value = eff_dict_2["values"]

				var eff_duration = (end_time - init_time) / 60.0

				if int(init_time) == dat_currframe:
					match type:
						EffTypes.MergeScale:
							init_value = Vector2(init_value[0], init_value[0])
							end_value = Vector2(end_value[0], end_value[0])
							node.scale = init_value
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "scale", end_value, eff_duration)
						EffTypes.XPos:
							init_value = init_value[0]
							end_value = end_value[0]
							node.position.x = init_value
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "position:x", end_value, eff_duration)
						EffTypes.YPos:
							init_value = init_value[0]
							end_value = end_value[0]
							node.position.y = init_value
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "position:y", end_value, eff_duration)
						EffTypes.DualPos:
							init_value = Vector2(init_value[0], init_value[1])
							end_value = Vector2(end_value[0], end_value[1])
							node.position = init_value
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "position", end_value, eff_duration)
						EffTypes.XScale:
							init_value = init_value[0]
							end_value = end_value[0]
							node.scale.x = init_value
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "scale:x", end_value, eff_duration)
						EffTypes.YScale:
							init_value = init_value[0]
							end_value = end_value[0]
							node.scale.y = init_value
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "scale:y", end_value, eff_duration)
						EffTypes.DualScale:
							init_value = Vector2(init_value[0], init_value[1])
							end_value = Vector2(end_value[0], end_value[1])
							node.scale = init_value
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "scale", end_value, eff_duration)
						EffTypes.Rotation: 
							init_value = init_value[0]
							end_value = end_value[0]
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node, "rotation", end_value, eff_duration)
						EffTypes.Height:
							pass
						EffTypes.Ghost:
							pass
						EffTypes.Fade:
							init_value = init_value[0]
							end_value = end_value[0]
							node.material.set_shader_parameter("shader_parameter/UppL_COL:a", init_value)
							node.material.set_shader_parameter("shader_parameter/UppR_COL:a", init_value)
							node.material.set_shader_parameter("shader_parameter/BotL_COL:a", init_value)
							node.material.set_shader_parameter("shader_parameter/BotR_COL:a", init_value)
							tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR)
							tween.tween_property(node.material, "shader_parameter/UppL_COL:a", end_value, eff_duration)
							tween.tween_property(node.material, "shader_parameter/UppR_COL:a", end_value, eff_duration)
							tween.tween_property(node.material, "shader_parameter/BotL_COL:a", end_value, eff_duration)
							tween.tween_property(node.material, "shader_parameter/BotR_COL:a", end_value, eff_duration)

		dat_currframe += 1


func hide_all_overlays(new_frame):
	for overlay in group_dict[str(dat_currgroup)]["appear_array"]:
		var end = overlay[2]
		var start = overlay[1]
		var node = overlay[0]
		if node == null: return
		if new_frame >= start and new_frame < end:
			node.show()
		elif new_frame > end or new_frame < start:
			node.hide()

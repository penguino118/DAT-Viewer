extends Node

@export_file('*.pgm') var PGM
var textures = []


func process_pgm(): #path : String
	var bytes = FileAccess.open(PGM, FileAccess.READ)#FileAccess.get_file_as_bytes(path)
	var magic = bytes.get_32()
	
	if magic != 1481912912:
		print("couldn't reach P2TX in ", PGM)
		return
	
	var image_count = bytes.get_32()
	bytes.seek(bytes.get_position() + 0x8)
	
	for x in range(image_count):
		var image_offset = bytes.get_32()
		var palette_offset = bytes.get_32()
		var image_resolution = bytes.get_16()
		var image_texture = get_sprite(bytes, image_offset, palette_offset, image_resolution)
		textures.append(image_texture)
		bytes.seek(bytes.get_position() + 0x6)
	
	return textures


func get_sprite(bytes : FileAccess, image_offset, palette_offset, image_resolution):
	#P2TX BPP is always 4bpp unless clut is 256 colors
	#P2TX CLUT is always 32 bpc
	var original_position = bytes.get_position()
	var bpp8 = false
	
	var width = image_resolution
	var height = image_resolution
	
	var texture = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var colors = []
	bytes.seek(palette_offset)
	var color_count = bytes.get_8()*4
	bytes.seek(palette_offset + 0x10)

	for x in range(color_count):
		var R = bytes.get_8()
		var G = bytes.get_8()
		var B = bytes.get_8()
		var A = bytes.get_8()
		var col = Color(clamp(R/256.0, 0, 1), clamp(G/256.0, 0, 1), clamp(B/256.0, 0, 1), clamp(A/128.0, 0, 1))
		colors.append(col)
	
	if color_count == 256:
		colors = swizzle(colors, color_count)
		bpp8 = true

	bytes.seek(image_offset + 0x10)
	var start = bytes.get_position()
	for pixel in range(width*height):
		var byte_index
		if bpp8:
			byte_index = pixel 
		else:
			byte_index = pixel / 2
		bytes.seek(start+byte_index)
		var byte_value = bytes.get_8()
		bytes.seek(bytes.get_position())
		
		var shift_amount = (pixel % 2) * 4
		var nibble = (byte_value >> shift_amount) & 0x0F
		
		var coord_x = pixel%(width)
		var coord_y = floor(pixel/height)
		
		if bpp8:
			texture.set_pixel(coord_x, coord_y, colors[byte_value])
		else:
			texture.set_pixel(coord_x, coord_y, colors[nibble])
	
	bytes.seek(original_position)
	return ImageTexture.create_from_image(texture)


func swizzle(colors, color_count):
	var new_colors = []
	var block_array = []

	for x in range(color_count/8):
		var block = colors.slice(x*8, (x*8)+8)
		block_array.append(block)
		
	for x in range(block_array.size()):
		var index = x
		if (x+1) % 4 == 2:
			index = x+1
		if (x+1) % 4 == 3:
			index = x-1
			
		for color in block_array[index]: new_colors.append(color)
		
	return new_colors

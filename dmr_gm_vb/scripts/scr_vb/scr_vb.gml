/// @desc

#macro MAT4_ZUP_TO_YUP [ 1,0,0,0 ,0,0,-1,0, 0,-1,0,0, 0,0,0,1 ]

function BufferTransformVertices(b, offset, count, stride, matrix)
{
	var n = (buffer_get_size(b) div stride) * stride;
	var vert = [0,0,0];
	var j;
	for (var i = offset; i < n; i += stride)
	{
		j = i;
		repeat(count)
		{
			vert[0] = buffer_peek(b, j, buffer_f32);
			vert[1] = buffer_peek(b, j+4, buffer_f32);
			vert[2] = buffer_peek(b, j+8, buffer_f32);
			vert = matrix_transform_vertex(matrix, vert[0], vert[1], vert[2]);
			buffer_poke(b, j, buffer_f32, vert[0]);
			buffer_poke(b, j+4, buffer_f32, vert[1]);
			buffer_poke(b, j+8, buffer_f32, vert[2]);
			
			j += 12; // move to next vec3
		}
	}
}

function OpenVB(vbf, path, freeze = 1, matrix = matrix_build(0,0,0, 0,0,0, 1,-1,1))
{
	var bzipped = buffer_load(path);
	
	// error reading file
	if bzipped < 0
	{
		show_debug_message("OpenVB(): Error opening file \""+ path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
	var vb = vertex_create_buffer_from_buffer(b, vbf);
	
	if freeze {vertex_freeze(vb);}
	
	return vb;
}


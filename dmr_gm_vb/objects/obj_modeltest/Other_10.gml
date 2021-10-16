/// @desc

function CreateGridVB(cellcount, cellsize)
{
	// Set up colors: [Grid lines, X axis, Y axis]
	var colbase = [c_dkgray, c_maroon, c_green];
	var col = [ [0,0,0], [0,0,0], [0,0,0] ];
	for (var i = 0; i < 3; i++)
	{
		col[i][0] = color_get_red(colbase[i])/255; 
		col[i][1] = color_get_green(colbase[i])/255; 
		col[i][2] = color_get_blue(colbase[i])/255;
	}
	
	// Make Grid
	var width = cellsize * cellcount;
	
	var out = vertex_create_buffer();
	vertex_begin(out, vbf_default);
	for (var i = -cellcount; i <= cellcount; i++)
	{
		vertex_position_3d(out, i * cellsize, width, 0); 
		vertex_color(out, colbase[0], 1);
		vertex_texcoord(out, 0, 0);
		
		vertex_position_3d(out, i * cellsize, -width, 0); 
		vertex_color(out, colbase[0], 1);
		vertex_texcoord(out, 0, 0);
	
		vertex_position_3d(out, width, i * cellsize, 0); 
		vertex_color(out, colbase[0], 1);
		vertex_texcoord(out, 0, 0);
		
		vertex_position_3d(out, -width, i * cellsize, 0); 
		vertex_color(out, colbase[0], 1);
		vertex_texcoord(out, 0, 0);
	}
	
	vertex_position_3d(out, width, 0, 0); 
	vertex_color(out, colbase[1], 1);
	vertex_texcoord(out, 0, 0);
	
	vertex_position_3d(out, -width, 0, 0); 
	vertex_color(out, colbase[1], 1);
	vertex_texcoord(out, 0, 0);

	vertex_position_3d(out, 0, width, 0); 
	vertex_color(out, colbase[2], 1);
	vertex_texcoord(out, 0, 0);
	
	vertex_position_3d(out, 0, -width, 0); 
	vertex_color(out, colbase[2], 1);
	vertex_texcoord(out, 0, 0);
	
	vertex_end(out);
	vertex_freeze(out);
	
	return out;
}


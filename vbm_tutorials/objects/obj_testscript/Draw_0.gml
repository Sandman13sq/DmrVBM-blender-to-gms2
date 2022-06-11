/// @desc 

/// @desc Set matrices and draw VBs

// Store room matrices in matrix stack
var roommatrices = [
	matrix_get(matrix_projection),
	matrix_get(matrix_view),
	matrix_get(matrix_world)
];

var textscale = 0.1;

draw_set_halign(1);
draw_set_valign(0);

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangles facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);

var sep = 13, i = 0;

// VBs
if (mode == 0)
{
	// Draw vertex buffers (Simple)
	shader_set(shd_style);
	shader_set_uniform_f_array(u_style_lightpos, [8, 32, 48]);
	
	matrix_set(matrix_world, Mat4());
	vertex_submit(vb_instanced, pr_trianglelist, -1);

	matrix_set(matrix_world, Mat4Translate(x+0, y-sep, 0));
	vertex_submit(vb_curly_scaled, pr_trianglelist, -1);
	DrawModelDesc("Scaled");
	
	//shader_set(shd_normal);
	//shader_set_uniform_f_array(u_normal_lightpos, [8, 32, 48]);
	
	shader_set(shd_simple);
	
	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vertex_submit(vb_curly_nocompression, pr_trianglelist, -1);
	DrawModelDesc("No Compression");

	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vertex_submit(vb_curly_fullcompression, pr_trianglelist, -1);
	DrawModelDesc("Full Compression");

	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vertex_submit(vb_curly_floatcolors, pr_trianglelist, -1);
	DrawModelDesc("Float Colors");

	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vertex_submit(vb_curly_edgesonly, pr_linelist, -1);
	DrawModelDesc("Edges Only");
}
// VBMs
else if (mode == 1)
{
	shader_set(shd_normal);
	shader_set_uniform_f_array(u_normal_lightpos, [80, 320, 480]);
	
	matrix_set(matrix_world, Mat4Translate(x, y, 0));
	vbm_instanced.Submit();
	
	shader_set(shd_style);
	shader_set_uniform_f_array(u_style_lightpos, [80, 320, 480]);
	
	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vbm_curly_uncompressed.Submit();
	DrawModelDesc("Uncompressed");

	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vbm_curly_compressed.Submit();
	DrawModelDesc("Compressed");
	
	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vbm_curly_vb.Submit();
	DrawModelDesc("VB (Not VBM)");
	
}
else
{
	shader_set(shd_normal);
	shader_set_uniform_f_array(u_normal_lightpos, [80, 320, 480]);
	
	matrix_set(matrix_world, Mat4Translate(x, y, 0));
	vbm_instanced.Submit();
	
	shader_set(shd_principled);
	shader_set_uniform_f_array(u_principled_light, [80, 320, 480]);
	
	shader_set_uniform_f_array(u_principled_matpose, matpose);
	
	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vbm_curly_exportlist.Submit();
	DrawModelDesc("Export List");
	
	shader_set_uniform_f_array(u_principled_matpose, matpose2);
	
	matrix_set(matrix_world, Mat4Translate(x+(sep*i++), y+0, 0));
	vbm_curly_surplusbones.Submit();
	DrawModelDesc("Surplus Bones");
}

shader_reset();

// Restore previous matrices from matrix stack
matrix_set(matrix_projection, roommatrices[0]);
matrix_set(matrix_view, roommatrices[1]);
matrix_set(matrix_world, roommatrices[2]);

// Restore previous GPU state
gpu_pop_state();


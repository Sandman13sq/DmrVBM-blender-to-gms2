/// @desc

draw_clear(0);

gpu_push_state();

// Store current render matrices
var oldmats = [
	matrix_get(matrix_projection),
	matrix_get(matrix_view),
	matrix_get(matrix_world),
];

// Set render matrices for models
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, matrix_build_identity());

// Default Shader ---------------------------------------------------
shader_set(shd_default);

vertex_submit(vb_grid, pr_linelist, -1);

// Model
gpu_set_cullmode(cull_clockwise);
gpu_set_ztestenable(1);
gpu_set_zwriteenable(1);

if vbmode == 0 // Static Model (No Bones)
{
	shader_set(shd_model);
	matrix_set(matrix_world, mattran);
	shader_set_uniform_f_array(uniformset[vbmode].u_drawmatrix, drawmatrix);
	shader_set_uniform_f_array(uniformset[vbmode].u_camera, camera);
	vertex_submit(vb, pr_trianglelist, -1);
}
else // Rigged Model (With Bones)
{
	shader_set(shd_modelrigged);
	matrix_set(matrix_world, mattran);
	shader_set_uniform_f_array(uniformset[vbmode].u_camera, camera);
	shader_set_uniform_f_array(uniformset[vbmode].u_matpose, matpose);
	
	// Solid
	if (!wireframe)
	{
		var _drawmatrix = [
			BuildDrawMatrix(1, 0, 0, 0),
			BuildDrawMatrix(1, 0, 0, 1),
			];
		
		for (var i = 0; i < vbx.vbcount; i++)
		{
			shader_set_uniform_f_array(uniformset[vbmode].u_drawmatrix, 
				_drawmatrix[string_pos("skin", vbx.vbnames[i]) != 0]);
			
			vertex_submit(vbx.vb[i], pr_trianglelist, -1);	
		}
	}
	// Wireframe
	else
	{
		for (var i = 0; i < vbx_wireframe.vbcount; i++)
		{
			vertex_submit(vbx_wireframe.vb[i], pr_linelist, -1);	
		}	
	}
}

shader_reset();

// Restore matrices
matrix_set(matrix_world, oldmats[2]);
matrix_set(matrix_view, oldmats[1]);
matrix_set(matrix_projection, oldmats[0]);

gpu_pop_state();

draw_text(300, 200, camera);
draw_text(300, 216, [x, y, z]);
draw_text(300, 232, stringf("Trackpos: %s", trackpos));
draw_text(300, 248, stringf("Parsemode: %s", keymode? "name": "index"));
draw_text(300, 16, execinfo);

/// @desc

draw_clear(bkcolor);

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

//vertex_submit(vb_grid, pr_linelist, -1);


// Model
gpu_set_cullmode(cull_clockwise);
gpu_set_ztestenable(1);
gpu_set_zwriteenable(1);

shader_set(shd_model);
matrix_set(matrix_world, matrix_build_identity());
shader_set_uniform_f_array(uniformset[0].u_drawmatrix, BuildDrawMatrix(1));
shader_set_uniform_f_array(uniformset[0].u_camera, camera);
vertex_submit(vb_world, pr_trianglelist, -1);

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
		shader_set_uniform_f_array(uniformset[vbmode].u_drawmatrix, drawmatrix);
		
		for (var i = 0; i < vbx.vbcount; i++)
		{
			if vbxvisible & (1<<i)
			{
				vertex_submit(vbx.vb[i], pr_trianglelist, -1);	
			}
		}
		
		// Shadow
		shader_set_uniform_f_array(uniformset[vbmode].u_drawmatrix, 
			BuildDrawMatrix(1, 1, 0, 0, c_dkgray, 1));
		matrix_set(matrix_world, matrix_multiply(mattran, matrix_build(0,0,0, 0,0,0, 1, 1, 0.001)));
		for (var i = 0; i < vbx.vbcount; i++)
		{
			if vbxvisible & (1<<i)
			{
				vertex_submit(vbx.vb[i], pr_trianglelist, -1);	
			}
		}
	}
	// Wireframe
	else
	{
		for (var i = 0; i < vbx_wireframe.vbcount; i++)
		{
			if vbxvisible & (1<<i)
			{
				shader_set_uniform_f_array(uniformset[vbmode].u_drawmatrix, 
					BuildDrawMatrix(1, 1, 1, 0, wireframecolors[i], 1));
				vertex_submit(vbx_wireframe.vb[i], pr_linelist, -1);
			}
		}	
	}
}

shader_reset();

// Restore matrices
matrix_set(matrix_world, oldmats[2]);
matrix_set(matrix_view, oldmats[1]);
matrix_set(matrix_projection, oldmats[0]);

gpu_pop_state();

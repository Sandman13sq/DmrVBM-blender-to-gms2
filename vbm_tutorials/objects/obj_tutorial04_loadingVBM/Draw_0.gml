/// @desc Set matrices and draw VBs

// Store room matrices
var roommatrices = [
	matrix_get(matrix_projection),
	matrix_get(matrix_view),
	matrix_get(matrix_world)
];

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangles facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);

// Draw vertex buffers (Simple)
shader_set(shd_simple);

matrix_set(matrix_world, matrix_build(0,0,0, 0,0,0, 0.1, 0.1, 0.1));
if (vb_grid >= 0) {vertex_submit(vb_grid, pr_linelist, -1);}
if (vb_axis >= 0) {vertex_submit(vb_axis, pr_trianglelist, -1);}

matrix_set(matrix_world, mattran); // Transform matrix

shader_set(shd_style);

shader_set_uniform_f_array(u_style_lightpos, lightpos);

if (vbm_starcie)
{
	for (var i = 0; i < vbm_starcie.Count(); i++) // Iterate through vb indices
	{
		if ( meshvisible & (1 << i) ) // Check if bit is set for mesh index
		{
			vbm_starcie.SubmitVBIndex(i, pr_trianglelist, -1); // Send indexed vb to GPU
		}
	}
}

shader_reset();

// Restore previous matrices
matrix_set(matrix_projection, roommatrices[0]);
matrix_set(matrix_view, roommatrices[1]);
matrix_set(matrix_world, roommatrices[2]);

// Restore previous GPU state
gpu_pop_state();

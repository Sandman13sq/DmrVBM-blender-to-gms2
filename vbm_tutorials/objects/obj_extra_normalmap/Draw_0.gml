/// @desc Set matrices and draw VBs

// Store room matrices
var roommatrices = [
	matrix_get(matrix_projection),
	matrix_get(matrix_view),
	matrix_get(matrix_world)
];

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangless facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

gpu_set_tex_repeat(true);	// Repeat texture past 0-1 range
gpu_set_tex_filter(true);	// Smooth pixels

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, mattran); // Transform matrix

shader_set(shd_normalmap);
shader_set_uniform_f_array(u_normalmap_lightpos, lightpos);

vbm_world.Submit(pr_trianglelist, tex_normalmap);
vbm_curly_normalmap.Submit(pr_trianglelist, tex_normalmap);

shader_reset();

// Restore previous matrices
matrix_set(matrix_projection, roommatrices[0]);
matrix_set(matrix_view, roommatrices[1]);
matrix_set(matrix_world, roommatrices[2]);

// Restore previous GPU state
gpu_pop_state();

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

matrix_set(matrix_world, matrix_build_identity()); // Transform matrix

shader_set(shd_style);
shader_set_uniform_f_array(u_style_lightpos, lightpos);
vbm_world.Submit();

matrix_set(matrix_world, mattran); // Transform matrix

shader_set(shd_outline);
shader_set_uniform_f_array(u_outline_lightpos, lightpos);

// Outline Pass
gpu_set_cullmode(cull_counterclockwise);
shader_set_uniform_f(u_outline_outline, outlinestrength);
vbm_starcie_outline.Submit();

// Non-Outline Pass
gpu_set_cullmode(cull_clockwise);
shader_set_uniform_f(u_outline_outline, 0);
vbm_starcie_outline.Submit();

shader_reset();

// Restore previous matrices
matrix_set(matrix_projection, roommatrices[0]);
matrix_set(matrix_view, roommatrices[1]);
matrix_set(matrix_world, roommatrices[2]);

// Restore previous GPU state
gpu_pop_state();

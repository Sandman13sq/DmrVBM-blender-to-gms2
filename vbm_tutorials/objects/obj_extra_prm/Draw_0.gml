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

gpu_set_tex_repeat(true);	// Repeat texture past 0-1 range
gpu_set_tex_filter(true);	// Smooth pixels

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, matrix_build_identity()); // Transform matrix

shader_set(shd_style);
shader_set_uniform_f_array(u_style_lightpos, lightpos);
vbm_world.Submit();

matrix_set(matrix_world, mattran); // Transform matrix

shader_set(shd_prm);
shader_set_uniform_f_array(u_prm_lightpos, lightpos);
shader_set_uniform_f(u_prm_transitionblend, transitionblend);
shader_set_uniform_matrix_array(u_prm_matpose, trkanimator.OutputPose());

texture_set_stage(u_prm_col, tex_col);
texture_set_stage(u_prm_nor, tex_nor);
texture_set_stage(u_prm_prm, tex_prm);

// Non-Skin
shader_set_uniform_f_array(u_prm_skinparams, [0, 0, 0, 0]);
vbm_starcie_prm.SubmitVBIndex(0, pr_trianglelist, -1);

// Skin
shader_set_uniform_f_array(u_prm_skincolor, skincolor);
shader_set_uniform_f_array(u_prm_skinparams, skinparams);
vbm_starcie_prm.SubmitVBIndex(1, pr_trianglelist, -1);

shader_reset();

// Restore previous matrices
matrix_set(matrix_projection, roommatrices[0]);
matrix_set(matrix_view, roommatrices[1]);
matrix_set(matrix_world, roommatrices[2]);

// Restore previous GPU state
gpu_pop_state();

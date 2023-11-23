/// @desc Set matrices and draw VBs

// Store room matrices in matrix stack
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
vertex_submit(vb_grid, pr_linelist, -1); // <- pr_linelist here
vertex_submit(vb_axis, pr_trianglelist, -1);

matrix_set(matrix_world, Mat4()); // Transform matrix

shader_set(shd_rigged);
shader_set_uniform_f_array(u_rigged_light, lightpos);
shader_set_uniform_matrix_array(u_rigged_matpose, trkanimator.OutputPose());	// Send final pose to shader

vbm_starcie.Submit(pr_trianglelist, tex_col);	// Texture index is given

shader_reset();

// Restore previous matrices from matrix stack
matrix_set(matrix_projection, roommatrices[0]);
matrix_set(matrix_view, roommatrices[1]);
matrix_set(matrix_world, roommatrices[2]);

// Restore previous GPU state
gpu_pop_state();

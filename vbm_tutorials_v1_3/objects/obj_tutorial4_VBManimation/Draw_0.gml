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
shader_set(shd_native);

matrix_set(matrix_world, matrix_build(0,0,0, 0,0,0, 0.1,0.1,0.1));
if (vb_axis >= 0) {vertex_submit(vb_axis, pr_trianglelist, -1);}
matrix_set(matrix_world, matrix_build(0,0,0, 0,0,0, 1,1,1));
if (vb_grid >= 0) {vertex_submit(vb_grid, pr_linelist, -1);}	// <- pr_linelist here

matrix_set(matrix_world, mattran); // Transform matrix

shader_set(shd_rigged);
shader_set_uniform_f_array(u_rigged_light, lightpos);
shader_set_uniform_matrix_array(u_rigged_matpose, animator.OutputPose());	// Send final pose to shader

vbm_treat.Submit(pr_trianglelist, tex_col);	// Texture index is given

shader_reset();

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

// Restore previous GPU state
gpu_pop_state();

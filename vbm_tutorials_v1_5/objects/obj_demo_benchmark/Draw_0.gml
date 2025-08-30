/// @desc Draw model

gpu_push_state();

matrix_set(matrix_projection, mproj);
matrix_set(matrix_view, mview);
matrix_set(matrix_world, mtran);

shader_set(shd_tutorial4_animation);

shader_set_uniform_matrix_array(
	shader_get_uniform(shader_current(), "u_bonematrices"),
	bone_skinning
);
VBM_Model_Submit(model, mtran);

shader_reset();

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

// Restore previous GPU state
gpu_pop_state();


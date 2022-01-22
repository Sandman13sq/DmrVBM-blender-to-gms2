/// @desc Restore draw matrices

shader_reset();

matrix_set(matrix_projection, camera_get_proj_mat(view_camera));
matrix_set(matrix_view, camera_get_view_mat(view_camera));
matrix_set(matrix_world, matrix_build_identity());

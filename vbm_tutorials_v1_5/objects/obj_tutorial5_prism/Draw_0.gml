/// @desc Set matrices and draw VBs

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangles facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);

// Render Models
shader_set(shd_tutorial5_world);
shader_set_uniform_matrix_array(u_world_axes, mataxes);
matrix_set(matrix_world, matrix_build_identity()); // Transform matrix
VBM_Model_Submit(model_level, matrix_build_identity());

shader_set(shd_tutorial5_entity);
shader_set_uniform_matrix_array(u_entity_axes, mataxes);
for (var entity_index = 0; entity_index < entity_count; entity_index++) {
	var e = entity_list[entity_index];
	if ( e.model ) {
		if ( array_length(e.pose_skinning) > 0 ) {
			shader_set_uniform_matrix_array(u_entity_bonematrices, e.pose_skinning);	// Send skinning pose to shader
		}
		VBM_Model_Submit(e.model, e.matrix);
	}
}

// Restore previous state
shader_reset();
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());
gpu_pop_state();




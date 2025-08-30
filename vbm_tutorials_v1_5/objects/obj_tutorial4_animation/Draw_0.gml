/// @desc Set matrices and draw VBs

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangles facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);

// Shader Uniforms
shader_set(shd_tutorial4_animation);

matrix_set(matrix_world, mattran); // Transform matrix

// Animation matrices are sent as single array representing matrix values
shader_set_uniform_matrix_array(u_animation_bonematrices, bone_skinning);	// Send final pose to shader

// Draw all meshes for model
VBM_Model_Submit(model, mattran, mesh_visibility_mask);

if ( mesh_flash > 0.0 ) {
	var amt = sin(2.0*pi*mesh_flash)*0.5 + 0.5;
	if ( amt > 0.0 ) {
		VBM_Model_SubmitMesh(model, mesh_select);	// Draw single mesh with flash value
	}
}
shader_reset();

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

// Restore previous GPU state
gpu_pop_state();


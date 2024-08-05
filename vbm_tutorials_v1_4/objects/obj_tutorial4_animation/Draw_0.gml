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
shader_set(shd_rigged);

matrix_set(matrix_world, mattran); // Transform matrix
shader_set_uniform_f(u_rigged_boneselect, bone_select);
shader_set_uniform_f(u_rigged_meshflash, 0);
shader_set_uniform_matrix_array(u_rigged_transforms, bone_matrices);	// Send final pose to shader

// Draw all meshes for model
VBM_Model_SubmitExt(model, VBM_SUBMIT_TEXDEFAULT, mesh_hide_bits, 0);	// Draw with texture

if ( mesh_flash > 0.0 ) {
	shader_set_uniform_f(u_rigged_meshflash, sin(2.0*pi*mesh_flash)*0.5 + 0.5);
	VBM_Model_SubmitMesh(model, VBM_SUBMIT_TEXDEFAULT, mesh_select);	// Draw single mesh
}
shader_reset();

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

// Restore previous GPU state
gpu_pop_state();

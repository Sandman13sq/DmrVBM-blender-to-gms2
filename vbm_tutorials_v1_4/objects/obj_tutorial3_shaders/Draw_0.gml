/// @desc Set matrices and draw VB

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangles facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);

// Draw vertex buffers (Native)
matrix_set(matrix_world, mattran); // Model transform matrix

if (shadermode == 0) { // Draw native model
	shader_set(shd_tutorial3_native);	// Set shader for next draw calls
	VBM_Model_Submit(model_native, VBM_SUBMIT_TEXNONE);	// Ignore texture, only use vertex color
}
else { // Draw model with normals
	shader_set(shd_tutorial3_normal);	// Set shader for next draw calls
	shader_set_uniform_f_array(u_normal_lightpos, lightpos); // Set light position for shader
	shader_set_uniform_f_array(u_normal_eyepos, eyepos); // Set eye position for shader
	VBM_Model_Submit(model_normal, VBM_SUBMIT_TEXNONE);	// Ignore texture, only use vertex color
}

shader_reset();	// Reset to default GM shader

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

// Restore previous GPU state
gpu_pop_state();

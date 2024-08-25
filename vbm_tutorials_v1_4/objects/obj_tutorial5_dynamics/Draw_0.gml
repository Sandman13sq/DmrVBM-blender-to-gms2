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
shader_set(shd_tutorial5_style);
shader_set_uniform_f_array(u_style_eyeforward, viewforward);	// Eye Forward
shader_set_uniform_f_array(u_style_eyeright, viewright);	// Eye Right
shader_set_uniform_f_array(u_style_eyeup, viewup);			// Eye Up

matrix_set(matrix_world, mattran); // Transform matrix
shader_set_uniform_f(u_style_boneselect, bone_select);
shader_set_uniform_f(u_style_meshflash, 0);
shader_set_uniform_matrix_array(u_style_bonematrices, VBM_Animator_GetMat4FinalArray(animator));	// Send final pose to shader

shader_set_uniform_f(u_style_outline, 1.0);	// Enable outline
gpu_set_cullmode(cull_counterclockwise);	// Draw backfacing triangles
VBM_Model_SubmitExt(model, VBM_SUBMIT_TEXDEFAULT, mesh_hide_bits, 0);	// Draw outline shell

gpu_set_cullmode(cull_clockwise);	// Draw frontfacing triangles
shader_set_uniform_f(u_style_outline, 0.0);	// Disable outline
VBM_Model_SubmitExt(model, VBM_SUBMIT_TEXDEFAULT, mesh_hide_bits, 0);	// Draw model

if ( mesh_flash > 0.0 ) {
	shader_set_uniform_f(u_style_meshflash, sin(2.0*pi*mesh_flash)*0.5 + 0.5);
	VBM_Model_SubmitMesh(model, VBM_SUBMIT_TEXDEFAULT, mesh_select);	// Draw single mesh
}
shader_reset();

// Draw Swing Bones
if ( show_bones ) {
	var s = 0.02;
	gpu_set_ztestenable(false);
	for (var i = 0; i < animator.swing_count; i++) {
		var swg = animator.swing_bones[i];
		matrix_set(matrix_world, matrix_build(swg.vcurr[0],swg.vcurr[1],swg.vcurr[2],0,0,0,s,s,s));
		VBM_Model_Submit(model_rotation, -1);
	}
}

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

// Restore previous GPU state
gpu_pop_state();

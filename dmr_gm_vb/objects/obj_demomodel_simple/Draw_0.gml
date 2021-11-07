/// @desc

gpu_push_state();

// GPU State
gpu_set_cullmode(cullmode);	// Don't draw tris facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// No custom shader
if use_gm_default_shader
{
	// Render model
	vertex_submit(vb, wireframe? pr_linelist: pr_trianglelist, -1);
}
// Use custom shader
else
{
	shader_set(shd_simple);

	// Set Uniforms
	drawmatrix = BuildDrawMatrix(alpha, 0, 0, 0,
		ArrayToRGB(colorblend), colorblend[3],
		ArrayToRGB(colorfill), colorfill[3],
		);
	
	shader_set_uniform_f_array(u_shd_model_drawmatrix, drawmatrix);
	
	matrix_set(matrix_world, matrix_build(
		obj_modeltest.modelposition[0], 
		obj_modeltest.modelposition[1], 
		obj_modeltest.modelposition[2], 
		0, 0, -obj_modeltest.modelzrot, 1, 1, 1));
	
	// Render model
	vertex_submit(vb, wireframe? pr_linelist: pr_trianglelist, -1);
}

// Restore State
shader_reset();
gpu_pop_state();
/// @desc Set matrices and draw VB

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangles facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);

// Draw vertex buffers (Simple)
shader_set(shd_native);	// Set shader for next draw calls

matrix_set(matrix_world, matrix_build(0,0,0, 0,0,0, 0.1,0.1,0.1));
if (vb_axis >= 0) {vertex_submit(vb_axis, pr_trianglelist, -1);}
matrix_set(matrix_world, matrix_build(0,0,0, 0,0,0, 1,1,1));
if (vb_grid >= 0) {vertex_submit(vb_grid, pr_linelist, -1);}	// <- pr_linelist here

matrix_set(matrix_world, mattran); // Model transform matrix

if (shadermode == 0) // Draw native model
{
	if (vb_treat_native >= 0)
	{
		//shader_set(shd_native);
		vertex_submit(vb_treat_native, pr_trianglelist, -1);
	}
}
else // Draw model with normals
{
	if (vb_treat_normal >= 0)
	{
		shader_set(shd_normal);	// Switch to shader with vertex normal attributes
		shader_set_uniform_f_array(u_normal_lightpos, lightpos); // Set light position for shader
		shader_set_uniform_f_array(u_normal_eyepos, eyepos); // Set light position for shader
		vertex_submit(vb_treat_normal, pr_trianglelist, -1);
	}
}

shader_reset();	// Reset to default GMS shader

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

// Restore previous GPU state
gpu_pop_state();

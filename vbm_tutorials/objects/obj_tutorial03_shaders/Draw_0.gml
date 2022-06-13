/// @desc Set matrices and draw VBs

// Store room matrices
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
shader_set(shd_simple);	// Set shader for next draw calls

if (vb_grid >= 0) {vertex_submit(vb_grid, pr_linelist, -1);}	// <- pr_linelist here
if (vb_axis >= 0) {vertex_submit(vb_axis, pr_trianglelist, -1);}

matrix_set(matrix_world, mattran); // Model transform matrix

if (shadermode == 0) // Draw simple model
{
	if (vb_curly_simple >= 0)
	{
		//shader_set(shd_simple);
		vertex_submit(vb_curly_simple, pr_trianglelist, -1);
	}
}
else // Draw model with normals
{
	if (vb_curly_normal >= 0)
	{
		shader_set(shd_normal);	// Switch to shader with vertex normal attributes
		shader_set_uniform_f_array(u_normal_lightpos, lightpos); // Set light position for shader
		vertex_submit(vb_curly_normal, pr_trianglelist, -1);
	}
}

shader_reset();	// Reset to default GMS shader

// Restore previous matrices
matrix_set(matrix_projection, roommatrices[0]);
matrix_set(matrix_view, roommatrices[1]);
matrix_set(matrix_world, roommatrices[2]);

// Restore previous GPU state
gpu_pop_state();

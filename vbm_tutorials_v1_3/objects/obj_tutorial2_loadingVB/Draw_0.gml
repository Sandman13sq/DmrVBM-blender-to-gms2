/// @desc Set matrices and draw VB

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, mattran); // No effect for default GM shader

// Draw vertex buffer
if (vb_axis >= 0)
{
	vertex_submit(vb_axis, pr_trianglelist, -1);
}

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());


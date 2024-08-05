/// @desc Set matrices and draw VB

// Set camera matrices
matrix_set(matrix_projection, matproj);	// Camera -> Screen
matrix_set(matrix_view, matview);	// World -> Camera
matrix_set(matrix_world, mattran);	// Model -> World

// Draw vertex buffer
VBM_Model_Submit(model, VBM_SUBMIT_TEXDEFAULT);	// Default uses texture stored in mesh, if any

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());


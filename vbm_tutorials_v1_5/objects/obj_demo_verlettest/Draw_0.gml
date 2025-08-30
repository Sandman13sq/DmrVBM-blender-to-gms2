/// @desc Render

matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, mattran);

var viewmats = [
	matview,
	matrix_build_lookat(6,-2,5, 6,-2,0, 0,1,0),
	matrix_build_lookat(6,-10,2, 6,0,2, 0,0,1)
];

for (var vindex = 0; vindex < array_length(viewmats); vindex++) {
	matrix_set(matrix_view, viewmats[vindex]);
	
	matrix_set(matrix_world, mattran);
	vertex_submit(vb, pr_linelist, -1);

	matrix_set(matrix_world, matrix_build(lx,ly,lz, 0,0,0, 0.5,0.5,0.5));
	VBM_Model_SubmitMesh(model, 0, -1);
	
	matrix_set(matrix_world, matrix_build(px,py,pz, 0,0,0, 1,1,1));
	VBM_Model_SubmitMesh(model, 0, -1);
	
	matrix_set(matrix_world, matrix_build(qx,qy,qz, 0,0,0, 0.5,0.5,0.5));
	VBM_Model_SubmitMesh(model, 0, -1);
	
	matrix_set(matrix_projection, matrix_build_projection_ortho(16, 9, 0.1, 100));
	
}

// Restore previous room matrices
matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());


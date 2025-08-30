/// @desc Draw Scene

// GPU State
gpu_push_state();
gpu_set_cullmode(cull_clockwise);	// Don't draw triangles facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

// Set camera matrices
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, matrix_build_identity());

// Draw Level using default shader
VBM_Model_Submit(model_level, matrix_build_identity());

// Draw Entities
shader_set(shd_tutorial4_animation);

var m = matrix_build_identity();
var _u_boneskinning = shader_get_uniform(shader_current(), "u_bonematrices");
var e;
var n = array_length(entitylist);
for (var i = 0; i < n; i++) {
	e = entitylist[i];
	if ( e == 0 ) {continue;}
	if ( e.model == undefined ) {continue;}
	
	shader_set_uniform_matrix_array(_u_boneskinning, e.bone_skinning);
	VBM_Model_Submit(e.model, e.matrix);
}

// Draw Entity Shadows
shader_reset();
for (var i = 0; i < n; i++) {
	e = entitylist[i];
	if ( e==0 ) {continue;}
	
	m = matrix_build(e.location[0], e.location[1], e.shadow_z+0.01, 0,0,0, 1,1,1);
	m[VBM_M20] = e.shadw_normal[0];
	m[VBM_M21] = e.shadw_normal[1];
	m[VBM_M22] = e.shadw_normal[2];
	
	VBM_Model_Submit(model_shadow, m);
}

// Restore last draw state
gpu_pop_state();
shader_reset();

matrix_set(matrix_projection, camera_get_proj_mat(camera_get_active()));
matrix_set(matrix_view, camera_get_view_mat(camera_get_active()));
matrix_set(matrix_world, matrix_build_identity());

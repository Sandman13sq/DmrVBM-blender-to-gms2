/// @desc

draw_clear(0);

gpu_push_state();

var oldmats = [
	matrix_get(matrix_projection),
	matrix_get(matrix_view),
	matrix_get(matrix_world),
];


matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, matrix_build_identity());

// Default
shader_set(shd_default);

vertex_submit(vb_grid, pr_linelist, -1);

// Model
shader_set(shd_model);

gpu_set_cullmode(cull_clockwise);
gpu_set_ztestenable(1);
gpu_set_zwriteenable(1);

matrix_set(matrix_world, mattran);
shader_set_uniform_f_array(u_drawmatrix, drawmatrix);
shader_set_uniform_f_array(u_camera, camera);
vertex_submit(vb, pr_trianglelist, -1);

shader_reset();

matrix_set(matrix_world, oldmats[2]);
matrix_set(matrix_view, oldmats[1]);
matrix_set(matrix_projection, oldmats[0]);

gpu_pop_state();

draw_text(300, 200, camera);
draw_text(300, 220, [x, y, z]);

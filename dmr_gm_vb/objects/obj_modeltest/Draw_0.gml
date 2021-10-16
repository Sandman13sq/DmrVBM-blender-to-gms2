/// @desc

//draw_clear(0);

gpu_push_state();

var oldmats = [
	matrix_get(matrix_projection),
	matrix_get(matrix_view),
	matrix_get(matrix_world),
];

shader_set(shd_model);

gpu_set_cullmode(cull_clockwise);
gpu_set_ztestenable(1);
gpu_set_zwriteenable(1);

matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);

vertex_submit(vb, pr_trianglelist, -1);

shader_reset();

matrix_set(matrix_world, oldmats[2]);
matrix_set(matrix_view, oldmats[1]);
matrix_set(matrix_projection, oldmats[0]);

gpu_pop_state();

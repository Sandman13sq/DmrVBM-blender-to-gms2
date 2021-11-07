/// @desc

gpu_push_state();

gpu_set_cullmode(cull_clockwise);
gpu_set_ztestenable(1);
gpu_set_zwriteenable(1);

shader_set(shd_model);

matrix_set(matrix_world, matrix_build_identity());
shader_set_uniform_f_array(u_shd_model_drawmatrix, BuildDrawMatrix(1, 0, 0.5, 0));
vertex_submit(vb_world, pr_trianglelist, -1);

shader_reset();

gpu_pop_state();

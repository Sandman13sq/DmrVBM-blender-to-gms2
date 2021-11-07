/// @desc

gpu_push_state();

// GPU State
gpu_set_cullmode(cull_clockwise);
gpu_set_ztestenable(1);
gpu_set_zwriteenable(1);

shader_set(shd_model);

matrix_set(matrix_world, matrix_build_identity());

// Draw World
shader_set_uniform_f_array(u_shd_model_drawmatrix, BuildDrawMatrix(1, 0, 0.5, 0));
vertex_submit(vb_world, pr_trianglelist, -1);

shader_reset();

// Draw Grid
if drawgrid
{
	shader_set_uniform_f_array(u_shd_model_drawmatrix, BuildDrawMatrix(1, 1, 0, 0));
	vertex_submit(vb_grid, pr_linelist, -1);
}

// Draw Camera Position
if drawcamerapos
{
	gpu_set_zfunc(cmpfunc_always); // Always draw on top
	matrix_set(matrix_world, matrix_build(
		camera.location[0], -camera.location[1], camera.location[2], 0,0,0, 1,1,1));
	vertex_submit(vb_ball, pr_trianglelist, -1);
}

gpu_pop_state();

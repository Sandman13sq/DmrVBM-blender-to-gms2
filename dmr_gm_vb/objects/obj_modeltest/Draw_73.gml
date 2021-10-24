/// @desc 

gpu_pop_state();

RENDERING.SetShader();
matrix_set(matrix_projection, matrix_build_projection_ortho(window_get_width(), window_get_height(), 1, 10000));
matrix_set(matrix_view, matrix_build_lookat(0,0,-1, 0,0,0, 0,1,0));
matrix_set(matrix_world, matrix_build_identity());


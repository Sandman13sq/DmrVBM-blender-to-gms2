/// @desc 

draw_clear(bkcolor);
gpu_push_state();

// Model
gpu_set_cullmode(cull_clockwise);
gpu_set_ztestenable(1);
gpu_set_zwriteenable(1);

// Set render matrices for models
matrix_set(matrix_projection, camera.matproj);
matrix_set(matrix_view, camera.matview);
matrix_set(matrix_world, matrix_build_identity());

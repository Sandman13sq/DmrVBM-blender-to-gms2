/// @desc Clear Screen

draw_clear(clearcolor);

matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, matrix_build_identity());

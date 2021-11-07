/// @desc

shader_reset();

matrix_set(matrix_projection, roomcameramats[0]);
matrix_set(matrix_view, roomcameramats[1]);
matrix_set(matrix_world, matrix_build_identity());

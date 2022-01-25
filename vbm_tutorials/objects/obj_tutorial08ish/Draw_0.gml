/// @desc 

// Store room matrices in matrix stack
matrix_stack_push(matrix_get(matrix_projection));
matrix_stack_push(matrix_get(matrix_view));
matrix_stack_push(matrix_get(matrix_world));

// Restore previous matrices from matrix stack
matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, matrix_build_identity());

// Draw vertex buffer
vertex_submit(vb_tri, pr_trianglestrip, -1);

// Restore previous matrices from matrix stack
matrix_set(matrix_world, matrix_stack_pop());
matrix_set(matrix_view, matrix_stack_pop());
matrix_set(matrix_projection, matrix_stack_pop());



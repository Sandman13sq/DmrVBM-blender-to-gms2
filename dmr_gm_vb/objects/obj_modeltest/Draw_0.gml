/// @desc

RENDERING.SetShader(shd_model);
matrix_set(matrix_world, matrix_build_identity());
shader_set_uniform_f_array(RENDERING.shaderactive.u_drawmatrix, BuildDrawMatrix(1));
vertex_submit(vb_world, pr_trianglelist, -1);


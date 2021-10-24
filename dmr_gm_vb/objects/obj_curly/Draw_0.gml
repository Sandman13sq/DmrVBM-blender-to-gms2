/// @desc 

RENDERING.SetShader(shd_modelrigged);

shader_set_uniform_f_array(
	RENDERING.shaderactive.u_drawmatrix, BuildDrawMatrix(1));
shader_set_uniform_matrix_array(
	RENDERING.shaderactive.u_matpose, matpose);

var n = vbx_model.vbcount;
for (var i = 0; i < n; i++)
{
	if meshvisible & (1<<i)
	{
		vertex_submit(vbx_model.vb[i], pr_trianglelist, -1);	
	}
}

RENDERING.SetShader();


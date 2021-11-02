/// @desc 

switch(shadermode)
{
	// Rigged
	case(0):
		RENDERING.SetShader(shd_modelrigged);
		
		shader_set_uniform_f_array(
			RENDERING.shaderactive.u_drawmatrix, drawmatrix);
		shader_set_uniform_matrix_array(
			RENDERING.shaderactive.u_matpose, mattran);
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
		break;
	
	// Normal Map
	case(1):
		RENDERING.SetShader(shd_normalmap);
		
		shader_set_uniform_f_array(
			RENDERING.shaderactive.u_drawmatrix, drawmatrix);
		shader_set_uniform_matrix_array(
			RENDERING.shaderactive.u_matpose, mattran);
		shader_set_uniform_matrix_array(
			RENDERING.shaderactive.u_matpose, matpose);

		var n = vbx_normal.vbcount;
		for (var i = 0; i < n; i++)
		{
			if meshvisible & (1<<i)
			{
				vertex_submit(vbx_normal.vb[i], pr_trianglelist, meshtexture[i]);	
			}
		}
		break;
}

RENDERING.SetShader();


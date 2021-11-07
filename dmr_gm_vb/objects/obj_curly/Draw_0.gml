/// @desc 

return;

switch(shadermode)
{
	// Rigged
	case(0):
		RENDERING.SetShader(shd_modelrigged);
		
		shader_set_uniform_matrix_array(
			RENDERING.shaderactive.u_matpose, matpose);
		matrix_set(matrix_world, mattran);
		
		var me;
		var n = vbx_model.vbcount;
		for (var i = 0; i < n; i++)
		{
			if meshvisible & (1<<i)
			{
				me = meshdata[i];
				
				shader_set_uniform_f_array(
					RENDERING.shaderactive.u_drawmatrix, 
					BuildDrawMatrix(1, me.emission, me.shine, me.sss));
				
				vertex_submit(vbx_model.vb[i], pr_trianglelist, me.texturediffuse);	
			}
		}
		break;
	
	// Normal Map
	case(1):
		RENDERING.SetShader(shd_normalmap);
		
		shader_set_uniform_f_array(
			RENDERING.shaderactive.u_drawmatrix, drawmatrix);
		shader_set_uniform_matrix_array(
			RENDERING.shaderactive.u_matpose, matpose);
		matrix_set(matrix_world, mattran);
		
		var me;
		var n = vbx_normal.vbcount;
		for (var i = 0; i < n; i++)
		{
			if meshvisible & (1<<i)
			{
				me = meshdata[i];
				
				shader_set_uniform_f_array(
					RENDERING.shaderactive.u_drawmatrix, 
					BuildDrawMatrix(1, me.emission, me.shine, me.sss));
				
				vertex_submit(vbx_normal.vb[i], pr_trianglelist, me.texturenormal);	
			}
		}
		break;
}

RENDERING.SetShader();


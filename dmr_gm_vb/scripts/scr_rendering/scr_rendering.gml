/// @desc

// Initialized in obj_main
#macro RENDERING global.g_rendering

function Rendering() constructor
{
	#region // Shaders =====================================================
	
	shaderdata = array_create(16);
	shaderactive = -1;
	shadercount = 0;
	
	for (var shd = 0; shd < 16; shd++)
	{
		shaderdata[shd] = {};
		shadercount++;
	}
	
	#endregion
	
	#region // VB Formats ==================================================
	
	vbformat = {
		basic : -1,
		model : -1,
		rigged : -1,
		normal : -1,
	};
	
	// Basic VB Attributes:
	//		pos3f, color4B, uv2f
	vertex_format_begin();
	vertex_format_add_position_3d();
	vertex_format_add_color();
	vertex_format_add_texcoord();
	vbformat.basic = vertex_format_end();
	
	// Static Model Attributes:
	//		pos3f, nor3f, color4B, uv2f,
	vertex_format_begin();
	vertex_format_add_position_3d();
	vertex_format_add_normal();
	vertex_format_add_color();
	vertex_format_add_texcoord();
	vbformat.model = vertex_format_end();
	
	// Rigged Model Attributes:
	//		pos3f, nor3f, color4B, uv2f, bone4f, weight4f
	vertex_format_begin();
	vertex_format_add_position_3d();
	vertex_format_add_normal();
	vertex_format_add_color();
	vertex_format_add_texcoord();
	vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
	vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
	vbformat.rigged = vertex_format_end();
	
	// Full Model Attributes:
	//		pos3f, nor3f, tan3f, bitan3f, color4B, uv2f, bone4f, weight4f
	vertex_format_begin();
	vertex_format_add_position_3d();
	vertex_format_add_normal();
	vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Tangent
	vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Bitangent
	vertex_format_add_color();
	vertex_format_add_texcoord();
	vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
	vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
	vbformat.normal = vertex_format_end();
	
	#endregion
	
	function Free()
	{
		
	}
	
	function DefineUniform(_handle)
	{
		var err;
		for (var shd = 0; shd < shadercount; shd++)
		{
			try
			{
				shaderdata[shd][$ _handle] = shader_get_uniform(shd, _handle);
				if !shaderdata[shd][$ _handle]
				{
					shaderdata[shd][$ _handle] = shader_get_sampler_index(shd, _handle);
				}
			}
			catch(err) {}
		}
	}
	
	function DefineVBFormat(_key, _vbf)
	{
		vbformat[$ _key] = _vbf;
	}
	
	function SetShader(shd = -1)
	{
		if shd < 0
		{
			shaderactive = -1;
			shader_reset();
			return;
		}
		
		if shader_current() != shd
		{
			shader_set(shd);
			shaderactive = shaderdata[shd];
		}
	}
	
	function ShaderActive() {return shaderactive;}
}

function BuildDrawMatrix(alpha=1, emission=0, shine=1, sss=0, fillcol=0, fillamt=0, blendcol=0, blendamt=0)
{
	return [
		alpha, emission, shine, sss, 
		color_get_red(fillcol)*0.004, color_get_green(fillcol)*0.004, color_get_blue(fillcol)*0.004, fillamt,
		color_get_red(blendcol)*0.004, color_get_green(blendcol)*0.004, color_get_blue(blendcol)*0.004, blendamt,
		0,0,0,0
	];
}


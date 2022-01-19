/*
*/

/// @arg init?
function Structor_VBFormat()
{
	if argument0
	{
		vbf = {
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
		vbf.basic = vertex_format_end();

		// Static Model Attributes:
		//		pos3f, nor3f, color4B, uv2f,
		vertex_format_begin();
		vertex_format_add_position_3d();
		vertex_format_add_normal();
		vertex_format_add_color();
		vertex_format_add_texcoord();
		vbf.model = vertex_format_end();

		// Rigged Model Attributes:
		//		pos3f, nor3f, color4B, uv2f, bone4f, weight4f
		vertex_format_begin();
		vertex_format_add_position_3d();
		vertex_format_add_normal();
		vertex_format_add_color();
		vertex_format_add_texcoord();
		vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
		vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
		vbf.rigged = vertex_format_end();
		
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
		vbf.normal = vertex_format_end();
	}
	else
	{
		vertex_format_delete(vbf.basic);
		vertex_format_delete(vbf.model);
		vertex_format_delete(vbf.rigged);
		vertex_format_delete(vbf.normal);
	}
}

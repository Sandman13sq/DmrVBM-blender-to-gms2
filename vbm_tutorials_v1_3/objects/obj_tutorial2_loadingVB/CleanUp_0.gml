/// @desc Free dynamic data

if (vbf_native != -1)
{
	vertex_format_delete(vbf_native);
}

// Valid vertex buffers have a value of 0 or greater. -1 if invalid
if (vb_axis >= 0) {vertex_delete_buffer(vb_axis);}


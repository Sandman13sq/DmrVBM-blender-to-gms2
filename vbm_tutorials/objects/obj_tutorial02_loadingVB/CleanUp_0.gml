/// @desc Free dynamic data

vertex_format_delete(vbf_simple);

// Valid vertex buffers have a value of 0 or greater. -1 if invalid
if (vb_axis >= 0) {vertex_delete_buffer(vb_axis);}


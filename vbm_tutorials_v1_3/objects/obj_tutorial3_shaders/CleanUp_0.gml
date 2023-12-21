/// @desc Free dynamic data

// Formats
vertex_format_delete(vbf_native);
vertex_format_delete(vbf_normal);

// VBs
if (vb_axis >= 0) {vertex_delete_buffer(vb_axis);}
if (vb_grid >= 0) {vertex_delete_buffer(vb_grid);}
if (vb_treat_native >= 0) {vertex_delete_buffer(vb_treat_native);}
if (vb_treat_normal >= 0) {vertex_delete_buffer(vb_treat_normal);}

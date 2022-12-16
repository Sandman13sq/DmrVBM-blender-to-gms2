/// @desc Free dynamic data

// Formats
vertex_format_delete(vbf_simple);
vertex_format_delete(vbf_normal);

// VBs
if (vb_axis >= 0) {vertex_delete_buffer(vb_axis);}
if (vb_grid >= 0) {vertex_delete_buffer(vb_grid);}
if (vb_starcie_simple >= 0) {vertex_delete_buffer(vb_starcie_simple);}
if (vb_starcie_normal >= 0) {vertex_delete_buffer(vb_starcie_normal);}

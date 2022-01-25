/// @desc Free dynamic data

vertex_format_delete(vbf_simple);
vertex_format_delete(vbf_normal);

vertex_delete_buffer(vb_axis);
vertex_delete_buffer(vb_grid);

VBMFree(vbm_curly);

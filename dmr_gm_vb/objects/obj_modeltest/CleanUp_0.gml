/// @desc

vertex_format_delete(vbf_model);
vertex_format_delete(vbf_default);
vertex_delete_buffer(vb);
vertex_delete_buffer(vb_grid);
vertex_delete_buffer(vb_world);

VBXFree(vbx);

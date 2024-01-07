/// @desc Free dynamic data

// Vertex buffers and formats need to be removed from memory when no longer needed
vertex_format_delete(vbf_native);
vertex_delete_buffer(vb_tri);

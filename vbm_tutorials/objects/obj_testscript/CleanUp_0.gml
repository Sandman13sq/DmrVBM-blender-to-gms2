/// @desc 

vertex_delete_buffer(vb_curly_nocompression);
vertex_delete_buffer(vb_curly_fullcompression);
vertex_delete_buffer(vb_curly_floatcolors);
vertex_delete_buffer(vb_curly_edgesonly);
vertex_delete_buffer(vb_curly_scaled);
vertex_delete_buffer(vb_instanced);

VBMFree(vbm_curly);
VBMFree(vbm_wrongpath);
VBMFree(vbm_wrongfiletype);
VBMFree(vbm_curly_uncompressed);
VBMFree(vbm_curly_compressed);
VBMFree(vbm_curly_vb);
VBMFree(vbm_instanced);
VBMFree(vbm_curly_exportlist);
VBMFree(vb_world);

vertex_format_delete(vbf_simple);
vertex_format_delete(vbf_normal);
vertex_format_delete(vbf_rigged);

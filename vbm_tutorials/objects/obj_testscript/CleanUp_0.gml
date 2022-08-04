/// @desc 

// VBs
vertex_delete_buffer(vb_kindle_nocompression);
vertex_delete_buffer(vb_kindle_fullcompression);
vertex_delete_buffer(vb_kindle_floatcolors);
vertex_delete_buffer(vb_kindle_edgesonly);
vertex_delete_buffer(vb_kindle_scaled);
vertex_delete_buffer(vb_instanced);

// VBMs
VBMFree(vbm_wrongpath);
VBMFree(vbm_wrongfiletype);
VBMFree(vbm_kindle_uncompressed);
VBMFree(vbm_kindle_compressed);
VBMFree(vbm_kindle_vb);
VBMFree(vbm_kindle_exportlist);
VBMFree(vbm_kindle_complete);
VBMFree(vbm_instanced);
VBMFree(vb_world);

// Formats
vertex_format_delete(vbf_simple);
vertex_format_delete(vbf_normal);
vertex_format_delete(vbf_rigged);

sprite_delete(normalmap);

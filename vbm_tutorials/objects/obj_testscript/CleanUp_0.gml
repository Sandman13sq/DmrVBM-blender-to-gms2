/// @desc 

// VBs
vertex_delete_buffer(vb_starcie_nocompression);
vertex_delete_buffer(vb_starcie_fullcompression);
vertex_delete_buffer(vb_starcie_floatcolors);
vertex_delete_buffer(vb_starcie_edgesonly);
vertex_delete_buffer(vb_starcie_scaled);
vertex_delete_buffer(vb_instanced);

// VBMs
VBMFree(vbm_wrongpath);
VBMFree(vbm_wrongfiletype);
VBMFree(vbm_starcie_uncompressed);
VBMFree(vbm_starcie_compressed);
VBMFree(vbm_starcie_vb);
VBMFree(vbm_starcie_exportlist);
VBMFree(vbm_starcie_complete);
VBMFree(vbm_instanced);
VBMFree(vb_world);

// Formats
vertex_format_delete(vbf_simple);
vertex_format_delete(vbf_normal);
vertex_format_delete(vbf_rigged);

sprite_delete(normalmap);

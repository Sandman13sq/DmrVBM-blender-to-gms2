/// @desc Free dynamic data

// Formats
vertex_format_delete(vbf_simple);
vertex_format_delete(vbf_rigged);

// VBs
if (vb_axis >= 0) {vertex_delete_buffer(vb_axis);}
if (vb_grid >= 0) {vertex_delete_buffer(vb_grid);}

// VBM
VBMFree(vbm_curly);

// TRK
TRKFree(trk_wave);

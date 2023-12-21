/// @desc Free dynamic data

// Formats
vertex_format_delete(vbf_native);

// VBs
if (vb_axis >= 0) {vertex_delete_buffer(vb_axis);}
if (vb_grid >= 0) {vertex_delete_buffer(vb_grid);}

// VBM
VBMFree(vbm_treat);

// Sprite
sprite_delete(spr_col);

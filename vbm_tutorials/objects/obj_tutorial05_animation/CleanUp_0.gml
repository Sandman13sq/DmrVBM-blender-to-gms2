/// @desc Free dynamic data

// Formats
vertex_format_delete(vbf_simple);

// VBs
if (vb_axis >= 0) {vertex_delete_buffer(vb_axis);}
if (vb_grid >= 0) {vertex_delete_buffer(vb_grid);}

// VBM
VBMFree(vbm_starcie);

// TRK
TRKFree(trk_lean);
TRKFree(trk_blink);

// Sprite
sprite_delete(spr_col);

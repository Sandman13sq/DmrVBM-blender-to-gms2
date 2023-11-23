/// @desc 

event_inherited();

VBMFree(vbm_starcie_prm);

for (var i = 0; i < array_length(animations); i++)
{
	TRKFree(animations[i]);
}

sprite_delete(spr_col);
sprite_delete(spr_nor);
sprite_delete(spr_prm);

/// @desc

function BuildDrawMatrix(alpha=1, emission=0, shine=1, sss=0, fillcol=0, fillamt=0, blendcol=0, blendamt=0)
{
	return [
		alpha, emission, shine, sss, 
		color_get_red(fillcol)*0.004, color_get_green(fillcol)*0.004, color_get_blue(fillcol)*0.004, fillamt,
		color_get_red(blendcol)*0.004, color_get_green(blendcol)*0.004, color_get_blue(blendcol)*0.004, blendamt,
		0,0,0,0
	];
}


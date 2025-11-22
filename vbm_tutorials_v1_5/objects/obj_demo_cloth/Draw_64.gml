/// @desc

var xx = 20;
var yy = 100.0;
for (var p = 0; p < pointcount; p++) {
	var p1 = p*VBM_BONEPARTICLE._len;
	
	draw_text(xx, yy, string([
		points[p1+VBM_BONEPARTICLE.xcurr],
		points[p1+VBM_BONEPARTICLE.ycurr],
		points[p1+VBM_BONEPARTICLE.zcurr]
	]));
	
	yy += 12;
}


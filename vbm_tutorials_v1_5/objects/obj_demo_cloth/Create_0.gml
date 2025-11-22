/// @desc

matview = matrix_build_identity();
matproj = matrix_build_identity();

pointcount = 0;
segmentcount = 0;
w = 32;
r = 0.1;
circle = [r*w/2, r*w/2, 1];
circle_radius = 0.5;

points = array_create(w*w*VBM_BONEPARTICLE._len);	// [<x,y,z>, ...]
segments = array_create(VBM_BONESEGMENT._len);	// [<p1, p2, length>, ...]

var zz = 2;
// Points
var p = 0;
for (var yy = 0; yy < w; yy++) {
	for (var xx = 0; xx < w; xx++) {
		points[p+VBM_BONEPARTICLE.xcurr] = xx*r;
		points[p+VBM_BONEPARTICLE.ycurr] = yy*r;
		points[p+VBM_BONEPARTICLE.zcurr] = zz;
		points[p+VBM_BONEPARTICLE.xlast] = xx*r;
		points[p+VBM_BONEPARTICLE.ylast] = yy*r;
		points[p+VBM_BONEPARTICLE.zlast] = zz;
		points[p+VBM_BONEPARTICLE.mass] = (xx==0)? 10000000: 1.0;
		p += VBM_BONEPARTICLE._len;
	}
}
pointcount = p/VBM_BONEPARTICLE._len;

// Segments
var s = 0;
for (var yy = 0; yy < w-1; yy++) {
	for (var xx = 0; xx < w-1; xx++) {
		segments[s+VBM_BONESEGMENT.bone0] = (w*(yy+0)+(xx+0));	// start
		segments[s+VBM_BONESEGMENT.bone1] = (w*(yy+0)+(xx+1));	// end
		segments[s+VBM_BONESEGMENT.length] = r;
		s += VBM_BONESEGMENT._len;
		segments[s+VBM_BONESEGMENT.bone0] = (w*(yy+0)+(xx+0));	// start
		segments[s+VBM_BONESEGMENT.bone1] = (w*(yy+1)+(xx+0));	// end
		segments[s+VBM_BONESEGMENT.length] = r;
		s += VBM_BONESEGMENT._len;
	}
}
segmentcount = s/VBM_BONESEGMENT._len;



// Scene ------------------------------------------
matview = matrix_build_identity();
matproj = matrix_build_identity();
mattran = matrix_build_identity();

vb = vertex_create_buffer();
format = VBM_FormatBuild(VBM_FORMAT_NATIVE);

event_perform(ev_step, ev_step_normal);


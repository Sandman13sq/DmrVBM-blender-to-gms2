
// Vertex Buffer ------------------------------------------------------------------
if (vb != -1) {
	vertex_delete_buffer(vb);
}

vb = vertex_create_buffer();
vertex_begin(vb, format);

var s=0, p0=0, p1=0;
for (var segment_index = 0; segment_index < segmentcount; segment_index++) {
	s = segment_index*VBM_BONESEGMENT._len;
	p0 = segments[s+VBM_BONESEGMENT.bone0]*VBM_BONEPARTICLE._len;
	p1 = segments[s+VBM_BONESEGMENT.bone1]*VBM_BONEPARTICLE._len;
	
	vertex_position_3d(
		vb,
		points[p0+VBM_BONEPARTICLE.xcurr],
		points[p0+VBM_BONEPARTICLE.ycurr],
		points[p0+VBM_BONEPARTICLE.zcurr]
	);
	vertex_color(vb, c_green, 1);
	vertex_texcoord(vb, 0.0, 0.0);
	
	vertex_position_3d(
		vb, 
		points[p1+VBM_BONEPARTICLE.xcurr],
		points[p1+VBM_BONEPARTICLE.ycurr],
		points[p1+VBM_BONEPARTICLE.zcurr]
	);
	vertex_color(vb, c_green, 1);
	vertex_texcoord(vb, 0.0, 0.0);
}

vertex_end(vb);

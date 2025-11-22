/// @desc

// Points -------------------------------------------------------------------------
var dt = 1.0;
var grav = -0.001;
var vel = [0,0,0], last = [0,0,0], acc = [0,0,grav];
for (var p = 0; p < pointcount; p++) {
	var p1 = p*VBM_BONEPARTICLE._len;
	
	// Current = current + velocity + acceleration *dt*dt
	vel[0] = points[p1+VBM_BONEPARTICLE.xcurr] - points[p1+VBM_BONEPARTICLE.xlast];
	vel[1] = points[p1+VBM_BONEPARTICLE.ycurr] - points[p1+VBM_BONEPARTICLE.ylast];
	vel[2] = points[p1+VBM_BONEPARTICLE.zcurr] - points[p1+VBM_BONEPARTICLE.zlast];
	
	points[p1+VBM_BONEPARTICLE.xlast] = points[p1+VBM_BONEPARTICLE.xcurr];
	points[p1+VBM_BONEPARTICLE.ylast] = points[p1+VBM_BONEPARTICLE.ycurr];
	points[p1+VBM_BONEPARTICLE.zlast] = points[p1+VBM_BONEPARTICLE.zcurr];
	
	points[p1+VBM_BONEPARTICLE.xcurr] += vel[0] + acc[0] * dt*dt;
	points[p1+VBM_BONEPARTICLE.ycurr] += vel[1] + acc[1] * dt*dt;
	points[p1+VBM_BONEPARTICLE.zcurr] += vel[2] + acc[2] * dt*dt;
}

// Satisfy Constraints
math_set_epsilon(0.000000001);
for (var iteration = 0; iteration < 2; iteration++) {
	var delta = [0,0,0];
	var s=0, p1=0, p2=0, restlength=0.0, restlengthsquared=0.0, diff=0.0, deltalength=0.0;
	var invmass1=0.0, invmass2=0.0;
	
	for (var segment_index = 0; segment_index < segmentcount; segment_index++) {
		s = segment_index*VBM_BONESEGMENT._len;
		p1 = segments[s+VBM_BONESEGMENT.bone0]*VBM_BONEPARTICLE._len;
		p2 = segments[s+VBM_BONESEGMENT.bone1]*VBM_BONEPARTICLE._len;
		if ( p1==p2 ) {continue;}
	
		restlength = segments[s+VBM_BONESEGMENT.length];
		invmass1 = 1.0/points[p1+VBM_BONEPARTICLE.mass];
		invmass2 = 1.0/points[p2+VBM_BONEPARTICLE.mass];
		
		{
			for (var i = 0; i < 3; i++) {
				delta[i] = points[p2+i]-points[p1+i];
			}
			
			deltalength = point_distance_3d(0,0,0, delta[0], delta[1], delta[2]);
			diff = (deltalength-restlength) / (deltalength*(invmass1+invmass2));
			for (var i = 0; i < 3; i++) {
				points[p1+i] -= invmass1*delta[i]*diff;
				points[p2+i] += invmass2*delta[i]*diff;
			}
		}
	}
	points[VBM_BONEPARTICLE._len*(100)+VBM_BONEPARTICLE.xcurr] = 0;
	points[VBM_BONEPARTICLE._len*(100)+VBM_BONEPARTICLE.ycurr] = 0;
	points[VBM_BONEPARTICLE._len*(100)+VBM_BONEPARTICLE.zcurr] = 0;
}


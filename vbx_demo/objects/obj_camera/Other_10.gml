/// @desc Methods

// Updates view matrix
function UpdateMatView()
{
	var d;
	var loc = viewlocation;
	var fwrd = viewforward;
	var rght = viewright;
	var up = viewup;
	var dir = viewdirection;
	var pitch = viewpitch;
	
	loc[1] = loc[1];
	
	// Forward
	fwrd[@ 0] = dcos(dir) * dcos(pitch);
	fwrd[@ 1] = -dsin(dir) * dcos(pitch);
	fwrd[@ 2] = -dsin(pitch);
	d = point_distance_3d(0,0,0, fwrd[0], fwrd[1], fwrd[2]);
	fwrd[@ 0] /= d;
	fwrd[@ 1] /= d;
	fwrd[@ 2] /= d;
	
	// Right
	rght[@ 0] = dcos(dir+90) * dcos(pitch);
	rght[@ 1] = -dsin(dir+90) * dcos(pitch);
	rght[@ 2] = -dsin(pitch);
	d = point_distance_3d(0,0,0, rght[0], rght[1], rght[2]);
	rght[@ 0] /= d;
	rght[@ 1] /= d;
	rght[@ 2] /= d;
	
	// Up
	up[@ 0] = dcos(dir) * dcos(pitch-90);
	up[@ 1] = -dsin(dir) * dcos(pitch-90);
	up[@ 2] = -dsin(pitch-90);
	d = point_distance_3d(0,0,0, up[0], up[1], up[2]);
	up[@ 0] /= d;
	up[@ 1] /= d;
	up[@ 2] /= d;
	
	// View Matrix
	d = viewdistance;
	matview = matrix_build_lookat(
		loc[0]-fwrd[0]*d, loc[1]-fwrd[1]*d, loc[2]-fwrd[2]*d, 
		loc[0], loc[1], loc[2], 
		up[0], up[1], up[2]);
	
	matrix_set(matrix_projection, matproj);
	matrix_set(matrix_view, matview);
}

function ResetCameraPosition()
{
	viewlocation[0] = 0;
	viewlocation[1] = 0;
	viewlocation[2] = 7.77;
	
	viewdistance = 21;
	viewdirection = 91;
	viewpitch = 7;
}

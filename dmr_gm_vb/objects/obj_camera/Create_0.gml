/// @desc

location = [0,0,7];
	
width = 0;
height = 0;
	
viewforward = [0,1,0];
viewright = [1,0,0];
viewup = [0,0,1];
	
viewdistance = 32;
viewdirection = 110;
viewpitch = 15;
	
zfar = 1000;
znear = 1;
fieldofview = 50;
	
matproj = matrix_build_identity();
matview = matrix_build_identity();

viewdistance = 24;
viewdirection = 90;
viewpitch = 7;

mouseanchor = [0, 0];
cameraanchor = [0,0,0];
rotationanchor = [0, 0];
middlemode = 0;
middlelock = 0;

lock = false;
clearcolor = 0x201010;

lastfullscreen = window_get_fullscreen();

roomcameramats = [
	camera_get_proj_mat(view_camera),
	camera_get_view_mat(view_camera)
	];

// Updates view matrix
function UpdateMatView()
{
	var d;
	var loc = location;
	var fwrd = viewforward;
	var rght = viewright;
	var up = viewup;
	var dir = viewdirection;
	var pitch = viewpitch;
	
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
	// Correct Yflip
	matview = matrix_multiply(matrix_build(0,0,0,0,0,0,1,-1,1), matview);
	
	matrix_set(matrix_projection, matproj);
	matrix_set(matrix_view, matview);
}

UpdateMatView();
/// @desc

game_set_speed(1, gamespeed_microseconds);

location = [0,0,7];

width = 0;
height = 0;
	
viewforward = [0,1,0];
viewright = [1,0,0];
viewup = [0,0,1];

zfar = 1000;
znear = 1;
fieldofview = 50;
	
matproj = matrix_build_identity();
matview = matrix_build_identity();

viewdistance = 21;
viewdirection = 91;
viewpitch = 7;

mouseanchor = [0, 0];
cameraanchor = [0,0,0];
rotationanchor = [0, 0];
middlemode = 0;
middlelock = 0;

lock = false;
orbitmodel = false;
orbitspeed = 1;
clearcolor = 0x201010;

lastfullscreen = window_get_fullscreen();

roomcameramats = [
	camera_get_proj_mat(view_camera),
	camera_get_view_mat(view_camera)
	];

event_user(0);

ResetCameraPosition();
UpdateMatView();

/// @desc

event_user(0);

Structor_VBFormat(1);

// Controls ==========================================================

x = 0;
y = 0;
z = 0;

vbmode = 1;
keymode = 1;
interpolationtype = AniTrack_Intrpl.linear;
wireframe = 0;
zrot = 0;
poseindex = 0;

vbxvisible = ~0; // Bit field
dm_emission = 0;
dm_shine = 1;
dm_sss = 0;

mouseanchor = [0, 0];
cameraanchor = [0,0,0];
rotationanchor = [0, 0];
middlemode = 0;
middlelock = 0;

// Camera ==============================================================

camera = {
	location : [0,0,7],
	
	width : 0,
	height : 0,
	
	viewforward : [0,1,0],
	viewright : [1,0,0],
	viewup : [0,0,1],
	
	viewdistance : 32,
	viewdirection : 110,
	viewpitch : 15,
	
	zfar : 1000,
	znear : 1,
	fieldofview : 50,
	
	matproj : matrix_build_identity(),
	matview : matrix_build_identity(),
};

camera.viewdistance = 24;
camera.viewdirection = 90;
camera.viewpitch = 7;

UpdateView(); // Matrices are set here

bkcolor = 0x201010;

curly = instance_create_depth(0,0,0, obj_curly);

vb_world = LoadVertexBuffer("world.vb", RENDERING.vbformat.model);

drawmatrix = BuildDrawMatrix(1, 0, 1, 0); // Shader uniforms sent as one array

// Layout
event_user(1);

execinfo = "";
exectime = [0, 0];
frametime = 0;

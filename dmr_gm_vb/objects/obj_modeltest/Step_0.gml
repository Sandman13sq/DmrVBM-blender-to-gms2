/// @desc

camera[0] += keyboard_check(ord("D")) - keyboard_check(ord("A"));
camera[1] += keyboard_check(ord("W")) - keyboard_check(ord("S"));

x += keyboard_check(vk_right) - keyboard_check(vk_left);
y += keyboard_check(vk_up) - keyboard_check(vk_down);

zrot += keyboard_check(ord("E")) - keyboard_check(ord("Q"));

mattran = matrix_build(x,y,z, 0,0,zrot, 1,1,1);

camera[3] = (0-camera[0]);
camera[4] = (0-camera[1]);
camera[5] = (8-camera[2]);
var d = point_distance_3d(0,0,0, camera[3], camera[4], camera[5]);
camera[3] /= d;
camera[4] /= d;
camera[5] /= d;

matview = matrix_build_lookat(
	camera[0], camera[1], camera[2], 
	camera[0]+camera[3], camera[1]+camera[4], camera[2]+camera[5], 
	0, 0, 1);

/// @description 

var _tutlast = tutorialindex;

if ( keyboard_check_pressed(ord("1")) ) {tutorialindex = 1;}
if ( keyboard_check_pressed(ord("2")) ) {tutorialindex = 2;}
if ( keyboard_check_pressed(ord("3")) ) {tutorialindex = 3;}
if ( keyboard_check_pressed(ord("4")) ) {tutorialindex = 4;}

if (_tutlast != tutorialindex)
{
	instance_destroy(tutorialinst);
	tutorialinst = instance_create_depth(0,0,0, tutorials[tutorialindex]);
	
	show_debug_message("Tutorial " + string(tutorialindex));
}

/// @description 

var _tutlast = tutorialindex;

for (var i = 1; i < array_length(tutorials); i++)
{
	if ( keyboard_check_pressed(ord("0")+i) ) 
	{
		tutorialindex = i;
	}	
}

if (_tutlast != tutorialindex)
{
	instance_destroy(tutorialinst);
	tutorialinst = instance_create_depth(0,0,0, tutorials[tutorialindex]);
	
	show_debug_message("Tutorial " + string(tutorialindex));
}

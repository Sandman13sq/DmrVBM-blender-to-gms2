/// @desc Navigation

if ( keyboard_check_pressed(ord("0")) )
{
	showextras ^= 1;
	ChangeTutorial(tutorialindex, showextras);
}

// Change Tutorial
if (!showextras)
{
	if ( keyboard_check_pressed(ord("1")) ) {ChangeTutorial(1, false);}
	if ( keyboard_check_pressed(ord("2")) ) {ChangeTutorial(2, false);}
	if ( keyboard_check_pressed(ord("3")) ) {ChangeTutorial(3, false);}
	if ( keyboard_check_pressed(ord("4")) ) {ChangeTutorial(4, false);}
	if ( keyboard_check_pressed(ord("5")) ) {ChangeTutorial(5, false);}
}
// Change Extra
else
{
	if ( keyboard_check_pressed(ord("1")) ) {ChangeTutorial(1, true);}
	if ( keyboard_check_pressed(ord("2")) ) {ChangeTutorial(2, true);}
	if ( keyboard_check_pressed(ord("3")) ) {ChangeTutorial(3, true);}
	if ( keyboard_check_pressed(ord("4")) ) {ChangeTutorial(4, true);}
	if ( keyboard_check_pressed(ord("5")) ) {ChangeTutorial(5, true);}
}


if ( keyboard_check(vk_tab) && keyboard_check_pressed(ord("T")) ) {ChangeTutorial(6);}
/// @desc

#macro DIRPATH working_directory
#macro DEBUG:DIRPATH "D:/GitHub/DmrVBC/vbc_demo/datafiles/"
//#macro DEBUG:DIRPATH "C:/Users/Dreamer/Documents/GitHub/DmrVBC/vbc_demo/datafiles/"

event_user(0);

display_set_gui_maximize(1, 1);
draw_set_font(fnt_default);

room_goto(rm_modeltest);

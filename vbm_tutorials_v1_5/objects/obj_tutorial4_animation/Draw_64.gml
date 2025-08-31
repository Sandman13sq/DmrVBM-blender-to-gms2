/// @desc Draw camera position
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _ystart = 96;
var xx = 16, yy = _ystart, ysep = 16;

// Left Info
draw_text(xx, yy, "Use the arrow keys to rotate model"); yy += ysep;
draw_text(xx, yy, "Hold SHIFT w/ arrow keys to rotate camera"); yy += ysep;
draw_text(xx, yy, "Press \"<\",\">\" to navigate meshes"); yy += ysep;
draw_text(xx, yy, "Press ? to toggle mesh visibility"); yy += ysep;
draw_text(xx, yy, "Press | to toggle weight visibility"); yy += ysep;
draw_text(xx, yy, "Press \"[\",\"]\" to highlight bone"); yy += ysep;
draw_text(xx, yy, "Press \"-\",\"+\" to navigate animations"); yy += ysep;
yy += ysep;
draw_text(xx, yy, "Camera Position: " + string(view_position)); yy += ysep;
draw_text(xx, yy, "Camera Rotation: " + string(view_euler)); yy += ysep;
yy += ysep;
draw_text(xx, yy, "Model Position: " + string(model_location)); yy += ysep;
draw_text(xx, yy, "Model Rotation: " + string(model_euler)); yy += ysep;
yy += ysep;
draw_text(xx, yy, "Bone Count: " + string(VBM_Model_GetBoneCount(model))); yy += ysep;
draw_text(xx, yy, "Bone Select: ["+string(bone_select)+"] " + string(VBM_Model_GetBoneName(model, bone_select))); yy += ysep;
yy += ysep;

// Mesh on right
xx = surface_get_width(application_surface)-180;
yy = _ystart;
draw_text(xx, yy, "Mesh Count: " + string(VBM_Model_GetMeshdefCount(model))); yy += ysep;
for (var i = 0; i < VBM_Model_GetMeshdefCount(model); i++) {
	if ( mesh_select == i ) {draw_set_color(c_orange);}
	else if ( mesh_visible_layermask & (1<<i) ) {draw_set_color(c_white);}
	else {draw_set_color(c_gray);}
	draw_text(xx, yy, "  ["+string(i)+"]: " + string(VBM_Model_GetMeshdefName(model, i))); yy += ysep;
}
draw_set_color(c_white);
yy += ysep;

// Animation stats
draw_text(xx, yy, "Anim Count: " + string(VBM_Model_GetAnimationCount(model)));
yy += ysep;
for (var i = 0; i < VBM_Model_GetAnimationCount(model); i++) {
	if ( animation_index == i ) {draw_set_color(c_orange);}
	else {draw_set_color(c_white);}
	draw_text(xx, yy, "  ["+string(i)+"]: " + string(VBM_Model_GetAnimationName(model, i))); yy += ysep;
}
draw_set_color(c_white);
draw_healthbar(
	xx, yy, xx+160, yy+10, 
	100*VBM_ModelAnimation_EvaluateFramePosition(animation, playback_frame), 
	0xFF223300,0xFF7777FF,0xFF7777FF,0,1,1
);
yy += ysep;
draw_text(xx, yy, 
	"Frame: " + string_format(VBM_ModelAnimation_EvaluateFrame(animation, playback_frame), 4, 0) + "/" + 
	string_format(VBM_Model_GetAnimationDuration(model, animation_index), 4, 0)
);
yy += ysep;
draw_text(xx, yy, 
	"Blend: " + string_format(animation_blend, 2, 2) + " (Spd=" + string_format(1.0/animation_blend_time, 1, 2) + ")"
);
yy += ysep;

// Animation Props
var n = VBM_ModelAnimation_GetPropertyCount(animation);
var _offset = VBM_ModelAnimation_GetPropertyOffset(animation);
var _numchannels;
var _curvename;
for ( var prop_index = 0; prop_index < n; prop_index++ ) {
	_curvename = VBM_ModelAnimation_GetCurveName(animation, _offset+prop_index);
	_numchannels = VBM_ModelAnimation_GetCurveSize(animation, _offset+prop_index);
	for (var c = 0; c < _numchannels; c++) {
		draw_text(xx, yy,  _curvename+"["+string(c)+"]: ");
		draw_text(xx+100, yy, string_format(animation_props[$ _curvename][c], 4, 2));
		yy += ysep;
	}
}

draw_set_color(c_white);

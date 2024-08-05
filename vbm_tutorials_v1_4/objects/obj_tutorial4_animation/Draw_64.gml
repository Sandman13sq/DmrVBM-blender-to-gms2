/// @desc Draw camera position

draw_set_halign(fa_left);
draw_set_valign(fa_top);

var yy = 100, ysep = 16;
draw_text(16, yy, "Use the arrow keys to rotate model"); yy += ysep;
draw_text(16, yy, "Hold SHIFT and use arrow keys to rotate camera"); yy += ysep;
draw_text(16, yy, "Press </> to navigate meshes"); yy += ysep;
draw_text(16, yy, "Press ? to toggle mesh visibility"); yy += ysep;
yy += ysep;
draw_text(16, yy, "Camera Position: " + string(viewposition)); yy += ysep;
draw_text(16, yy, "Camera Rotation: " + string(viewhrot)); yy += ysep;
yy += ysep;
draw_text(16, yy, "Model Position: " + string([x,y,0])); yy += ysep;
draw_text(16, yy, "Model Rotation: " + string(zrot)); yy += ysep;
yy += ysep;
draw_text(16, yy, "Animation: " + string(VBM_Model_GetAnimationName(model, 0))); yy += ysep;
draw_text(16, yy, "Frame: " + string_format(playback_frame, 4, 0) + "/" + string_format(VBM_Model_GetAnimationDuration(model, 0), 4, 0)); yy += ysep;
yy += ysep;
draw_text(16, yy, "Bone Count: " + string(VBM_Model_GetBoneCount(model))); yy += ysep;
draw_text(16, yy, "Bone Select: ["+string(bone_select)+"] " + string(VBM_Model_GetBoneName(model, bone_select))); yy += ysep;
yy += ysep;
draw_text(16, yy, "Mesh Count: " + string(VBM_Model_GetMeshCount(model))); yy += ysep;
for (var i = 0; i < VBM_Model_GetMeshCount(model); i++) {
	if ( mesh_select == i ) {
		draw_set_color(c_orange);
	}
	else if ( mesh_hide_bits & (1<<i) ) {
		draw_set_color(c_gray);
	}
	else {
		draw_set_color(c_white);
	}
	draw_text(16, yy, "["+string(i)+"]: " + string(VBM_Model_GetMeshName(model, i))); yy += ysep;
}
draw_set_color(c_white);

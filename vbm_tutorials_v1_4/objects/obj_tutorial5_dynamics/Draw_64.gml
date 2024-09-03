/// @desc Draw camera position

draw_set_halign(fa_left);
draw_set_valign(fa_top);

var xx = 0;
var yy = 100, ysep = 16;
var ww = display_get_gui_width();
var hh = display_get_gui_height();

draw_text(16, yy, "Use the arrow keys to rotate model"); yy += ysep;
draw_text(16, yy, "Hold SHIFT and use arrow keys to rotate camera"); yy += ysep;
draw_text(16, yy, "Press \"<\",\">\" to navigate meshes"); yy += ysep;
draw_text(16, yy, "Press ? to toggle mesh visibility"); yy += ysep;
draw_text(16, yy, "Press \"[\",\"]\" to highlight bone"); yy += ysep;
draw_text(16, yy, "Press \"-\",\"+\" to navigate animations"); yy += ysep;
yy += ysep;
draw_text(16, yy, "Camera Position: " + string(viewposition)); yy += ysep;
draw_text(16, yy, "Camera Rotation: " + string(viewhrot)); yy += ysep;
yy += ysep;
draw_text(16, yy, "Model Position: " + string([x,y,0])); yy += ysep;
draw_text(16, yy, "Model Rotation: " + string(zrot)); yy += ysep;
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

xx = 16;
yy = hh - 64;
for (var i = 0; i < VBM_Animator_GetLayerCount(animator); i++) {
	draw_healthbar(xx, yy, ww-xx, yy+20, 100.0*(VBM_Animator_GetLayerAnimationPosition(animator, i) mod 1.0), 0, c_green, c_green, 0, 1, 1);
	draw_text(xx+4, yy+4, 
		"Layer["+string(i)+"]: " + 
		VBM_Animator_GetLayerAnimationKey(animator, i) + " | " +
		string(VBM_Animator_GetLayerAnimationFrame(animator, i))
	);
	yy += 20;
}
draw_text(xx, yy, "Exec Time: " + string(benchmark_net[0] / benchmark_count));
draw_text(xx+200, yy, "Transforms: " + string(benchmark_net[1] / benchmark_count));
draw_text(xx+400, yy, "Matrices: " + string(benchmark_net[2] / benchmark_count));
draw_text(xx+600, yy, (animator.layers[0].animation.animcurve)? "Curves": "Array");

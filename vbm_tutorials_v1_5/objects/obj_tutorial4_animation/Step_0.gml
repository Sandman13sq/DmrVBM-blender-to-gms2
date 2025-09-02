/// @desc Tutorial Controls

// Animation Controls ----------------------------------------
mesh_flash = max(0.0, mesh_flash - 0.05);

// Navigate animation
if ( keyboard_check_pressed(189) ) {	// "+"
	animation_index = (animation_index==0)? VBM_Model_GetAnimationCount(model)-1: animation_index-1;
	animation = VBM_Model_GetAnimation(model, animation_index);
	animation_blend = 0.0;
}
if ( keyboard_check_pressed(187) ) {	// "-"
	animation_index = (animation_index+1) mod VBM_Model_GetAnimationCount(model);
	animation = VBM_Model_GetAnimation(model, animation_index);
	animation_blend = 0.0;
}

// Navigate Meshes
if ( keyboard_check_pressed(188) ) {	// "<"
	mesh_select = (mesh_select == 0)? VBM_Model_GetMeshdefCount(model)-1: mesh_select-1;
	mesh_flash = 1.0;
}
if ( keyboard_check_pressed(190) ) {	// ">"
	mesh_select = (mesh_select+1) mod VBM_Model_GetMeshdefCount(model);
	mesh_flash = 1.0;
}
if ( keyboard_check_pressed(191) ) {	// "?"
	mesh_visible_layermask ^= (1<<mesh_select);
}

// Navigate bones weight index
if ( keyboard_check_pressed(220) )	{	// "|\"
	show_weights ^= 1;
}
if ( keyboard_check_pressed(0xDB) ) {	// "["
	bone_select = (bone_select==0)? VBM_Model_GetBoneCount(model)-1: bone_select-1;
}
if ( keyboard_check_pressed(0xDD) ) {	// "]"
	bone_select = (bone_select+1) mod VBM_Model_GetBoneCount(model);
}

// Update Animation ...................................................

// Increment playback frame
playback_frame += playback_speed;
animation_blend = min(1.0, animation_blend+1.0/animation_blend_time);

// Sample animation index at <frame> and store values into <bone_matrices>
/*
	Animation Process Order:
		Animation - Sample transformations from animation frame
		Matrices - Convert transformations to Model-space matrices
		Swing (Optional) - Process swing bone particles for dynamic animation
		Skinning - Convert Model-space matrices to Inverse Bind-space matrices for vertex skinning
*/
if ( !is_undefined(animation) ) {
	// Sample bone transforms from animation
	VBM_Model_EvaluateAnimationTransforms_Blend(model, animation, playback_frame, animation_blend, bone_transforms, bone_transforms);
	// Convert transforms into Model-space matrices
	VBM_Model_EvaluateTransformMatrices(model, bone_transforms, bone_matrices);
	// Update and apply swing particle transformations
	VBM_Model_EvaluateSwingMatrices(model, mattran, bone_particles, bone_matrices);
	// Convert Model-space transforms into Inverse-bind space for skinning
	VBM_Model_EvaluateSkinningMatrices(model, bone_matrices, bone_skinning);
	
	// Non-bone properties
	VBM_ModelAnimation_SampleProps_Struct(animation, playback_frame, animation_props);
}


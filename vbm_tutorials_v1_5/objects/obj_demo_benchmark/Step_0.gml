/// @desc Process Model

if ( keyboard_check_pressed(ord("B")) ) {
	for (var i = 0; i < array_length(benchmark); i++) {
		benchmark[i] = [0,0,0,0];
	}
}

model_euler[2] += 5.0*(keyboard_check(vk_right) - keyboard_check(vk_left));

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

animation_time_factor *= 1.0+0.1*(mouse_wheel_up()-mouse_wheel_down());

// Update Animation
animation = VBM_Model_GetAnimation(model, animation_index);

benchmark[Benchmark.total][0] = get_timer();

benchmark[Benchmark.animation][0] = get_timer();
VBM_Model_EvaluateAnimationTransforms(model, animation, animation_frame, bone_transforms);
benchmark[Benchmark.animation][0] = get_timer() - benchmark[Benchmark.animation][0];

benchmark[Benchmark.transform][0] = get_timer();
VBM_Model_EvaluateTransformMatrices(model, bone_transforms, bone_matrices);
benchmark[Benchmark.transform][0] = get_timer() - benchmark[Benchmark.transform][0];

benchmark[Benchmark.swing][0] = get_timer();
VBM_Model_EvaluateSwingMatrices(model, mtran, bone_particles, bone_matrices, animation_time_factor);
benchmark[Benchmark.swing][0] = get_timer() - benchmark[Benchmark.swing][0];

benchmark[Benchmark.skinning][0] = get_timer();
VBM_Model_EvaluateSkinningMatrices(model, bone_matrices, bone_skinning);
benchmark[Benchmark.skinning][0] = get_timer() - benchmark[Benchmark.skinning][0];

benchmark[Benchmark.total][0] = get_timer() - benchmark[Benchmark.total][0];

if ( keyboard_check_pressed(vk_numpad7) ) {
	var t, times = array_create(16);
	for (var i = 0; i < 16; i++) {
		t = get_timer();
		repeat(1000) {
			VBM_Model_EvaluateSkinningMatrices(model, bone_matrices, bone_skinning);
		}
		times[i] = get_timer() - t;
		
	}
	show_debug_message("Skinning: "+string(times)+" µs");
}


animation_frame += 1;



// Update Benchmark --------------------------------------------------
for (var i = 0; i < array_length(benchmark); i++) {
	benchmark[i][3] += 1;	// Iterations
	benchmark[i][2] += benchmark[i][0];	// Sum
	benchmark[i][1] = benchmark[i][2] / benchmark[i][3];	// Average
}


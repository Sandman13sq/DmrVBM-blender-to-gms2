/// @desc Update Entity

var _movekeys = [ord("D"), ord("W"), ord("A"), ord("S")];	// Right, Up, Left, Down

// Process Entities -----------------------------------------------
var e;
var n = array_length(entitylist);
for (var e_index = 0; e_index < n; e_index++) {
	e = entitylist[e_index];
	if ( e == 0 ) {continue;}
	
	var _animation_key_last = e.animation_key;
	
	// Process Entity Type
	if ( e.type == "player" ) {
		var _xlev = (keyboard_check(_movekeys[0]) - keyboard_check(_movekeys[2]));
		var _ylev = -(keyboard_check(_movekeys[1]) - keyboard_check(_movekeys[3]));
		var _moving = (_xlev != 0) || (_ylev != 0);
		
		if ( _moving ) {
			var _spd = 0.1;
			var _acc = 0.01;
			var _dir = darctan2(_ylev, _xlev);
			var _mag = point_distance_3d(0,0,0, e.velocity[0], e.velocity[1], e.velocity[2]);
			
			_mag = min(_mag+_acc, _spd);
			
			e.euler[2] += angle_difference(_dir, e.euler[2])/10;
			_dir = e.euler[2];
			
			e.velocity[0] = _mag * dcos(_dir);
			e.velocity[1] = -_mag * dsin(_dir);
			e.animation_key = "run";
		}
		else {
			var _dec = 0.01;
			for (var i = 0; i < 3; i++) {
				e.velocity[i] = (e.velocity[i] > 0.0)? max(e.velocity[i]-_dec, 0): min(e.velocity[i]+_dec, 0);
			}
			e.animation_key = "idle";
		}
	}
	
	// Movement
	e.location[0] += e.velocity[0];
	e.location[1] += e.velocity[1];
	e.location[2] += e.velocity[2];
	
	// Update Animation
	if ( e.model != 0 ) {
		if ( _animation_key_last != e.animation_key ) {
			e.animation_frame = 0.0;
			e.animation_blend = 0.0;
		}
		else {
			e.animation_frame += 1.0;
			e.animation_blend = min(e.animation_blend+0.1, 1.0);
		}
		
		var _animation = VBM_Model_FindAnimation(e.model, e.animation_key);
		if ( _animation ) {
			var m = matrix_build(
				e.location[0], e.location[1], e.location[2], 
				e.euler[0], e.euler[1], e.euler[2],
				1,1,1
			);
			
			VBM_Model_EvaluateAnimationTransforms_Blend(
				e.model, 
				_animation, 
				e.animation_frame, 
				e.animation_blend, 
				e.bone_transforms, 
				e.bone_transforms
			);
			VBM_Model_EvaluateTransformMatrices(e.model, e.bone_transforms, e.bone_matrices);
			VBM_Model_EvaluateSwingMatrices(e.model, m, e.bone_particles, e.bone_matrices);
			VBM_Model_EvaluateSkinningMatrices(e.model, e.bone_matrices, e.bone_skinning);
		}
	}
	
	e.matrix = matrix_build(
		e.location[0], e.location[1], e.location[2], 
		e.euler[0], e.euler[1], e.euler[2],
		1,1,1
	);
	
	// Shadow
	var intersection = [0,0,0];
	if ( VBM_ModelPrism_CastRay(
		model_level.prisms[0], 
		matrix_build_identity(), 
		e.location[0], e.location[1], e.location[2],
		0,0,-1,
		0,
		1000,
		intersection,
		e.shadw_normal
	) != -1 ) {
		e.shadow_z = intersection[2];
	}
}

// Camera Update -------------------------------------------------
view_distance_intermediate += mouse_wheel_down()-mouse_wheel_up();
view_distance_intermediate = clamp(view_distance_intermediate, view_distance_limits[0], view_distance_limits[1]);
view_distance = lerp(view_distance, view_distance_intermediate, 0.1);

view_location_intermediate[0] = player.location[0] + player.velocity[0] + dcos(player.euler[2]) * 0.2;
view_location_intermediate[1] = player.location[1] + player.velocity[1] - dsin(player.euler[2]) * 0.2;
view_location_intermediate[2] = player.location[2];
for (var i = 0; i < 3; i++) {
	view_location[i] = lerp(view_location[i], view_location_intermediate[i], 0.1);
}

view_euler_intermediate[0] = lerp(45, 0, 1/(view_distance-view_distance_limits[0]+2));
view_euler_intermediate[2] += 3*(keyboard_check(ord("E")) - keyboard_check(ord("Q")));
for (var i = 0; i < 3; i++) {
	view_euler[i] = lerp(view_euler[i], view_euler_intermediate[i], 0.1);	
}


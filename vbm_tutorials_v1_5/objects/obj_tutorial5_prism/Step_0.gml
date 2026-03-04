/// @desc Playsim

var input_right = keyboard_check(ord("D"));
var input_up = keyboard_check(ord("W"));
var input_left = keyboard_check(ord("A"));
var input_down = keyboard_check(ord("S"));

// Entity Loop
for (var entity_index = 0; entity_index < entity_count; entity_index++) {
	var e = entity_list[entity_index];
	
	// Poppie -----------------------------------------------------------
	if ( e.entity_type == "POPPIE" ) {
		var xlev = input_right-input_left;
		var ylev = input_up-input_down;
		
		if ( xlev != 0 || ylev != 0 ) {
			var movevec = [view_forward[0], view_forward[1], 0];
			var dir = darctan2(movevec[1], movevec[0]) + darctan2(ylev, xlev) - 90;
			var spd = 0.1;
			
			if ( abs(angle_difference(e.euler[2], dir)) >= 150 ) {e.euler[2] = dir;}
			e.euler[2] = approach_angle(e.euler[2], dir, 5);
			movevec[0] = dcos(e.euler[2]);
			movevec[1] = dsin(e.euler[2]);
			
			e.velocity[0] = spd*movevec[0];
			e.velocity[1] = spd*movevec[1];
			if ( e.animation_name != "run" ) {e.animation_blend = 0.0;}
			e.animation_name = "run";
		}
		else {
			e.velocity[0] = 0;
			e.velocity[1] = 0;
			if ( e.animation_name != "idle" ) {e.animation_blend = 0.0;}
			e.animation_name = "idle";
		}
		
		e.animation_frame += 1.0;
	}
	
	// Movement
	e.x += e.velocity[0];
	e.y += e.velocity[1];
	e.z += e.velocity[2];
	
	var ground_point = [0,0,0];
	var ground_normal = [0,0,0];
	var t = VBM_Model_CastRay(
		model_level, 
		matrix_build_identity(), 
		e.x, e.y, e.z,
		0,0,-1,
		-1,
		0, 
		VBM_LAYERMASKALL, VBM_LAYERMASKALL,
		ground_point,
		ground_normal
	);
	if ( t != undefined ) {
		e.z = ground_point[2];
		e.velocity[2] = 0;
	}
	else {
		e.velocity[2] += -0.01;
	}
	
	e.matrix = matrix_build(e.x, e.y, e.z, e.euler[0],e.euler[1],-e.euler[2], 1,1,1);
	e.animation_blend = min(e.animation_blend+0.04, 1.0);
	
	if ( e.model && e.animation_name != "" ) {
		var animation = VBM_Model_FindAnimation(e.model, e.animation_name);
		if ( animation ) {
			if ( array_length(e.pose_skinning) == 0 ) {
				e.pose_transforms = vbm_transform_identity_array_1d(200);
				e.pose_particles = vbm_boneparticle_array_1d(200);
				e.pose_matrices = vbm_mat4_identity_array_1d(200);
				e.pose_skinning = vbm_mat4_identity_array_1d(200);
			}
			VBM_Model_EvaluateAnimationTransforms_Blend(e.model, animation, e.animation_frame, e.animation_blend, e.pose_transforms, e.pose_transforms);
			VBM_Model_EvaluateTransformMatrices(e.model, e.pose_transforms, e.pose_matrices);
			VBM_Model_EvaluateSwingMatrices(e.model, e.matrix, e.pose_particles, e.pose_matrices, 0.5);
			VBM_Model_EvaluateSkinningMatrices(e.model, e.pose_matrices, e.pose_skinning);
		}
		break;
	}
}

// Follow player
view_position_target = [entity_list[0].x, entity_list[0].y, entity_list[0].z+1.0];
view_position_intermediate[0] = lerp(view_position_intermediate[0], view_position_target[0], 0.2);
view_position_intermediate[1] = lerp(view_position_intermediate[1], view_position_target[1], 0.2);
view_position_intermediate[2] = lerp(view_position_intermediate[2], view_position_target[2], 0.2);
view_position[0] = lerp(view_position[0], view_position_intermediate[0], 0.2);
view_position[1] = lerp(view_position[1], view_position_intermediate[1], 0.2);
view_position[2] = lerp(view_position[2], view_position_intermediate[2], 0.2);

// Camera Controls
var mlev = mouse_wheel_up()-mouse_wheel_down();
view_distance_target = clamp(view_distance_target-mlev, view_distance_bounds[0], view_distance_bounds[1]);
view_distance = lerp(view_distance, view_distance_target, 0.1);

view_rotation_target += 2*(keyboard_check(ord("E")) - keyboard_check(ord("Q")));
view_euler[2] = lerp(view_euler[2], view_rotation_target, 0.1);

var amt = (view_distance-view_distance_bounds[0]) / (view_distance_bounds[1]-view_distance_bounds[0]);
view_euler[0] = lerp(view_angle_bounds[1], view_angle_bounds[0], power(amt, 0.1));

view_forward[0] = 0;
view_forward[1] = dsin(view_euler[0]);
view_forward[2] = -dcos(view_euler[0]);
view_forward = matrix_transform_vertex(
	matrix_build(0,0,0,0,0,view_euler[2],1,1,1), 
	view_forward[0], view_forward[1], view_forward[2]
);

// Matrices
var projection_yflip = (os_type==os_windows)? -1: 1;
matproj = matrix_build_projection_perspective_fov(
	fieldofview * -projection_yflip,
	window_get_width()/window_get_height() * projection_yflip,
	znear, 
	zfar
);

matview = matrix_build_lookat(
	view_position[0]-view_forward[0]*view_distance,
	view_position[1]-view_forward[1]*view_distance,
	view_position[2]-view_forward[2]*view_distance,
	view_position[0],
	view_position[1],
	view_position[2],
	0,0,1
);
mataxes = matrix_inverse(matview);


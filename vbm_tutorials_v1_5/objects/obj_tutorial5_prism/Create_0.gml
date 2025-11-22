/// @desc Initialize

function approach_angle(value, target, delta) {
    while (target-value < 0 ) {value -= 360;} 
    while (target-value > 180) {value += 360;}
    return (value < target)?
        (((value+delta) > target)? target: (value+delta)):
        (((value-delta) < target)? target: (value-delta));
}

// *Camera ----------------------------------------------
view_position = [0, 0, 1];	// Location to point the camera at
view_forward = [0, 0, 0];
view_euler = [0,0,0];

view_position_target = [0,0,1];
view_position_intermediate = [0,0,1];
view_rotation_target = 0;
view_angle_bounds = [45, 70];	// [Far : Close]
view_distance = 10;	// Distance from camera position
view_distance_target = view_distance;
view_distance_bounds = [2, 32];

fieldofview = 60;	// Angle of vision
znear = 0.1;	// Clipping distance for close triangles
zfar = 100;	// Clipping distance for far triangles

matproj = matrix_build_identity();	// Matrices are updated in Step Event
matview = matrix_build_identity();
mattran = matrix_build_identity();
mataxes = matrix_build_identity();	// View matrix inverted = view axes

model_poppie = VBM_Model_Create();
VBM_Model_Open(model_poppie, "tutorial5_poppie.vbm");

model_level = VBM_Model_Create();
VBM_Model_Open(model_level, "tutorial5_level.vbm", VBM_OPENFLAGS.PRINTDEBUG);

bone_transforms = vbm_transform_identity_array_1d(VBM_BONELIMIT);	// Transforms are sampled from animation
bone_particles = vbm_boneparticle_array_1d(VBM_BONELIMIT);	// Particles represent swing bone transformations
bone_matrices = vbm_mat4_identity_array_1d(VBM_BONELIMIT);	// Model-Space Matrices for each bone
bone_skinning = vbm_mat4_identity_array_1d(VBM_BONELIMIT);	// Vertex-Space Matrices to send to shader	

// *Shader Uniforms
u_world_axes = shader_get_uniform(shd_tutorial5_world, "u_axes");	// View axes
u_entity_axes = shader_get_uniform(shd_tutorial5_entity, "u_axes");	// View axes
u_entity_bonematrices = shader_get_uniform(shd_tutorial5_entity, "u_bonematrices");	// For skinning matrices

// Playsim
function Entity() constructor {
	x = 0;
	y = 0;
	z = 0;
	velocity = [0,0,0];
	euler = [0,0,0];
	matrix = matrix_build_identity();
	pose_transforms = [];
	pose_matrices = [];
	pose_particles = [];
	pose_skinning = [];
	model = undefined;
	animation_frame = 0;
	animation_name = "";
	animation_blend = 0;
	entity_type = "";
};

entity_count = 64;
entity_list = array_create(entity_count);
for (var e = 0; e < entity_count; e++) {
	entity_list[e] = new Entity();
	if ( e > 0 ) {
		entity_list[e].entity_type = choose("APPLE", "BALL", "PUFF");
		entity_list[e].x = irandom_range(-30, 30);
		entity_list[e].y = irandom_range(-30, 30);
		entity_list[e].z = irandom_range(0, 30);
	}
}

entity_list[0].entity_type = "POPPIE";
entity_list[0].model = model_poppie;
entity_list[0].animation_name = "idle";

event_perform(ev_step, 0); // Force Step Update before first draw call
/// @desc

px = 0;	// Particle Current
py = 0;
pz = 0;

lx = 0;	// Particle Last
ly = 0;
lz = 0;

vx = 0;	// Velocity
vy = 0;
vz = 0;

dx = 0;	// Particle Direction
dy = 0;
dz = 0;

gx = 0;	// Goal Position
gy = 0;
gz = 1;

fx = 0;	// Goal direction
fy = 0;
fz = 0;

rx = 0;	// Root Position
ry = 0;
rz = 0;

cx = 0;	// Particle x Goal
cy = 0;
cz = 0;

hx = 0;	// Half-vector test
hy = 0;
hz = 0;

qx = 0;
qy = 0;
qz = 0;

bone_length = 1.3;
plength = 0;
limit = 0.7;
limit_intermediate = limit;

dot_result = 0;
dot_cross = 0;
time_factor = 1.0;

// Scene ------------------------------------------
matview = matrix_build_identity();
matproj = matrix_build_identity();
mattran = matrix_build_identity();

vb = vertex_create_buffer();
format = VBM_FormatBuild(VBM_FORMAT_NATIVE);

event_perform(ev_step, ev_step_normal);


/// @desc Process

var d;

if ( keyboard_check_pressed(vk_space) ) {
	px = 0;
	py = 0;
	pz = 0;
	lx = 0;
	ly = 0;
	lz = 0;
}

if ( keyboard_check_pressed(ord("X")) ) {time_factor = min(time_factor*2.0, 1.0);}
if ( keyboard_check_pressed(ord("Z")) ) {time_factor = max(time_factor/2.0, 0.0);}

if ( keyboard_check_pressed(ord("F")) ) {py = 0; ly = 0;}

if ( keyboard_check_pressed(ord("G")) ) {
	d = 1;
	px += gx + random_range(-d, d);
	py += gy + random_range(-d, d);
	pz += gz + random_range(-d, d);
}

if ( px==0 && py==0 && pz==0 ) {
	d = 0.1;
	px += gx + random_range(-d, d);
	py += gy + random_range(-d, d);
	pz += gz + random_range(-d, d);
}

// Velocity = current - last
vx = px - lx;
vy = py - ly;
vz = pz - lz;
vz -= 0.01;

// Update last
lx = lerp(lx, px, time_factor);
ly = lerp(ly, py, time_factor);
lz = lerp(lz, pz, time_factor);

// Current = current + velocity + acceleration * dt*dt
px += vx * time_factor;
py += vy * time_factor;
pz += vz * time_factor;

// Constraints ---------------------------------------

// Distance Constraint
plength = point_distance_3d(0,0,0, px-rx, py-ry, pz-rz);
dx = (px-rx) / plength;
dy = (py-ry) / plength;
dz = (pz-rz) / plength;

px = rx + dx * bone_length;
py = ry + dy * bone_length;
pz = rz + dz * bone_length;
plength = bone_length;

// Rotation Constraint
d = point_distance_3d(0,0,0, gx-rx, gy-ry, gz-rz);
fx = (gx-rx) / d;
fy = (gy-ry) / d;
fz = (gz-rz) / d;

dot_result = dot_product_3d_normalized(dx,dy,dz, fx,fy,fz);

// Early guess if limit needs to be checked
if ( (dot_result*0.5+0.5) < limit*1.2 ) 
{
	//show_debug_message([dot_result, limit*2-1]);
	vx = (dy*fz - dz*fy);	// Up Axis = Forward x Current
	vy = (dz*fx - dx*fz);
	vz = (dx*fy - dy*fx);
	
	cx = (fy*vz - fz*vy);	// Half Axis = Up x Forward
	cy = (fz*vx - fx*vz);
	cz = (fx*vy - fy*vx);
	d = point_distance_3d(0,0,0, cx,cy,cz);
	cx /= d; cy /= d; cz /= d;
	
	// Source: https://github.com/blender/blender/blob/cb22938fe942b994541b3e80715ef8042d5320c7/source/blender/blenlib/intern/math_vector.cc#L58
	var cosom, sinom, omega, w0, w1;
	var fac = limit*2.0-1.0;
	cosom = dot_product_3d(fx,fy,fz, cx,cy,cz);
	omega = arccos(cosom);
	sinom = sin(omega);
	w0 = sin( (1.0-fac)*omega ) / sinom;
	w1 = sin( fac*omega ) / sinom;
	
	vx = cx*w0 + fx*w1;
	vy = cy*w0 + fy*w1;
	vz = cz*w0 + fz*w1;
	
	hx = vx; hy = vy; hz = vz;
	
	d = dot_product_3d_normalized(fx,fy,fz, vx,vy,vz);
	//show_debug_message(d);
	if ( dot_result <= d ) 
	{
		d = point_distance_3d(0,0,0, vx,vy,vz);
		px = rx + (vx/d) * plength;
		py = ry + (vy/d) * plength;
		pz = rz + (vz/d) * plength;
		lx = px; ly = py; lz = pz;	// <- Disable for ping-pong ding-dong
		
		qx = px; qy = py; qz = pz;	
	}
}

vx = (dy*fz - dz*fy);	// Up Axis = Forward x Current
vy = (dz*fx - dx*fz);
vz = (dx*fy - dy*fx);

cx = (fy*vz - fz*vy);	// Right Axis = Up x Forward
cy = (fz*vx - fx*vz);
cz = (fx*vy - fy*vx);
d = point_distance_3d(0,0,0, cx,cy,cz);
cx /= d; cy /= d; cz /= d;

// Source: https://github.com/blender/blender/blob/cb22938fe942b994541b3e80715ef8042d5320c7/source/blender/blenlib/intern/math_vector.cc#L58
var cosom, sinom, omega, w0, w1;
var fac = limit*2.0-1.0;
cosom = dot_product_3d_normalized(fx,fy,fz, cx,cy,cz);

omega = arccos(cosom);
sinom = sin(omega);
w0 = sin( (1.0-fac)*omega ) / sinom;
w1 = sin( fac*omega ) / sinom;

hx = cx*w0 + fx*w1;
hy = cy*w0 + fy*w1;
hz = cz*w0 + fz*w1;

d = point_distance_3d(0,0,0, hx,hy,hz) / plength;
hx /= d; hy /= d; hz /= d;

dot_cross = dot_product_3d_normalized(hx,hy,hz, fx,fy,fz);

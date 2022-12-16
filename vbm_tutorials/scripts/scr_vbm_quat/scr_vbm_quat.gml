/*
	References:
		Quat Operations: https://www.euclideanspace.com/maths/algebra/realNormedAlgebra/quaternions/code/index.htm
		Extra functions: https://github.com/JujuAdams/basic-quaternions
		Matrix to Quat: https://d3cw3dd2w32x2b.cloudfront.net/wp-content/uploads/2015/01/matrix-to-quat.pdf
*/

// Quaternions use the form <w,x,y,z>
function Quat() {return [1.0, 0.0, 0.0, 0.00001];}

function QuatBuild(w, x, y, z) {return [x, y, z, w];}

function QuatArray1d(size)
{
	size *= 4;
	var q = Quat();
	var out = array_create(size);
	for (var i = 0; i < size; i += 4) {out[i] = 1.0;}
	return out;
}

function QuatArray2d(size)
{
	var q = Quat();
	var out = array_create(size);
	for (var i = 0; i < size; i += 4) {out[i] = [ q[0], q[1], q[2], q[3] ];}
	return out;
}

// Operations ========================================================

function QuatConjugate(q)
{
	q[@ 1] *= -1;
	q[@ 2] *= -1;
	q[@ 3] *= -1;
	return q;
}

function QuatConjugated(q)
{
	return [q[0], -q[1], -q[2], -q[3]];
}

function QuatNormalize(q)
{
	var n = sqrt(q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3]);
	q[@ 0] /= n;
	q[@ 1] /= n;
	q[@ 2] /= n;
	q[@ 3] /= n;
	return q;
}

function QuatNormalized(q)
{
	var n = sqrt(q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3]);
	return [ q[0]/n, q[1]/n, q[2]/n, q[3]/n ];
}

function QuatScale(q, scale)
{
	q[@ 0] *= scale;
	q[@ 1] *= scale;
	q[@ 2] *= scale;
	q[@ 3] *= scale;
	return q;
}

function QuatScaled(q, scale)
{
	return [q[0] * scale, q[1] * scale, q[2] * scale, q[3] * scale];
}

// Interpolates between two quaternions
function QuatSlerp(q1, q2, amt)
{
	// quaternion to return
	var out = Quat();
	
	var q1_0 = q1[0], q1_1 = q1[1], q1_2 = q1[2], q1_3 = q1[3],
		q2_0 = q2[0], q2_1 = q2[1], q2_2 = q2[2], q2_3 = q2[3];
	
	// Calculate angle between them.
	var cosHalfTheta = q1_3 * q2_3 + q1_0 * q2_0 + q1_1 * q2_1 + q1_2 * q2_2;
	// if q1=q2 or q1=-q2 then theta = 0 and we can return q1
	if (abs(cosHalfTheta) >= 1.0)
	{
		out[@ 3] = q1_3;
		out[@ 0] = q1_0;
		out[@ 1] = q1_1;
		out[@ 2] = q1_2;
		return;
	}
	// Calculate temporary values.
	var halfTheta = arccos(cosHalfTheta);
	var sinHalfTheta = sqrt(1.0 - cosHalfTheta*cosHalfTheta);
	// if theta = 180 degrees then result is not fully defined
	// we could rotate around any axis normal to q1 or q2
	if (abs(sinHalfTheta) < 0.000001)
	{
		out[@ 3] = (q1_3 * 0.5 + q2_3 * 0.5);
		out[@ 0] = (q1_0 * 0.5 + q2_0 * 0.5);
		out[@ 1] = (q1_1 * 0.5 + q2_1 * 0.5);
		out[@ 2] = (q1_2 * 0.5 + q2_2 * 0.5);
		return;
	}
	var ratioA = sin((1.0 - amt) * halfTheta) / sinHalfTheta;
	var ratioB = sin(amt * halfTheta) / sinHalfTheta; 
	// calculate Quaternion.
	out[@ 3] = (q1_3 * ratioA + q2_3 * ratioB);
	out[@ 0] = (q1_0 * ratioA + q2_0 * ratioB);
	out[@ 1] = (q1_1 * ratioA + q2_1 * ratioB);
	out[@ 2] = (q1_2 * ratioA + q2_2 * ratioB);
	return;
}

function QuatSlerp_r(q1, q2, amt, out)
{
	var q1_0 = q1[0], q1_1 = q1[1], q1_2 = q1[2], q1_3 = q1[3],
		q2_0 = q2[0], q2_1 = q2[1], q2_2 = q2[2], q2_3 = q2[3];
	
	// Calculate angle between them.
	var cosHalfTheta = q1_3 * q2_3 + q1_0 * q2_0 + q1_1 * q2_1 + q1_2 * q2_2;
	// if q1=q2 or q1=-q2 then theta = 0 and we can return q1
	if (abs(cosHalfTheta) >= 1.0)
	{
		out[@ 3] = q1_3;
		out[@ 0] = q1_0;
		out[@ 1] = q1_1;
		out[@ 2] = q1_2;
		return;
	}
	
	// Follow shortest path
	var reverse_q1 = 0;
	if (cosHalfTheta < 0.0)
	{
		reverse_q1 = 1;
		cosHalfTheta = -cosHalfTheta;
	}
	
	// Calculate temporary values.
	var halfTheta = arccos(cosHalfTheta);
	var sinHalfTheta = sqrt(1.0 - cosHalfTheta*cosHalfTheta);
	// if theta = 180 degrees then result is not fully defined
	// we could rotate around any axis normal to q1 or q2
	if (abs(sinHalfTheta) < 0.000001)
	{
		if !reverse_q1
		{
			out[@ 3] = (q1_3 * 0.5 + q2_3 * 0.5);
			out[@ 0] = (q1_0 * 0.5 + q2_0 * 0.5);
			out[@ 1] = (q1_1 * 0.5 + q2_1 * 0.5);
			out[@ 2] = (q1_2 * 0.5 + q2_2 * 0.5);
		}
		else
		{
			out[@ 3] = (q1_3 * 0.5 - q2_3 * 0.5);
			out[@ 0] = (q1_0 * 0.5 - q2_0 * 0.5);
			out[@ 1] = (q1_1 * 0.5 - q2_1 * 0.5);
			out[@ 2] = (q1_2 * 0.5 - q2_2 * 0.5);
		}
		return;
	}
	var ratioA = sin((1.0 - amt) * halfTheta) / sinHalfTheta;
	var ratioB = sin(amt * halfTheta) / sinHalfTheta; 
	// calculate Quaternion.
	if !reverse_q1
	{
		out[@ 3] = (q1_3 * ratioA + q2_3 * ratioB);
		out[@ 0] = (q1_0 * ratioA + q2_0 * ratioB);
		out[@ 1] = (q1_1 * ratioA + q2_1 * ratioB);
		out[@ 2] = (q1_2 * ratioA + q2_2 * ratioB);
	}
	else
	{
		out[@ 3] = (q1_3 * ratioA - q2_3 * ratioB);
		out[@ 0] = (q1_0 * ratioA - q2_0 * ratioB);
		out[@ 1] = (q1_1 * ratioA - q2_1 * ratioB);
		out[@ 2] = (q1_2 * ratioA - q2_2 * ratioB);
	}
	return;
}

#macro QUATFAST_MU 1.85298109240830
#macro QUATFAST_u global.QuatFast_u
#macro QUATFAST_v global.QuatFast_v
#macro QUATFAST_bT global.QuatFast_bT
#macro QUATFAST_bD global.QuatFast_bD
QUATFAST_u = [1.0/(1*3), 1.0/(2*5) , 1.0/(3*7) , 1.0/(4*9) , 1.0/(5*11) , 1.0/(6*13) , 1.0/(7*15) , QUATFAST_MU/(8*17)];
QUATFAST_v = [1.0/3 , 2.0/5 , 3.0/7 , 4.0/9 , 5.0/11 , 6.0/13 , 7.0/15 , QUATFAST_MU*8.0/17];
QUATFAST_bT = array_create(8);
QUATFAST_bD = array_create(8);

/*
DOES NOT WORK!!!

source: https://www.geometrictools.com/Documentation/FastAndAccurateSlerp.pdf

function QuatSlerpFast(q1, q2, t, out)
{
	var q1_0 = q1[0], q1_1 = q1[1], q1_2 = q1[2], q1_3 = q1[3],
		q2_0 = q2[0], q2_1 = q2[1], q2_2 = q2[2], q2_3 = q2[3];
	
	// Calculate angle between them.
	var xml = (q1_3 * q2_3 + q1_0 * q2_0 + q1_1 * q2_1 + q1_2 * q2_2) - 1.0;
	var d = 1.0-t;
	var sqrT = t*t;
	var sqrD = d*d;
	
	for (var i = 7; i >= 0; --i)
	{
		QUATFAST_bT[i] = (QUATFAST_u[i] * sqrT - QUATFAST_v[i]) * xml;
		QUATFAST_bD[i] = (QUATFAST_u[i] * sqrD - QUATFAST_v[i]) * xml;
	}
	
	var f0 = t * (
		1 + QUATFAST_bT[0] * (1 + QUATFAST_bT[1] * (1 + QUATFAST_bT[2] *(1 + QUATFAST_bT[3] * (
		1 + QUATFAST_bT[4] * (1 + QUATFAST_bT[5] * (1 + QUATFAST_bT[6] *(1 + QUATFAST_bT[7] ) ) ) ) ) ) )
	);
	var f1 = t * (
		1 + QUATFAST_bD[0] * (1 + QUATFAST_bD[1] * (1 + QUATFAST_bD[2] *(1 + QUATFAST_bD[3] * (
		1 + QUATFAST_bD[4] * (1 + QUATFAST_bD[5] * (1 + QUATFAST_bD[6] *(1 + QUATFAST_bD[7] ) ) ) ) ) ) )
	);
	
	var _q1 = QuatScaled(q1, f0);
	var _q2 = QuatScaled(q2, f1);
	
	out[@ 0] = _q1[0] + _q2[0];
	out[@ 1] = _q1[1] + _q2[1];
	out[@ 2] = _q1[2] + _q2[2];
	out[@ 3] = _q1[3] + _q2[3];
}

*/


function Mat4ToQuat(m)
{
	var q;
	var t;
	
	// Not sure if this needs to be transposed because of gm
	var m00 = m[0], m01 = m[4], m02 = m[8],
		m10 = m[1], m11 = m[5], m12 = m[9],
		m20 = m[2], m21 = m[6], m22 = m[10];
	
	if (m22 < y)
	{
		if (m00 > m11)
		{
			t = 1.0 + m00 - m11 - m22;
			q = QuatBuild( t, m01+m10, m20+m02, m12-m21 );
		}
		else
		{
			t = 1.0 - m00 + m11 - m22;
			q = QuatBuild( m01+m10, t, m12+m21, m20-m02 );
		}
	}
	else
	{
		if (m00 < -m11)
		{
			t = 1.0 - m00 - m11 + m22;
			q = QuatBuild( m20+m02, m12+m21, t, m01-m10 );
		}
		else
		{
			t = 1.0 + m00 + m11 + m22;
			q = QuatBuild( m12-m21, m20-m02, m01-m10, t );
		}
	}
	
	q *= 0.5 / sqrt(t);
	return q;
}

// Credits to JuJuAdams for the following
function QuatMultiply(q1, q2)
{
	return [ // WXYZ
		q1[0]*q2[0] - q1[1]*q2[1] - q1[2]*q2[2] - q1[3]*q2[3],
        q1[0]*q2[1] + q1[1]*q2[0] + q1[2]*q2[3] - q1[3]*q2[2],
        q1[0]*q2[2] + q1[2]*q2[0] + q1[3]*q2[1] - q1[1]*q2[3],
        q1[0]*q2[3] + q1[3]*q2[0] + q1[1]*q2[2] - q1[2]*q2[1]
		];
	
	return [ // XYZW
		 q1[0] * q2[3] + q1[1] * q2[2] - q1[2] * q2[1] + q1[3] * q2[0],
	    -q1[0] * q2[2] + q1[1] * q2[3] + q1[2] * q2[0] + q1[3] * q2[1],
	     q1[0] * q2[1] - q1[1] * q2[0] + q1[2] * q2[3] + q1[3] * q2[2],
	    -q1[0] * q2[0] - q1[1] * q2[1] - q1[2] * q2[2] + q1[3] * q2[3]
	];
}

function QuatToMat4(q)
{
	var _r = q[0];
	var _x = q[1];
	var _y = q[2];
	var _z = q[3];

	var _length = sqrt(_x*_x + _y*_y + _z*_z);
	
	if _length == 0 {return matrix_build_identity();}
	
	var _hyp_sqr = _length*_length + _r*_r;

	//Calculate trig coefficients
	var _c   = 2*_r*_r / _hyp_sqr - 1;
	var _s   = 2*_length*_r*_hyp_sqr;
	var _omc = 1 - _c;

	//Normalise the input vector
	_x /= _length;
	_y /= _length;
	_z /= _length;

	//Build matrix
	return [_omc*_x*_x + _c   , _omc*_x*_y + _s*_z,  _omc*_x*_z - _s*_y, 0,
	        _omc*_x*_y - _s*_z, _omc*_y*_y + _c   ,  _omc*_y*_z + _s*_x, 0,
	        _omc*_x*_z + _s*_y, _omc*_y*_z - _s*_x,  _omc*_z*_z + _c   , 0,
	                         0,                  0,                   0, 1];
}

// Writes Quaternion rotation to matrix. (3x3 section only!)
function QuatToMat4_r(q, out)
{
	var _r = q[0], _x = q[1], _y = q[2], _z = q[3];
	var _length = sqrt(_x*_x + _y*_y + _z*_z);
	
	if _length == 0
	{
		out[@ 0] = 1; out[@ 1] = 0; out[@ 2] = 0; //out[@ 3] = 0;
		out[@ 4] = 0; out[@ 5] = 1; out[@ 6] = 0; //out[@ 7] = 0;
		out[@ 8] = 0; out[@ 9] = 0; out[@10] = 1; //out[@11] = 0;
		//out[@12] = 0; out[@13] = 0; out[@14] = 0; out[@15] = 1;
		return;
	}
	
	var _hyp_sqr = _length*_length + _r*_r;

	//Calculate trig coefficients
	var _c   = 2*_r*_r / _hyp_sqr - 1;
	var _s   = 2*_length*_r*_hyp_sqr;
	var _omc = 1 - _c;

	//Normalise the input vector
	_x /= _length; _y /= _length; _z /= _length;

	//Build matrix
	out[@ 0] = _omc*_x*_x + _c;
	out[@ 1] = _omc*_x*_y + _s*_z;
	out[@ 2] = _omc*_x*_z - _s*_y;
	//out[@ 3] = 0;
	out[@ 4] = _omc*_x*_y - _s*_z;
	out[@ 5] = _omc*_y*_y + _c;
	out[@ 6] = _omc*_y*_z + _s*_x;
	//out[@ 7] = 0;
	out[@ 8] = _omc*_x*_z + _s*_y;
	out[@ 9] = _omc*_y*_z - _s*_x;
	out[@10] = _omc*_z*_z + _c;
	//out[@11] = 0;
	//out[@12] = 0;
	//out[@13] = 0;
	//out[@14] = 0;
	//out[@15] = 1;
}

function QuatRotateLocalX(q, angle)
{
	return QuatMultiply(argument0[0], argument0[1], argument0[2], argument0[3],
                           dcos(argument1/2), dsin(argument1/2), 0, 0);
}

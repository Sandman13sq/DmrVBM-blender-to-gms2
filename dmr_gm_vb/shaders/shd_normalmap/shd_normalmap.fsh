//
// Simple passthrough fragment shader
//

varying vec3 v_pos;
varying vec2 v_uv;
varying vec4 v_color;
varying vec3 v_nor;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_dirtolight_ts;
varying vec3 v_dirtocamera_ts;

uniform vec3 u_camera[2]; // [pos, dir, light]
uniform vec4 u_drawmatrix[4]; // [alpha emission shine ??? colorfill[4] colorblend[4]]

const vec3 NY = vec3(1.0, -1.0, 1.0);
const vec3 u_lightpos = vec3(10.0, -10.0, 20.0);
const float u_emission = 0.0;

// Returns 1 if (value & (1 << flagindex)) is nonzero
// Why is there no bitwise operations in shaders?
bool CheckFlag(int value, int flagindex)
{
	return int(mod( floor(float(value) / pow(2.0, float(flagindex) ) ) , 2.0)) != 0;
}

float blendColorBurn(float base, float blend) {
	return (blend==0.0)?blend:max((1.0-((1.0-base)/blend)),0.0);
}

vec3 blendColorBurn(vec3 base, vec3 blend) {
	return vec3(blendColorBurn(base.r,blend.r),blendColorBurn(base.g,blend.g),blendColorBurn(base.b,blend.b));
}

vec3 blendColorBurn(vec3 base, vec3 blend, float opacity) {
	return (blendColorBurn(base, blend) * opacity + base * (1.0 - opacity));
}

float ColorRampFloat(
	float fac,
	float val0, float pos0,
	float val1, float pos1,
	float val2, float pos2,
	float val3, float pos3
	)
{
	if (fac < pos0) {return val0;}
	if (fac < pos1) {return mix(val0, val1, (fac - pos0) / (pos1 - pos0));}
	if (fac < pos2) {return mix(val1, val2, (fac - pos1) / (pos2 - pos1));}
	if (fac < pos3) {return mix(val2, val3, (fac - pos2) / (pos3 - pos2));}
	return val3;
}

vec3 ColorRampVec3(
	float fac,
	vec3 col0, float pos0,
	vec3 col1, float pos1,
	vec3 col2, float pos2,
	vec3 col3, float pos3
	)
{
	if (fac < pos0) {return col0;}
	if (fac < pos1) {return mix(col0, col1, (fac - pos0) / (pos1 - pos0));}
	if (fac < pos2) {return mix(col1, col2, (fac - pos1) / (pos2 - pos1));}
	if (fac < pos3) {return mix(col2, col3, (fac - pos2) / (pos3 - pos2));}
	return col3;
}

// Returns "fac" value mapped to range [pos0, pos1]
float MapRange(float fac, float pos0, float pos1)
{
	return clamp((fac - pos0) / (pos1 - pos0), 0.0, 1.0);
}

// Returns blurred value from [0, 1] at position
float MapBlur(float fac, float pos, float blur)
{
	return clamp((fac - pos + blur*0.5) / blur, 0.0, 1.0);
}

float u_skin = 0.0;

void main()
{
	vec3 n; // Surface Normal
	vec3 l; // Direction from fragment -> light
	vec3 e; // Direction from fragment -> camera
	
	vec3 colordiffuse = v_color.rgb;
	vec3 colorshadow = colordiffuse * vec3(0.1, 0.1, 0.5);
	vec3 colorshine = colordiffuse * vec3(1.2);
	vec3 colorfresnel = colordiffuse * vec3(1.2);
	
	colorshadow = mix(colorshadow, colordiffuse * vec3(0.5, 0.1, 0.3), u_skin);
	
	if (false) // 
	{
		n = v_nor;
		l = normalize(v_dirtolight_cs);
		e = normalize(v_dirtocamera_cs);
	}
	else
	{
		n = normalize(texture2D(gm_BaseTexture, v_uv).xyz * 2.0 - 1.0);
		l = normalize(v_dirtolight_ts);
		e = normalize(v_dirtocamera_ts);
	}
	
	float dp = clamp( dot(n, l), 0.0, 1.0 ); // (1 = exposed, -1 = hidden, 0 = perpendicular)
	
	// Shadow
	vec3 diffusecolor = v_color.rgb;
	vec3 shadowcolor = mix(
		vec3(0.003, 0.003, 0.15), 
		mix(diffusecolor, diffusecolor * vec3(0.5, 0.0, 0.5), 0.5), 
		u_skin
		);
	//shadowcolor = mix(diffusecolor, shadowcolor, 0.7);
	//dp = mix(dp, MapRange(dp, 0.4, 0.5), 0.5);
	
	// Fake Fresnel
	float fresnel = pow(1.0 - dot(e, normalize(n + vec3(0.0, 0.0, -0.5))), 2.0);
	//fresnel = MapBlur(fresnel, 0.5, 0.1);
	fresnel = mix(fresnel, fresnel * 0.5, u_skin);
	
	// Specular
	float shine = clamp(dot(e, reflect(-l, n) ), 0.0, 1.0);
	shine = pow(shine, 16.0);
	//shine = mix(0.0, 0.5, max(0.0, shine - 0.5));
	shine = mix(shine, shine * 0.5, u_skin);
	//shine = MapBlur(shine, 0.9, 0.1);
	
	// Skin
	vec3 ssscolor = diffusecolor;
	ssscolor = mix(ssscolor, ssscolor * vec3(1.0, vec2(0.7)) * mix(0.7, 1.0, dp), 1.0-dp );
	ssscolor = blendColorBurn(diffusecolor, vec3(0.0, 0.1, 1.0), 0.1 * dp);
	
	gl_FragColor.rgb = mix(colorshadow, colordiffuse, dp);
	gl_FragColor.rgb = mix(gl_FragColor.rgb, colorshine, shine);
	gl_FragColor.rgb = mix(gl_FragColor.rgb, colorfresnel, fresnel);
	gl_FragColor.rgb = mix(gl_FragColor.rgb, colordiffuse, mix(0.2, 1.0, u_emission));
	
}

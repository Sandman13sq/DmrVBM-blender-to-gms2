//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform float u_hue;
uniform float u_sat;
uniform float u_lum;

/*
	Credits to the souls in this thread:
	https://gist.github.com/mairod/a75e7b44f68110e1576d77419d608786
*/
// Shifts given color hue by amount (loops every 2pi)
vec3 HueShift(vec3 color, float amt)
{
	const vec3 k = vec3(0.57735);
	float cosangle = cos(amt);
	
	return vec3(
		color * cosangle + 
		cross(k, color) * sin(amt) + 
		k * dot(k, color) * (1.0 - cosangle)
		);
}

void main()
{
    gl_FragColor = v_vColour * texture2D( gm_BaseTexture, v_vTexcoord );
	vec3 basecolor = gl_FragColor.rgb;
	
	// Hue
	gl_FragColor.rgb = HueShift(basecolor, u_hue);
	// Saturation
	gl_FragColor.rgb = mix(vec3(length(basecolor)), gl_FragColor.rgb, u_sat);
	// Brightness
	gl_FragColor.rgb += u_lum;
}

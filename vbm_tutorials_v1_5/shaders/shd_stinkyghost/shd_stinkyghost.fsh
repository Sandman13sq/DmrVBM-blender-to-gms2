//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

#define PI 3.141592653589793

uniform float u_time;
uniform vec4 u_color[2];

void main() {
	float t = u_time * 0.5;
	vec2 uv = gl_FragCoord.xy;
	
	uv = uv / 800.0;
	uv.x += 0.1*cos(t+uv.y*8.0) * mix(-1.0, 1.0, step(sin(512.0*uv.y), 0.1));
	
    float x = texture2D(gm_BaseTexture, mod(uv, 1.0)).r;
	float x_nonzero = float(x >= 0.01);
	float f = 1.0;
	float r = 0.2;
	
	x -= x_nonzero * 0.3;
	x = 0.5+0.5*sin(f*2.0*PI*(x + r*t));
	vec4 color = mix(u_color[0], u_color[1], x);
	
    gl_FragColor = color;
}


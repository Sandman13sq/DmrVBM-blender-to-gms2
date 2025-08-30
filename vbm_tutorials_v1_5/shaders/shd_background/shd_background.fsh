//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

#define PI 3.141592653589793

uniform float u_time;
uniform vec4 u_color[2];

void main() {
    vec2 uv = gl_FragCoord.xy / 1000.0;
    float t = u_time;
    float amt[2];
	
    uv.y += t/100.;
    amt[0] = 4.*uv.x + 2.*(uv.y) + .5*sin(16.*uv.y-t/2.);
    amt[0] = float(distance(fract(amt[0]), 0.5) < 0.2);
    
    amt[1] = 5.*uv.x + 1.*(uv.y) + .2*cos(32.*uv.y+t/3.);
    amt[1] = float(distance(fract(amt[1]), 0.5) < 0.3);
    
    gl_FragColor = mix(u_color[0], u_color[1], (amt[0]+amt[1])/2.0);
}


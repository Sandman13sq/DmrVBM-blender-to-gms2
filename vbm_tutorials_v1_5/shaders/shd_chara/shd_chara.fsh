//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;

varying vec3 v_axes[4];

void main()
{
	// Params -----------------------------------------------------
	vec3 normal = normalize(v_vNormal);
	vec3 incoming = normalize(-v_axes[2]);
	vec3 lightvec = -normalize(v_axes[2]-vec3(0,0,40));
	
	float dp = dot(normal, lightvec);	// shadow
	float dr = dot(normal, normalize(incoming+lightvec));	// reflect
	float di = dot(normal, incoming);	// incoming
	
	float shadowvalue = dp+v_vColour.b*2.0-1.0;
	
	// Color ---------------------------------------------------------
	vec4 cbase = texture2D(gm_BaseTexture, v_vTexcoord);
	//cbase = vec4(0.2, 0.1, 0.3, 1);
	vec4 chigh = cbase + cbase * max(vec4(1.9)-length(cbase), vec4(0));
	vec4 cdark1 = cbase * vec4(0.8, 0.5, 0.8, 1.0);
	vec4 cdark2 = cbase * vec4(0.4, 0.3, 0.7, 1.0);
	
	// Output --------------------------------------------------------
	vec4 c = cbase;
	c = mix(c, chigh, float(dr>0.95 || (di-dp < -0.3)));
	c = mix(c, cdark1, float(shadowvalue < 0.0));
	c = mix(c, cdark2, float(shadowvalue < -0.9));
	
    c.a = cbase.a;
    c = clamp(c, vec4(0), vec4(1));
	
    gl_FragColor = c;
}

//
// Simple passthrough fragment shader
//
varying vec2 v_uv;
varying vec3 v_position;
varying vec3 v_normal;
varying float v_netweight;
varying float v_outline;

varying vec3 v_eyeforward;	// View forward vector
varying vec3 v_eyeright;	// View right vector
varying vec3 v_eyeup;		// View up vector

uniform float u_meshflash;	// Mesh flash time

void main()
{
	// Input variables
	vec3 n = normalize(v_normal);
	vec3 l = normalize(vec3(1.0,-1.0,1.0));
	vec3 incoming = normalize(-v_eyeforward);
	
	// Calculations
	float dp = dot(normalize(n), l);
	float rim = dot(normalize(incoming + vec3(.0, .0, -.2)), n);
	float spe = dot(reflect(-l, n), incoming);
	float ani = ((1.0 - abs( dot( normalize( n+(incoming+vec3(.0,.0,.5))*vec3(-.5) ), vec3(.0,.0,1.) ))) * dot(n,l));
	
	// Colors
	vec4 color = texture2D( gm_BaseTexture, v_uv );
	vec3 cspec = color.rgb * 1.5;
	vec3 cdark1 = color.rgb * vec3(.8, .4, .8);
	vec3 cdark2 = color.rgb * vec3(.2, .2, .5);
	vec3 coutline = cdark2 * cdark1;
	
	// Style Color
	if (false) {
		gl_FragColor = color;
	    gl_FragColor.rgb = mix(gl_FragColor.rgb, cspec.rgb, float((rim < 0.4) || (ani > 0.95)));
	    gl_FragColor.rgb = mix(gl_FragColor.rgb, cdark1.rgb, float(dp < 0.0));
	    gl_FragColor.rgb = mix(gl_FragColor.rgb, cdark2.rgb, float(dp <-0.5));
		gl_FragColor.rgb = mix(gl_FragColor.rgb, coutline, v_outline);
	}
	else {
		gl_FragColor = color;
		//gl_FragColor.rgb = mix(gl_FragColor.rgb, cspec.rgb, float((rim < 0.4) || (ani > 0.95)));
		gl_FragColor.rgb = mix(gl_FragColor.rgb, cdark1.rgb, 1.0-max(dp*.5+.5, 0.0));
		gl_FragColor.rgb = mix(gl_FragColor.rgb, cdark2.rgb, 1.0-max((dp*.5+.5)+0.5, 0.0));
		gl_FragColor.rgb = mix(gl_FragColor.rgb, coutline, v_outline);
	}
	
	// Weight Color
	vec3 bonecolor = vec3(.13, .13, .5);
	bonecolor = mix(bonecolor, vec3(.13, .74, .13), min(v_netweight * 2.0, 1.0));
	bonecolor = mix(bonecolor, vec3(1., .13, .13), max(0.0, v_netweight * 2.0 - 1.0));
	
	gl_FragColor.rgb = mix(gl_FragColor.rgb, bonecolor, float(v_netweight > -.5) * 0.9);
	gl_FragColor = mix(gl_FragColor, vec4(1.0), u_meshflash);
}

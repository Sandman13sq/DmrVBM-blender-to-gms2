//
// Simple passthrough fragment shader
//

// Passed from Vertex Shader
varying vec3 v_pos;
varying vec2 v_uv;
varying vec4 v_color;
varying vec3 v_nor;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_dirtolight_ts;
varying vec3 v_dirtocamera_ts;

// Uniforms passed in before draw call
uniform vec3 u_camera[2]; // [pos, dir, light]
uniform vec4 u_drawmatrix[4]; // [alpha emission shine sss colorfill[4] colorblend[4]]

void main()
{
	vec3 texnor = texture2D(gm_BaseTexture, v_uv).xyz;
	texnor = mix(texnor, vec3(0.5, 0.5, 1.0), float(texnor == vec3(1.0, 1.0, 1.0)));
		
	vec3 n = normalize((texnor * 2.0) - 1.0);
	vec3 l = normalize(v_dirtolight_ts);
	vec3 e = normalize(v_dirtocamera_ts);
	vec3 r = reflect(l, n);				// Reflect Angle
	
	// Dot Product
	float dp = clamp(dot(n, l), 0.0, 1.0);
	dp = dot(n, l);
	
	// Specular
	float shine = pow( clamp( dot(-e, r), 0.0, 1.0), 64.0 );
	
	vec4 diffusecolor = v_color;// * texture2D( gm_BaseTexture, v_uv);
	vec3 shadowtint = mix(vec3(0.1, 0.0, 0.5), vec3(.5, .0, .2), u_drawmatrix[0].w);
	vec3 shadowcolor = mix(diffusecolor.rgb * shadowtint, diffusecolor.rgb*0.5, 0.7);
	vec3 shinecolor = diffusecolor.rgb * vec3(1.0-(length(diffusecolor.rgb)*0.65));
	shinecolor = mix(shinecolor, vec3(1.0), 0.5);
	
	vec3 outcolor = mix(shadowcolor, diffusecolor.rgb, dp);
	outcolor += shinecolor * clamp(shine, 0.0, 1.0) * u_drawmatrix[0][2];
	
	// Emission
	outcolor = mix(outcolor, diffusecolor.rgb, u_drawmatrix[0][1]);
	// Fill Color
	outcolor = mix(outcolor, u_drawmatrix[1].rgb, u_drawmatrix[1].a);
	// Blend Color
	outcolor = mix(outcolor, u_drawmatrix[2].rgb*diffusecolor.rgb, u_drawmatrix[2].a);
	
	// Alpha
    gl_FragColor = vec4(outcolor, u_drawmatrix[0][0]*diffusecolor.a);
	
	if (gl_FragColor.a == 0.0) {discard;}
}

void main0()
{
	vec3 n; // Surface Normal
	vec3 l; // Direction from fragment -> light
	vec3 c; // Direction from fragment -> camera
	
	if (false) // 
	{
		n = v_nor;
		l = normalize(v_dirtolight_cs);
		c = normalize(v_dirtocamera_cs);
	}
	else
	{
		vec3 texnor = texture2D(gm_BaseTexture, v_uv).xyz;
		texnor = mix(texnor, vec3(0.5, 0.5, 1.0), float(texnor == vec3(1.0, 1.0, 1.0)));
		
		n = normalize((texnor * 2.0) - 1.0);
		l = normalize(v_dirtolight_ts);
		c = normalize(v_dirtocamera_ts);
	}
	c.y *= -1.0;
	
	// Dot Product
	float dp = clamp(dot(n, l), 0.0, 1.0); // (1 = exposed, -1 = hidden, 0 = perpendicular)
	//dp = pow(dp, 0.5);
	
	// Fake Fresnel
	float fresnel = dot(n, c);
	fresnel = clamp(pow(1.0-fresnel, 8.0), 0.0, 1.0);
	fresnel = float(fresnel >= 0.02);
	
	// Specular
	float shine = pow(dp + 0.03, 512.0);
	
	vec4 diffusecolor = v_color;// * texture2D( gm_BaseTexture, v_uv);
	vec3 shadowtint = mix(vec3(0.1, 0.0, 0.5), vec3(.5, .0, .2), u_drawmatrix[0].w);
	vec3 shadowcolor = mix(diffusecolor.rgb * shadowtint, diffusecolor.rgb, 0.7);
	vec3 shinecolor = diffusecolor.rgb * vec3(1.0-(length(diffusecolor.rgb)*0.65));
	
	vec3 outcolor = mix(shadowcolor, diffusecolor.rgb, dp);
	//outcolor += (diffusecolor.rgb * 0.4) * clamp(shine+fresnel, 0.0, 1.0);
	outcolor += shinecolor * clamp(shine, 0.0, 1.0) * u_drawmatrix[0][2];
	
	// Emission
	outcolor = mix(outcolor, diffusecolor.rgb, u_drawmatrix[0][1]);
	// Fill Color
	outcolor = mix(outcolor, u_drawmatrix[1].rgb, u_drawmatrix[1].a);
	// Blend Color
	outcolor = mix(outcolor, u_drawmatrix[2].rgb*diffusecolor.rgb, u_drawmatrix[2].a);
	
	// Alpha
    gl_FragColor = vec4(outcolor, u_drawmatrix[0][0]*diffusecolor.a);
	
	if (gl_FragColor.a == 0.0) {discard;}
	
}

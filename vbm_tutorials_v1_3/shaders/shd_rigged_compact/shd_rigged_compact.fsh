//
//	Transforms vertices by bone matrices
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main()
{
    gl_FragColor = v_vColour * texture2D( gm_BaseTexture, vec2(v_vTexcoord.x, v_vTexcoord.y) );	
}

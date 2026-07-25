#version 120

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform vec4 entityColor; 

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;

	bool isUnlitEmissiveLayer = (lmcoord.x < 0.001 && lmcoord.y < 0.001);
	if (!isUnlitEmissiveLayer) {
		color *= texture2D(lightmap, lmcoord);
	}

	color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}
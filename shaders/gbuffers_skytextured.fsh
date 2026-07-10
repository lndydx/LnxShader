#version 120

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 glcolor;

/* DRAWBUFFERS:01 */

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;

	gl_FragData[0] = color; //gcolor
	gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0); 
}
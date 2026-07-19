#version 120

uniform sampler2D lightmap;

varying vec2 lmcoord;
varying vec4 glcolor;

/* DRAWBUFFERS:0 */

void main() {
	vec4 color = glcolor;
	color.a = max(color.a, 0.9); // pastiin gak transparan
	gl_FragData[0] = color;
}
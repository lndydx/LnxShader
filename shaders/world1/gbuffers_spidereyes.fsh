#version 120

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 glcolor;

#define SPIDEREYES_BRIGHTNESS 0.85 

/* DRAWBUFFERS:0 */

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color.rgb *= SPIDEREYES_BRIGHTNESS;
	gl_FragData[0] = color;
}
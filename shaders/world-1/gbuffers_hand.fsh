#version 120

uniform int biome_category;

#include "/lib/nether_sky.glsl"
#include "/lib/nether_lighting.glsl"

uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos; // unused

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color *= texture2D(lightmap, lmcoord);
	color.rgb = applyNetherAmbientFill(color.rgb, getNetherAmbientFillColor(biome_category));

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}
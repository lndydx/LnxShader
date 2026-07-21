#version 120

uniform int biome_category;

uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying float isEmissiveBlock;
varying vec3 viewNormal;   
varying vec3 viewPosVar;

#include "/lib/nether_sky.glsl"
#include "/lib/nether_lighting.glsl"

#define RIM_COLOR vec3(0.780, 0.337, 0.039)
#define RIM_POWER 2.0
#define RIM_STRENGTH 1.0

#define BLOCKLIGHT_RADIUS 2.0
#define TORCH_WARM_TINT vec3(1.40, 1.05, 0.50)
#define TORCH_WARM_STRENGTH 0.35   
#define TORCH_SPREAD_CURVE 0.8
#define EMISSIVE_GLOW_BOOST 1.6

float rimFactor(vec3 N, vec3 V, float lightAmount) {
    float facing = 1.0 - max(dot(N, V), 0.0);
    return pow(facing, RIM_POWER) * lightAmount;
}

void main() {
	vec4 texColor = texture2D(texture, texcoord);
	
	float glLuma = dot(glcolor.rgb, vec3(0.299, 0.587, 0.114));
	vec3 glFlat  = vec3(max(glLuma, 1.0)) * EMISSIVE_GLOW_BOOST;
	vec3 glFinal = mix(glcolor.rgb, glFlat, isEmissiveBlock);

	vec4 color = vec4(texColor.rgb * glFinal, texColor.a * glcolor.a);

	vec2 lm = lmcoord;
	lm.x = pow(lm.x, BLOCKLIGHT_RADIUS);
	color *= texture2D(lightmap, lm);

	float torchStrength = pow(lmcoord.x, TORCH_SPREAD_CURVE);
	color.rgb = mix(color.rgb, color.rgb * TORCH_WARM_TINT, torchStrength * TORCH_WARM_STRENGTH);

	color.rgb = applyNetherAmbientFill(color.rgb, getNetherAmbientFillColor(biome_category));

	vec3 V = normalize(-viewPosVar);
	float rim = rimFactor(normalize(viewNormal), V, torchStrength);
	color.rgb += RIM_COLOR * rim * RIM_STRENGTH;

/* DRAWBUFFERS:01 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
}
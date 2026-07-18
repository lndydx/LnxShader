#version 120

#define COLORED_SHADOWS 1
#define SHADOW_BRIGHTNESS 0.75
#define LEAF_SSS 

uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;
uniform vec3 shadowLightPosition;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;

varying vec3 leafViewPos;  
varying float isLeaf;
varying float isEmissiveBlock;

const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

#include "/distort.glsl"
#ifdef LEAF_SSS
#include "/lib/leaf_sss.glsl"
#endif

#define TORCH_WARM_TINT      vec3(1.000, 1.000, 0.898)
#define TORCH_WARM_STRENGTH  0.55
#define TORCH_SPREAD_CURVE   0.8
#define EMISSIVE_GLOW_BOOST  1.4

void main() {
	vec4 texColor = texture2D(texture, texcoord);

	float glLuma = dot(glcolor.rgb, vec3(0.299, 0.587, 0.114));
	vec3 glFlat  = vec3(max(glLuma, 1.0)) * EMISSIVE_GLOW_BOOST;
	vec3 glFinal = mix(glcolor.rgb, glFlat, isEmissiveBlock);

	vec4 color = vec4(texColor.rgb * glFinal, texColor.a * glcolor.a);

	vec2 lm = lmcoord;
	#ifdef SHADOWS
	if (shadowPos.w > 0.0) {
		#if COLORED_SHADOWS == 0
			if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
		#else
			if (texture2D(shadowtex1, shadowPos.xy).r < shadowPos.z) {
		#endif
			lm.y *= SHADOW_BRIGHTNESS;
		}
		else {
			lm.y = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
			#if COLORED_SHADOWS == 1
				if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
					vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
					shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);
					shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lm.x);
					color.rgb *= shadowLightColor.rgb;
				}
			#endif
		}
	}
	#endif	
	#define BLOCKLIGHT_RADIUS 1.8
	lm.x = pow(lm.x, BLOCKLIGHT_RADIUS);
	color *= texture2D(lightmap, lm);

	float torchStrength = pow(lmcoord.x, TORCH_SPREAD_CURVE);
	color.rgb = mix(color.rgb, color.rgb * TORCH_WARM_TINT, torchStrength * TORCH_WARM_STRENGTH);

	#if defined LEAF_SSS
	if (isLeaf > 0.5) {
		vec3 viewDir = normalize(leafViewPos);
		vec3 sunDir  = normalize(shadowLightPosition);
		color.rgb += calcLeafSSS(color.rgb, viewDir, sunDir, shadowPos, shadowtex1);
	}
	#endif

	/* DRAWBUFFERS:01 */
	gl_FragData[0] = color; 
	gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0); 
}
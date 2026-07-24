#version 120

uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying float isEmissiveBlock;
varying vec3 viewNormal;
varying vec3 viewPosVar;

#include "/lib/end_palette.glsl"

#define END_BASE_DARKEN        0.80
#define END_MIN_AMBIENT_LIGHT  0.22
#define BLOCKLIGHT_RADIUS      1.8
#define TORCH_WARM_TINT        vec3(1.000, 0.839, 0.980)
#define TORCH_WARM_STRENGTH    0.85
#define TORCH_SPREAD_CURVE     0.8
#define EMISSIVE_GLOW_BOOST    1.5
#define CRYSTAL_GLOW_STRENGTH  0.55

#define END_SPECULAR_STRENGTH  0.50 //[tuning] kekuatan sheen keseluruhan. 0 = mati total
#define END_SPECULAR_POWER     4.0  //[tuning] makin besar = highlight makin sempit/tajam di sudut landai
#define END_SPECULAR_TINT      vec3(0.914, 0.588, 0.886) //[tuning] warna reflect, pucat-violet ikut ambient
#define END_SPECULAR_MIN_LIGHT 0.45 //[tuning] batas bawah biar tetap ada sheen tipis walau di area gelap/goa

void main() {
	vec4 texColor = texture2D(texture, texcoord);

	float glLuma = dot(glcolor.rgb, vec3(0.299, 0.587, 0.114));
	vec3 glFlat  = vec3(max(glLuma, 1.0)) * EMISSIVE_GLOW_BOOST;
	vec3 glFinal = mix(glcolor.rgb, glFlat, isEmissiveBlock);

	vec4 color = vec4(texColor.rgb * glFinal, texColor.a * glcolor.a);

	vec2 lm = lmcoord;
	lm.x = pow(lm.x, BLOCKLIGHT_RADIUS);
	lm.y = max(lm.y, END_MIN_AMBIENT_LIGHT);

	color *= texture2D(lightmap, lm);
	color.rgb += AMBIENT_LIGHT * END_MIN_AMBIENT_LIGHT * 0.5;

	float torchStrength = pow(lmcoord.x, TORCH_SPREAD_CURVE);
	color.rgb = mix(color.rgb, color.rgb * TORCH_WARM_TINT, torchStrength * TORCH_WARM_STRENGTH);

	color.rgb = mix(color.rgb, color.rgb * CRYSTAL_GLOW * 1.6, isEmissiveBlock * CRYSTAL_GLOW_STRENGTH);

	vec3 N = normalize(viewNormal);
	vec3 V = normalize(-viewPosVar);
	float fresnel = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), END_SPECULAR_POWER);
	float skylightGate = max(lm.y, END_SPECULAR_MIN_LIGHT);
	color.rgb += END_SPECULAR_TINT * fresnel * END_SPECULAR_STRENGTH * skylightGate;

	color.rgb *= END_BASE_DARKEN;

/* DRAWBUFFERS:01 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
}
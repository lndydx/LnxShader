#version 120

uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying float isEmissiveBlock;

#include "/lib/end_palette.glsl"

#define END_BASE_DARKEN        0.80  //[tuning] 1.0 = gak digelapin sama sekali, makin kecil makin gelap
#define END_MIN_AMBIENT_LIGHT  0.22  //[tuning] lantai ambien minimum, jangan sampai 0 (biar gak item)
#define BLOCKLIGHT_RADIUS      1.8   //[tuning] curve falloff cahaya torch/glowstone
#define TORCH_WARM_TINT        vec3(1.000, 0.839, 0.980) //[tuning] tint cahaya block warm
#define TORCH_WARM_STRENGTH    0.85  //[tuning] kekuatan blend tint warm ke torch light
#define TORCH_SPREAD_CURVE     0.8   //[tuning] curve seberapa cepat torch tint menyebar
#define EMISSIVE_GLOW_BOOST    1.6   //[tuning] boost brightness block emissive putih (glowstone dll)
#define CRYSTAL_GLOW_STRENGTH  0.55  //[tuning] seberapa kuat tint ungu ke block emissive

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

	color.rgb *= END_BASE_DARKEN;

/* DRAWBUFFERS:01 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
}
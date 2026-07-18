#version 120
uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying float isEmissiveBlock;

#define BLOCKLIGHT_RADIUS 1.8
#define TORCH_WARM_TINT vec3(1.40, 1.05, 0.50)
#define TORCH_WARM_STRENGTH 0.60   
#define TORCH_SPREAD_CURVE 0.8
#define EMISSIVE_GLOW_BOOST 1.6

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

/* DRAWBUFFERS:01 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
}
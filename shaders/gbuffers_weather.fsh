#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float alphaTestRef = 0.1;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;

#define RAIN_TINT vec3(0.55, 0.57, 0.60)
#define RAIN_TINT_STRENGTH 0.5
#define RAIN_DENSITY 0.3

/* DRAWBUFFERS:01 */

void main() {
    vec4 baseColor = texture2D(texture, texcoord) * glcolor;

    if (baseColor.a < alphaTestRef) {
        discard;
    }

    vec3 lm = texture2D(lightmap, lmcoord).rgb;

    vec3 tintedColor = mix(baseColor.rgb, RAIN_TINT, RAIN_TINT_STRENGTH);
    float finalAlpha = baseColor.a * RAIN_DENSITY;

    gl_FragData[0] = vec4(tintedColor * lm, finalAlpha);
    gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
}
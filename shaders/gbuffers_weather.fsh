#version 120

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform float alphaTestRef = 0.1;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#define RAIN_DROP_TINT vec3(0.88, 0.86, 0.82)
#define RAIN_DROP_ALPHA_MULT 0.55

/* DRAWBUFFERS:0 */

void main() {
    vec4 color = texture2D(texture, texcoord) * glcolor;
    color *= texture2D(lightmap, lmcoord);

    color.rgb *= RAIN_DROP_TINT;
    color.a   *= RAIN_DROP_ALPHA_MULT;

    if (color.a < alphaTestRef) {
        discard;
    }

    gl_FragData[0] = color;
}
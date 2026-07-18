#version 120

uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform float rainStrength;

varying vec4 starData;

#define END_SKY_ZENITH  vec3(0.035, 0.028, 0.055)
#define END_SKY_HORIZON vec3(0.10, 0.075, 0.14)

vec3 calcEndSkyColor(vec3 viewDir) {
    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
    float t = clamp(worldDir.y * 0.5 + 0.5, 0.0, 1.0);
    float horizonBlend = smoothstep(0.30, 0.85, t);
    return mix(END_SKY_HORIZON, END_SKY_ZENITH, horizonBlend);
}

/* DRAWBUFFERS:01 */

void main() {
    vec3 color;
    if (starData.a > 0.5) {
        color = starData.rgb * 0.0;
    } else {
        vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
        pos = gbufferProjectionInverse * pos;
        color = calcEndSkyColor(normalize(pos.xyz));
    }

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
}

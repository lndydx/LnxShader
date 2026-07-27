#version 120

uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float netherBiomeId;

varying vec4 starData;

#include "/lib/nether_sky.glsl"

vec3 calcNetherSkyColor(vec3 viewDir) {
    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
    vec3 baseFog = getNetherFogColor(netherBiomeId);
    vec3 atmo = renderNetherAtmosphere(worldDir, frameTimeCounter, netherBiomeId);
    return baseFog * 0.5 + atmo;
}

/* DRAWBUFFERS:01 */

void main() {
    vec3 color;
    if (starData.a > 0.5) {
        color = starData.rgb * 0.0;
    } else {
        vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
        pos = gbufferProjectionInverse * pos;
        color = calcNetherSkyColor(normalize(pos.xyz));
    }

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
}
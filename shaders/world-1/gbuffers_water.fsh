#version 120

uniform float netherBiomeId;

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float alphaTestRef = 0.1;
uniform mat4 gbufferModelView;
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying vec3 flatNormal;
varying float isRealWater;
varying float isLava;

#include "/lib/ggx.glsl"
#include "/lib/nether_sky.glsl"
#include "/lib/nether_lighting.glsl"

#define LAVA_EMISSIVE_BOOST 2.4
#define LAVA_PULSE_STRENGTH 0.06
#define LAVA_SPECULAR_ROUGHNESS 0.30   
#define LAVA_SPECULAR_INTENSITY 3.6
#define LAVA_SPECULAR_F0 0.08

/* DRAWBUFFERS:0 */

void main() {
    vec4 baseColor = texture2D(texture, texcoord) * glcolor;
    if (baseColor.a < alphaTestRef) discard;

    vec3 lm = texture2D(lightmap, lmcoord).rgb;

    if (isLava > 0.5) {
        float pulse = 1.0 + sin(frameTimeCounter * 2.0) * LAVA_PULSE_STRENGTH;
        vec3 lavaGlow = baseColor.rgb * lm * LAVA_EMISSIVE_BOOST * pulse;
        
        vec3 N = normalize(viewNormal);
        vec3 V = normalize(-viewPos);
        vec3 fakeGlowDir = normalize((gbufferModelView * vec4(0.0, 1.0, 0.0, 0.0)).xyz);

        vec3 sheen = ggxSpecular(N, V, fakeGlowDir, LAVA_SPECULAR_ROUGHNESS, vec3(LAVA_SPECULAR_F0));
        lavaGlow += sheen * LAVA_SPECULAR_INTENSITY * baseColor.rgb;

        gl_FragData[0] = vec4(lavaGlow, 1.0);
        return;
    }

    if (isRealWater > 0.5) {
        gl_FragData[0] = vec4(baseColor.rgb * lm * vec3(0.4, 0.55, 0.65), baseColor.a);
        return;
    }

    gl_FragData[0] = vec4(applyNetherAmbientFill(baseColor.rgb * lm, getNetherAmbientFillColor(netherBiomeId)), baseColor.a); 
}   
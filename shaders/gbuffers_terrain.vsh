#version 120

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_mid_block;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;

 // SSS
varying vec3 leafViewPos;  
varying float isLeaf;      

#include "/distort.glsl"

// WIND CONFIG 
#define WAVE_LEAVES_ID   10010
#define WAVE_GRASS_ID    10011
#define WAVE_VINE_ID     10012
#define WAVE_FLOWER_ID   10013
#define WAVE_CROP_ID     10014
#define WAVE_LITTER_ID   10015
#define WAVE_DRIPLEAF_ID 10016

#define WIND_LITTER_STRENGTH   0.04
#define WIND_DRIPLEAF_STRENGTH 0.08
#define WIND_LEAVES_STRENGTH   0.08
#define WIND_GRASS_STRENGTH    0.15
#define WIND_VINE_STRENGTH     0.08
#define WIND_DIR vec2(0.8, 0.5)

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 getWindOffset(vec3 worldPos, float mask, float strength, float phase, float freqMul) {
    if (mask <= 0.0) return vec3(0.0);

    float t = frameTimeCounter * (1.2 + freqMul * 0.7) + phase;

    float w1 = sin(t + worldPos.x * 0.6 + worldPos.z * 0.4);
    float w2 = sin(t * 1.8 + worldPos.x * 1.1 - worldPos.z * 0.9 + 1.7);
    float w3 = sin(t * 0.55 - worldPos.x * 0.3 + worldPos.z * 0.8 + 4.2);

    float combined = w1 * 0.5 + w2 * 0.3 + w3 * 0.2;

    return vec3(WIND_DIR.x, 0.0, WIND_DIR.y) * combined * strength * mask;
}

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;

    // WIND ANIMATION 
    vec4 position = gl_Vertex;
    vec3 worldPos = position.xyz + cameraPosition;
    vec3 blockPos = floor(worldPos + 0.001);

    int blockId = int(mc_Entity.x);
    isLeaf = float(blockId == WAVE_LEAVES_ID);

    if (blockId == WAVE_LEAVES_ID) {
        float phase   = hash13(blockPos) * 6.283;
        float freqMul = hash13(blockPos + 17.0);
        position.xyz += getWindOffset(worldPos, 1.0, WIND_LEAVES_STRENGTH, phase, freqMul);
    }
    else if (blockId == WAVE_GRASS_ID || blockId == WAVE_FLOWER_ID || blockId == WAVE_CROP_ID) {
        float topMask = float(gl_MultiTexCoord0.y < mc_midTexCoord.y);
        float phase   = hash13(blockPos) * 6.283;
        float freqMul = hash13(blockPos + 41.0);
        position.xyz += getWindOffset(worldPos, topMask, WIND_GRASS_STRENGTH, phase, freqMul);
    }
    else if (blockId == WAVE_VINE_ID) {
        float bottomMask = float(gl_MultiTexCoord0.y > mc_midTexCoord.y);
        float phase   = hash13(blockPos) * 6.283;
        float freqMul = hash13(blockPos + 73.0);
        position.xyz += getWindOffset(worldPos, bottomMask, WIND_VINE_STRENGTH, phase, freqMul);
    }
    else if (blockId == WAVE_LITTER_ID) {
        float phase = hash13(blockPos) * 6.283;
        float t = frameTimeCounter * 1.5 + phase;
        float flutter = sin(t) * 0.5 + sin(t * 2.3 + 1.1) * 0.3;
        position.y += flutter * WIND_LITTER_STRENGTH * 0.3;
        position.x += flutter * WIND_LITTER_STRENGTH;
    }
    else if (blockId == WAVE_DRIPLEAF_ID) {
        float topMask = float(gl_MultiTexCoord0.y < mc_midTexCoord.y);
        float phase   = hash13(blockPos) * 6.283;
        float freqMul = hash13(blockPos + 97.0);
        position.xyz += getWindOffset(worldPos, topMask, WIND_DRIPLEAF_STRENGTH, phase, freqMul);
    }

    // SHADOW 
    vec3 viewNormal = gl_NormalMatrix * gl_Normal;
    float lightDot = dot(normalize(shadowLightPosition), normalize(viewNormal));
    #ifdef EXCLUDE_FOLIAGE
        float id = mc_Entity.x;
        bool isFoliage = (id == 10000.0) || (id >= 10010.0 && id <= 10016.0);
        if (isFoliage) lightDot = 1.0;
    #endif

    vec4 viewPos = gl_ModelViewMatrix * position;
    leafViewPos = viewPos.xyz;

    if (lightDot > 0.0) {
        vec4 playerPos = gbufferModelViewInverse * viewPos;
        shadowPos = shadowProjection * (shadowModelView * playerPos);
        float bias = computeBias(shadowPos.xyz);
        shadowPos.xyz = distort(shadowPos.xyz);
        shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5;
        #ifdef NORMAL_BIAS
            vec4 normal = shadowProjection * vec4(mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal)), 1.0);
            shadowPos.xyz += normal.xyz / normal.w * bias;
        #else
            shadowPos.z -= bias / abs(lightDot);
        #endif
    }
    else {
        lmcoord.y *= SHADOW_BRIGHTNESS;
        shadowPos = vec4(0.0);
    }
    shadowPos.w = lightDot;
    gl_Position = gl_ProjectionMatrix * viewPos;
}
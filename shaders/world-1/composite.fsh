#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D lightmap;
uniform sampler2D noisetex;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTime;
uniform float frameTimeCounter;
uniform int worldTime;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform int biome_category;

varying vec2 texcoord;
varying float eyeInWater;

#define EYE_ADJUST_NETHER_DARK      2.2
#define EYE_ADJUST_NETHER_LIGHT     1.6
#define NETHER_TARGET_LUMA          0.12
#define NETHER_EXPOSURE_ADAPT_RATE  0.8
#define EXPOSURE_ENCODE_MIN (EYE_ADJUST_NETHER_LIGHT * 0.4)
#define EXPOSURE_ENCODE_MAX EYE_ADJUST_NETHER_DARK

#define BLOOM_THRESHOLD 0.65
#define BLOOM_KNEE 0.30
#define BLOOM_INTENSITY 0.45
#define BLOOM_CORE_BOOST 1.0
#define BLOOM_RADIUS_PX 0.3
#define BLOOM_RADIUS_PX_WIDE 0.8

#define SATURATION 1.15
#define VIBRANCE 0.20
#define CONTRAST 0.15
#define SHARPEN_STRENGTH 0.05

#define NIGHT_HEIGHT_THRESHOLD -0.30

#define AO_RADIUS 0.15
#define AO_STRENGTH 0.40
#define AO_SAMPLES 4
#define AO_BIAS 0.04

#include "/lib/composite_common.glsl"
#include "/lib/composite_post.glsl"
#include "/lib/nether_sky.glsl" 
#include "/lib/nether_fog.glsl" 

float getSSAO(vec2 uv, vec3 viewPos, vec3 normal) {
    float occlusion = 0.0;
    float angle = hash12(uv * viewWidth) * 6.2831853;
    float sa = sin(angle);
    float ca = cos(angle);
    mat2 rot = mat2(ca, -sa, sa, ca);

    for (int i = 0; i < AO_SAMPLES; i++) {
        float a = (float(i) / float(AO_SAMPLES)) * 6.2831853;
        vec2 dir = rot * vec2(cos(a), sin(a));
        float screenRadius = AO_RADIUS * (1.0 / max(-viewPos.z, 1.0)) * 0.05;
        vec2 sampleUV = uv + dir * screenRadius;
        float sampleDepthRaw = texture2D(depthtex0, sampleUV).r;
        if (sampleDepthRaw >= 0.9999) continue;
        vec3 sampleViewPos = getViewPos(sampleUV, sampleDepthRaw);
        vec3 diff = sampleViewPos - viewPos;
        float dist = length(diff);
        vec3 dirToSample = diff / max(dist, 0.0001);
        float rangeCheck = smoothstep(0.0, 1.0, AO_RADIUS / max(dist, 0.0001));
        float NdotD = max(dot(normal, dirToSample) - AO_BIAS, 0.0);
        occlusion += NdotD * rangeCheck;
    }
    occlusion /= float(AO_SAMPLES);
    return 1.0 - clamp(occlusion * AO_STRENGTH, 0.0, 1.0);
}

vec3 applyLavaVision(vec3 sceneColor, float linDepth) {
    float dist = linDepth * far;
    float sceneVisibility = (1.0 - smoothstep(0.0, 4.0, dist)) * 0.35;
    vec3 lavaColor = vec3(0.75, 0.28, 0.06) + 0.03 * sin(frameTimeCounter * 1.5);
    return mix(lavaColor, sceneColor, sceneVisibility);
}

vec3 getWorldRayDir(vec2 uv) {
    vec4 clip = vec4(uv * 2.0 - 1.0, 1.0, 1.0);
    vec4 viewSpace = gbufferProjectionInverse * clip;
    viewSpace /= viewSpace.w;
    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(viewSpace.xyz, 0.0)).xyz);
    return worldDir;
}

float computeNetherExposure() {
    float avgLuma = max(sampleAverageLuminance(), 0.0001);

    float eyeCeiling = mix(EYE_ADJUST_NETHER_DARK, EYE_ADJUST_NETHER_LIGHT, smoothstep(0.02, 0.25, avgLuma));
    float targetExposure = clamp(NETHER_TARGET_LUMA / avgLuma, EYE_ADJUST_NETHER_LIGHT * 0.4, eyeCeiling);

    vec2 historyTexel = vec2(0.5 / viewWidth, 0.5 / viewHeight);
    float lastExposureRaw = texture2D(colortex2, historyTexel).r;
    float lastExposure = decodeExposure(lastExposureRaw);

    float adaptSpeed = clamp(1.0 - exp(-max(frameTime, 0.0001) * NETHER_EXPOSURE_ADAPT_RATE), 0.0, 1.0);
    return mix(lastExposure, targetExposure, adaptSpeed);
}

/* DRAWBUFFERS:02 */

void main() {
    vec3 col       = texture2D(colortex0, texcoord).rgb;
    float rawDepth = texture2D(depthtex0, texcoord).r;
    float linDepth = linearizeDepth(rawDepth);
    bool isSky     = rawDepth >= 0.9999;

    if (eyeInWater > 1.5) {
        col = applyLavaVision(col, linDepth);
    } else {
        if (!isSky) {
            vec3 viewPos = getViewPos(texcoord, rawDepth);

            vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
            float depthL = texture2D(depthtex0, texcoord - vec2(texel.x, 0.0)).r;
            float depthR = texture2D(depthtex0, texcoord + vec2(texel.x, 0.0)).r;
            float depthD = texture2D(depthtex0, texcoord - vec2(0.0, texel.y)).r;
            float depthU = texture2D(depthtex0, texcoord + vec2(0.0, texel.y)).r;

            float depthDelta = max(max(abs(rawDepth - depthL), abs(rawDepth - depthR)),
                                    max(abs(rawDepth - depthD), abs(rawDepth - depthU)));

            bool isEdge = depthDelta > 0.0015;

            float ao = 1.0;
            if (!isEdge) {
                vec3 normal = normalize(cross(dFdx(viewPos), dFdy(viewPos)));
                ao = getSSAO(texcoord, viewPos, normal);
            }
            col *= ao;
        }

        vec3 moodColor = getNetherFogColor(biome_category);

        vec3 worldPos = getStableWorldPos(texcoord, rawDepth);
        col = applyNetherVolumetricFog(col, cameraPosition, worldPos, isSky, moodColor);

        vec3 rayDir = getWorldRayDir(texcoord);
        vec3 netherAtmo = renderNetherAtmosphere(rayDir, frameTimeCounter, biome_category);
        col += netherAtmo * (isSky ? 1.0 : 0.08);
    }

    vec3 bloomContribution = isSky ? vec3(0.0) : getBloomContribution(col, texcoord);
    col = col + bloomContribution;

    float exposure = computeNetherExposure();
    col *= exposure;

    float netherLuma = getLuma(col);
    col = mix(vec3(netherLuma), col, 1.08);
    col = applyContrast(col, CONTRAST);
    col = acesTonemap(col);
    col = applySharpen(col, texcoord);
    col = clamp(col, 0.0, 1.0);

    gl_FragData[0] = vec4(col, 1.0);
    gl_FragData[1] = vec4(encodeExposure(exposure), 0.0, 0.0, 1.0);
}
#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

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
uniform int biome_precipitation;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;
uniform float thunderStrength;
uniform mat4 gbufferProjection;

#include "/distort.glsl"

varying vec2 texcoord;
varying float eyeInWater;

// CONFIGURATION
#define CLOUD_HEIGHT 192.0
#define CLOUD_SCALE 0.02
#define CLOUD_SPEED 0.001
#define CLOUD_WARP_SCALE 0.02
#define CLOUD_WARP_SPEED 0.05
#define CLOUD_COVERAGE 0.48
#define CLOUD_SOFTNESS 0.3
#define CLOUD_MAX_DISTANCE 750.0
#define CLOUD_SHADOW_OFFSET 6.0
#define CLOUD_SHADOW_STRENGTH 0.35
#define CLOUD_RIM_STRENGTH 0.35
      
#define DEBUG_GODRAYS 1

#define RENDER_DISTANCE_FOG_START 100.0  
#define RENDER_DISTANCE_FOG_END   280.0   
#define RENDER_DISTANCE_FOG_INTENSITY 1.0
#define RENDER_DISTANCE_FOG_CURVE 2.0
#define AERIAL_FOG_DENSITY 0.0012   
#define AERIAL_FOG_START 40.0    
#define WEATHER_FOG_DENSITY 0.006
#define WEATHER_FOG_MAX 0.22

#define TARGET_LUMA 0.12
#define EXPOSURE_MIN 0.9
#define EXPOSURE_MAX 1.3
#define EXPOSURE_ADAPT_RATE 1.0
#define NIGHT_TARGET_LUMA_MULT   0.9
#define NIGHT_EXPOSURE_MIN_MULT  0.7
#define NIGHT_EXPOSURE_MAX_MULT  0.9
#define EXPOSURE_ENCODE_MIN (EXPOSURE_MIN * NIGHT_EXPOSURE_MIN_MULT)
#define EXPOSURE_ENCODE_MAX EXPOSURE_MAX

#define BLOOM_THRESHOLD 0.75
#define BLOOM_KNEE 0.35
#define BLOOM_INTENSITY 0.4
#define BLOOM_CORE_BOOST 0.8
#define BLOOM_RADIUS_PX 0.4
#define BLOOM_RADIUS_PX_WIDE 1.2

#define SATURATION 1.4
#define VIBRANCE 0.35
#define CONTRAST 0.15
#define SHARPEN_STRENGTH 0.1

#define DAY_HEIGHT_THRESHOLD 0.40      
#define NIGHT_HEIGHT_THRESHOLD -0.30
#define SKY_ZENITH_BIAS 0.55

#define AO_RADIUS 0.2
#define AO_STRENGTH 0.6
#define AO_SAMPLES 5
#define AO_BIAS 0.03

#ifndef PPT_NONE
#define PPT_NONE 0
#define PPT_RAIN 1
#define PPT_SNOW 2
#endif

// INCLUDES
#include "/lib/composite_common.glsl"
#include "/lib/composite_fog.glsl"
#include "/lib/composite_clouds.glsl"
#include "/lib/composite_underwater.glsl"
#include "/lib/composite_post.glsl"
#include "/lib/godrays.glsl"
#include "/lib/lens_flare.glsl"

// SSAO
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

// LAVA VISION — sama kayak versi End/Nether, tinggal ketinggalan di overworld
vec3 applyLavaVision(vec3 sceneColor, float linDepth) {
    float dist = linDepth * far;
    float sceneVisibility = (1.0 - smoothstep(0.0, 3.0, dist)) * 0.4; 
    vec3 lavaColor = vec3(0.85, 0.32, 0.05) + 0.04 * sin(frameTimeCounter * 2.0);
    return mix(lavaColor, sceneColor, sceneVisibility);
}

/* DRAWBUFFERS:02 */

void main() {
    vec3 col       = texture2D(colortex0, texcoord).rgb;
    float rawDepth = texture2D(depthtex0, texcoord).r;
    float linDepth = linearizeDepth(rawDepth);
    bool isSky     = rawDepth >= 0.9999;

    vec3 sunDir = getSunDirWorld();
    vec3 viewDirVS = getViewPos(texcoord, 0.0);
    vec3 rayDir = normalize((gbufferModelViewInverse * vec4(viewDirVS, 0.0)).xyz);

    if (eyeInWater > 1.5) {
        col = applyLavaVision(col, linDepth);
    } else if (eyeInWater > 0.5) {
        float rawDepth1 = texture2D(depthtex1, texcoord).r;
        bool isWaterToSky = (rawDepth < 0.9999) && (rawDepth1 >= 0.9999);
        vec3 worldPos = getStableWorldPos(texcoord, rawDepth);
        vec3 rayDir = normalize(worldPos - cameraPosition);
        col = applyClearUnderwater(col, texcoord, rawDepth, linDepth, worldPos, isWaterToSky, rayDir, sunDir);
    } else {
        float sceneDist = linDepth * far;
        vec4 clouds = renderClouds(rayDir, cameraPosition, sceneDist, isSky, sunDir);
        col = mix(col, clouds.rgb, clouds.a);

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

        // GOD RAYS 
        vec3 godrays = computeGodRays(texcoord, rawDepth, sunDir);
        col += godrays * (isSky ? 0.0 : 1.0);

        col = applyWeatherFog(col, linDepth, thunderStrength);
        col = applyAerialFog(col, linDepth, isSky, rayDir, sunDir, worldTime, rainStrength);
        col = applyRenderDistanceFog(col, linDepth, isSky, sunDir, worldTime, rainStrength);
    }

    if (eyeInWater <= 0.5) {
        col += computeLensFlare(texcoord, normalize(sunPosition), sunDir, rainStrength, col);
    }

    vec3 bloomContribution = isSky ? vec3(0.0) : getBloomContribution(col, texcoord);
    #if DEBUG_BLOOM
        gl_FragData[0] = vec4(bloomContribution * 5.0, 1.0);
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    #endif

    col = col + bloomContribution;

    float exposure = computeExposure(sunDir);
    col *= exposure;

    col = applyColorGrade(col, sunDir);
    col = acesTonemap(col);
    col = applySharpen(col, texcoord);
    col = clamp(col, 0.0, 1.0);

    gl_FragData[0] = vec4(col, 1.0);
    gl_FragData[1] = vec4(encodeExposure(exposure), 0.0, 0.0, 1.0);
}
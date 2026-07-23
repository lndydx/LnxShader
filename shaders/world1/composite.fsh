#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D lightmap;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTime;
uniform float frameTimeCounter;
uniform int worldTime;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

varying vec2 texcoord;
varying float eyeInWater;

#define TARGET_LUMA 0.075 //[tuning] target rata-rata kecerahan layar
#define EXPOSURE_MIN 0.85 //[tuning]
#define EXPOSURE_MAX 1.15 //[tuning]
#define EXPOSURE_ADAPT_RATE 1.0 //[tuning] kecepatan adaptasi exposure
#define NIGHT_TARGET_LUMA_MULT   0.90
#define NIGHT_EXPOSURE_MIN_MULT  0.70
#define NIGHT_EXPOSURE_MAX_MULT  0.90
#define EXPOSURE_ENCODE_MIN (EXPOSURE_MIN * NIGHT_EXPOSURE_MIN_MULT)
#define EXPOSURE_ENCODE_MAX EXPOSURE_MAX

#define END_AMBIENT_STRENGTH 0.22 //[tuning] fill-light global dari nebula ke terrain, JANGAN dibalikin ke 0.03

#define BLOOM_THRESHOLD 0.55 //[tuning] makin kecil makin gampang mancar bloom
#define BLOOM_KNEE 0.85
#define BLOOM_INTENSITY 1.10 //[tuning] kekuatan bloom keseluruhan
#define BLOOM_CORE_BOOST 2.0
#define BLOOM_RADIUS_PX 0.65
#define BLOOM_RADIUS_PX_WIDE 2.2 //[tuning] radius lebar buat efek halo portal/crystal

#define SATURATION 1.05 //[tuning]
#define VIBRANCE 0.42   //[tuning] saturasi ekstra khusus highlight
#define CONTRAST 0.05   //[tuning] jaga rendah biar gak "keras" kayak vanilla
#define SHARPEN_STRENGTH 0.0

#define NIGHT_HEIGHT_THRESHOLD -0.30

#define AO_RADIUS 0.2
#define AO_STRENGTH 0.0
#define AO_SAMPLES 5
#define AO_BIAS 0.03

#define END_FOG_DENSITY 0.0014        //[tuning] densitas fog jarak
#define END_FOG_HEIGHT_FALLOFF 0.015  //[tuning] makin besar makin cepat fog menipis ke atas
#define END_FOG_HEIGHT_REF 40.0       //[tuning] ketinggian dunia acuan fog paling pekat
#define END_FOG_MAX 0.90              //[tuning] opacity maksimum fog
#define END_FOG_SKY_BLEND 0.5         //[tuning] seberapa jauh fog nyampur ke langit di horizon

#include "/lib/end_palette.glsl"
#include "/lib/end_sky.glsl"
#include "/lib/composite_common.glsl"
#include "/lib/composite_underwater.glsl"
#include "/lib/composite_post.glsl"

vec3 calcEndSkyFull(vec3 worldDir) {
    float t = clamp(worldDir.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 baseSky = mix(SKY_HORIZON, SKY_MID, smoothstep(0.0, 0.45, t));
    baseSky = mix(baseSky, SKY_ZENITH, smoothstep(0.45, 1.0, t));
    vec3 endEffects = renderEndSky(worldDir, frameTimeCounter);
    return baseSky + endEffects;
}

vec3 applyEndColorGrade(vec3 col) {
    float luma = getLuma(col);
    col = mix(vec3(luma), col, SATURATION);
    col = applyVibrance(col, VIBRANCE);
    col = applyContrast(col, CONTRAST);
    return col;
}

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

vec3 reconstructWorldDir(vec2 uv) {
    vec4 clip = vec4(uv * 2.0 - 1.0, 1.0, 1.0);
    vec4 viewDir = gbufferProjectionInverse * clip;
    vec3 dir = normalize((gbufferModelViewInverse * vec4(viewDir.xyz, 0.0)).xyz);
    return dir;
}

vec3 applyEndVoidFog(vec3 col, float linDepth, bool isSky, vec3 worldDir, vec3 worldPos) {
    float heightDensity = exp(-max(worldPos.y - END_FOG_HEIGHT_REF, 0.0) * END_FOG_HEIGHT_FALLOFF);
    vec3 fogColor = mix(FOG_FAR, FOG_NEAR, 0.4);

    if (isSky) {
        float horizonFactor = 1.0 - smoothstep(0.0, END_FOG_SKY_BLEND, abs(worldDir.y));
        return mix(col, fogColor, horizonFactor * 0.45);
    }

    float realDistance = linDepth * far;
    float fogFactor = (1.0 - exp(-realDistance * END_FOG_DENSITY)) * mix(0.5, 1.0, heightDensity);
    fogFactor = clamp(fogFactor, 0.0, END_FOG_MAX);

    return mix(col, fogColor, fogFactor);
}

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
    vec3 endGradeDir = vec3(0.0, -1.0, 0.0);
    vec3 worldPos = getStableWorldPos(texcoord, rawDepth);

    if (eyeInWater > 1.5) {
        col = applyLavaVision(col, linDepth);
    } else if (eyeInWater > 0.5) {
        float rawDepth1 = texture2D(depthtex1, texcoord).r;
        bool isWaterToSky = (rawDepth < 0.9999) && (rawDepth1 >= 0.9999);
        vec3 rayDir = normalize(worldPos - cameraPosition);
        col = applyClearUnderwater(col, texcoord, rawDepth, linDepth, worldPos, isWaterToSky, rayDir, sunDir);
    } else {
        vec3 worldDir = reconstructWorldDir(texcoord);

        if (!isSky) {
            vec3 viewPos = getViewPos(texcoord, rawDepth);
            vec3 viewNormal = normalize(cross(dFdx(viewPos), dFdy(viewPos)));

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
                ao = getSSAO(texcoord, viewPos, viewNormal);
            }
            col *= ao;

            vec3 worldNormal = normalize((gbufferModelViewInverse * vec4(viewNormal, 0.0)).xyz);
            float skyFacing = clamp(worldNormal.y * 0.5 + 0.5, 0.0, 1.0);
            vec3 ambientCol = mix(FOG_FAR, AMBIENT_LIGHT, skyFacing);
            col += ambientCol * END_AMBIENT_STRENGTH * ao;
        } else {
            col = calcEndSkyFull(worldDir);
        }

        col = applyEndVoidFog(col, linDepth, isSky, worldDir, worldPos);
    }

    vec3 bloomContribution = isSky ? vec3(0.0) : getBloomContribution(col, texcoord);
    col = col + bloomContribution * BLOOM_TINT;

    float exposure = computeExposure(sunDir);
    col *= exposure;

    col = applyEndColorGrade(col);
    col = acesTonemap(col);
    
    col = applySharpen(col, texcoord);  
    
    col = clamp(col, 0.0, 1.0);

    gl_FragData[0] = vec4(col, 1.0);
    gl_FragData[1] = vec4(encodeExposure(exposure), 0.0, 0.0, 1.0);
}
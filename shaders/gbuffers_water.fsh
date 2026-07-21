#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float alphaTestRef = 0.1;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 sunPosition;
uniform int worldTime;
uniform float rainStrength;
uniform int isEyeInWater;
uniform sampler2D shadowtex1;
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying vec3 flatNormal;
varying float isRealWater;
varying vec4 shadowPos;
varying vec2 waterWorldXZ;

const bool shadowtex1Nearest = true;

#include "/distort.glsl"
#include "/lib/ggx.glsl"

#define WATER_SPECULAR_ROUGHNESS 0.20
#define WATER_SPECULAR_INTENSITY 8.0

#define STORM_WATER_COLOR vec3(0.34, 0.38, 0.4)
#define DAY_HEIGHT_THRESHOLD 0.5
#define NIGHT_HEIGHT_THRESHOLD -0.3

float waveHeight(vec2 pos, float t) {
    return sin(pos.x * 0.8 + pos.y * 0.5 + t * 1.2) * 0.09
         + sin(pos.x * 1.3 - pos.y * 1.1 + t * 0.9) * 0.05;
}

vec2 microRippleOffset(vec2 pos, float t) {
    vec2 offset = vec2(0.0);

    offset += vec2( 0.83,  0.55) * sin(dot(pos, vec2( 0.83,  0.55)) * 4.7 + t * 2.3);
    offset += vec2(-0.42,  0.91) * sin(dot(pos, vec2(-0.42,  0.91)) * 7.1 - t * 1.7 + 1.3);
    offset += vec2( 0.65, -0.76) * sin(dot(pos, vec2( 0.65, -0.76)) * 5.9 + t * 3.1 + 4.2);
    offset += vec2(-0.95, -0.31) * sin(dot(pos, vec2(-0.95, -0.31)) * 9.3 - t * 2.6 + 2.1);

    return offset * 0.25;
}

vec3 skyColorByWorldTime(int wt, float sunHeight, float rain) {
    vec3 night   = vec3(0.26, 0.28, 0.53);
    vec3 sunrise = vec3(0.60, 0.76, 0.95);
    vec3 day     = vec3(0.45, 0.70, 0.98);
    vec3 noon    = vec3(0.42, 0.68, 1.00);
    vec3 sunset  = vec3(0.62, 0.68, 0.90);

    bool isMorning = wt < 12000;
    vec3 horizonCol = isMorning ? sunrise : sunset;

    float dayFactor   = smoothstep(0.0, DAY_HEIGHT_THRESHOLD, sunHeight);
    float noonFactor  = smoothstep(DAY_HEIGHT_THRESHOLD, 1.0, sunHeight);
    float nightFactor = smoothstep(0.0, NIGHT_HEIGHT_THRESHOLD, sunHeight);

    vec3 skyCol = mix(horizonCol, day, dayFactor);
    skyCol = mix(skyCol, noon, noonFactor);
    skyCol = mix(skyCol, night, nightFactor);

    skyCol = mix(skyCol, STORM_WATER_COLOR, rain);
    return skyCol;
}

vec3 waterTintByTime(float sunHeight, int wt) {
    vec3 night   = vec3(0.15, 0.28, 0.45);      
    vec3 sunrise = vec3(0.28, 0.38, 0.40);     
    vec3 day     = vec3(0.02, 0.55, 0.60);      
    vec3 sunset  = vec3(0.42, 0.46, 0.58);

    bool isMorning = wt < 12000;
    vec3 horizonCol = isMorning ? sunrise : sunset;

    float dayFactor   = smoothstep(0.0, DAY_HEIGHT_THRESHOLD, sunHeight);
    float nightFactor = smoothstep(0.0, NIGHT_HEIGHT_THRESHOLD, sunHeight);

    vec3 tint = mix(horizonCol, day, dayFactor);
    tint = mix(tint, night, nightFactor);
    return tint;
}

/* DRAWBUFFERS:01 */

void main() {
    vec4 baseColor = texture2D(texture, texcoord) * glcolor;

    if (baseColor.a < alphaTestRef) {
        discard;
    }

    vec3 lm = texture2D(lightmap, lmcoord).rgb;

    if (isRealWater < 0.5) {
        gl_FragData[0] = vec4(baseColor.rgb * lm, baseColor.a);
        gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
        return;
    }

    vec3 sunDirView  = normalize(sunPosition);
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunHeight  = sunDirWorld.y;

    float baseLuma = dot(baseColor.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desatBase = mix(baseColor.rgb, vec3(baseLuma), 0.10);
    vec3 clearTint = desatBase * waterTintByTime(sunHeight, worldTime);

    vec3 partialDesat = mix(baseColor.rgb, vec3(baseLuma), 0.5);
    vec3 stormTint = mix(partialDesat, STORM_WATER_COLOR, 0.45);
    baseColor.rgb  = mix(clearTint, stormTint, rainStrength);

    vec3 viewDir = normalize(viewPos);

    vec3 geoNormal = normalize(flatNormal);
    if (dot(geoNormal, viewDir) > 0.0) geoNormal = -geoNormal;

    vec3 worldFlatNormal = normalize((gbufferModelViewInverse * vec4(geoNormal, 0.0)).xyz);
    bool isHorizontalSurface = abs(worldFlatNormal.y) > 0.5;

    vec3 N = normalize(viewNormal);
    if (isHorizontalSurface) {
        float t = frameTimeCounter;
        vec2 wavePos = mod(waterWorldXZ, 8192.0);
        float eps = 0.15;
        float hL = waveHeight(wavePos - vec2(eps, 0.0), t);
        float hR = waveHeight(wavePos + vec2(eps, 0.0), t);
        float hD = waveHeight(wavePos - vec2(0.0, eps), t);
        float hU = waveHeight(wavePos + vec2(0.0, eps), t);
        vec3 waveNormalWorld = normalize(vec3((hL - hR) / (2.0 * eps), 1.0, (hD - hU) / (2.0 * eps)));
        N = normalize(mat3(gbufferModelView) * waveNormalWorld);
        vec2 ripple = microRippleOffset(waterWorldXZ, t);
        N = normalize(N + vec3(ripple.x, 0.0, ripple.y) * 0.14);
    }

    vec3 skyCol = skyColorByWorldTime(worldTime, sunHeight, rainStrength);
    vec3 skyColClamped = max(skyCol, vec3(0.05, 0.06, 0.09));

    vec3 reflectionColor;
    if (isEyeInWater == 0) {
        vec3 reflectDir = reflect(viewDir, geoNormal);
        vec3 worldReflectDir = normalize((gbufferModelViewInverse * vec4(reflectDir, 0.0)).xyz);

        reflectionColor = mix(skyColClamped * 0.55, skyColClamped * 0.70, clamp(worldReflectDir.y * 0.5 + 0.5, 0.0, 1.0));
    } else {
        reflectionColor = skyColClamped * 0.45;
    }

    float cosView = clamp(dot(-viewDir, N), 0.0, 1.0);
    float F0 = 0.02;
    float fresnel = fresnelSchlick(cosView, vec3(F0)).r;

    float lmLuma = dot(lm, vec3(0.299, 0.587, 0.114));
    float lmNightFactor = smoothstep(0.0, NIGHT_HEIGHT_THRESHOLD, sunHeight);
    vec3 lmNeutral = mix(lm, vec3(lmLuma), 0.02 * lmNightFactor);

    float skyVisibility = clamp(lmcoord.y, 0.0, 1.0);

    vec3 caveAmbient = baseColor.rgb * 0.35;
    vec3 ambientReflection = mix(caveAmbient, reflectionColor, skyVisibility);

    float verticalness = 1.0 - abs(worldFlatNormal.y);

    float reflectWeight = fresnel * float(isEyeInWater == 0);
    reflectWeight = max(reflectWeight, mix(0.0, 0.15, verticalness) * float(isEyeInWater == 0));

    vec3 finalColor = mix(baseColor.rgb * lmNeutral, ambientReflection, reflectWeight);
    vec3 sunSpecular = ggxSpecular(N, -viewDir, sunDirView, WATER_SPECULAR_ROUGHNESS, vec3(F0));
    float sunVisible = smoothstep(-0.05, 0.05, sunDirWorld.y) * skyVisibility * float(isEyeInWater == 0);
    finalColor += sunSpecular * WATER_SPECULAR_INTENSITY * sunVisible;

    #ifdef SHADOWS
    float shadow = 1.0;
    if (shadowPos.w > 0.0) {
        if (texture2D(shadowtex1, shadowPos.xy).r < shadowPos.z) {
            shadow = SHADOW_BRIGHTNESS;
        }
    } else {
        shadow = SHADOW_BRIGHTNESS;
    }
    finalColor *= mix(1.0, shadow, skyVisibility);
    #endif

    float caveAlphaReduce = mix(0.15, 0.0, skyVisibility);
    float finalAlpha = clamp((0.32 - rainStrength * 0.05) + fresnel * 0.55 - caveAlphaReduce, 0.0, 1.0);

    if (isEyeInWater == 1) {
        vec3 worldRayDir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
        float rayY = worldRayDir.y;

        const float SNELL_COS = 0.6626;
        const float SNELL_SOFTNESS = 0.12;
        float withinWindow = smoothstep(SNELL_COS - SNELL_SOFTNESS, SNELL_COS + SNELL_SOFTNESS, rayY);
        float snellOpacity = (1.0 - withinWindow) * 0.55;
        finalAlpha = max(finalAlpha, snellOpacity);
    }

    gl_FragData[0] = vec4(finalColor, finalAlpha);

    vec3 ssrNormal = normalize(mix(flatNormal, N, 0.25));
    gl_FragData[1] = vec4(ssrNormal * 0.5 + 0.5, float(isEyeInWater == 0));
}
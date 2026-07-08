#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float alphaTestRef = 0.1;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform int worldTime;
uniform float rainStrength;
uniform int isEyeInWater;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying vec3 flatNormal;
varying float isRealWater;

#define STORM_WATER_COLOR vec3(0.34, 0.38, 0.4)
#define DAY_HEIGHT_THRESHOLD 0.5
#define NIGHT_HEIGHT_THRESHOLD -0.3

vec3 skyColorByWorldTime(int wt, float sunHeight, float rain) {
    vec3 night   = vec3(0.03, 0.03, 0.045);
    vec3 sunrise = vec3(0.90, 0.55, 0.40);
    vec3 day     = vec3(0.55, 0.75, 0.95);
    vec3 noon    = vec3(0.42, 0.68, 1.00);
    vec3 sunset  = vec3(0.85, 0.45, 0.35);

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
    vec3 night   = vec3(0.05, 0.09, 0.11);
    vec3 sunrise = vec3(0.30, 0.34, 0.32);
    vec3 day     = vec3(0.10, 0.34, 0.36);
    vec3 sunset  = vec3(0.26, 0.30, 0.28);

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
        gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0); // bukan air -> flag SSR = 0
        return;
    }

    vec3 sunDirView  = normalize(sunPosition);
    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunHeight  = sunDirWorld.y;

    float baseLuma = dot(baseColor.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desatBase = mix(baseColor.rgb, vec3(baseLuma), 0.20);
    vec3 clearTint = desatBase * waterTintByTime(sunHeight, worldTime);

    vec3 partialDesat = mix(baseColor.rgb, vec3(baseLuma), 0.5);
    vec3 stormTint = mix(partialDesat, STORM_WATER_COLOR, 0.45);
    baseColor.rgb  = mix(clearTint, stormTint, rainStrength);

    vec3 N = normalize(viewNormal);
    vec3 viewDir = normalize(viewPos);

    vec3 skyCol = skyColorByWorldTime(worldTime, sunHeight, rainStrength);
    vec3 skyColClamped = max(skyCol, vec3(0.05, 0.06, 0.09));

    vec3 reflectionColor;
    if (isEyeInWater == 0) {
        vec3 reflectDir = reflect(viewDir, flatNormal);
        vec3 worldReflectDir = normalize((gbufferModelViewInverse * vec4(reflectDir, 0.0)).xyz);

        reflectionColor = mix(skyColClamped * 0.45, skyColClamped * 0.80, clamp(worldReflectDir.y * 0.5 + 0.5, 0.0, 1.0));
    } else {
        reflectionColor = skyColClamped * 0.45;
    }

    float fresnel = pow(1.0 - clamp(dot(-viewDir, N), 0.0, 1.0), 3.0);
    fresnel = clamp(fresnel * 0.85 + 0.15, 0.0, 1.0);

    float lmLuma = dot(lm, vec3(0.299, 0.587, 0.114));
    float lmNightFactor = smoothstep(0.0, NIGHT_HEIGHT_THRESHOLD, sunHeight);
    vec3 lmNeutral = mix(lm, vec3(lmLuma), 0.02 * lmNightFactor);

    float skyVisibility = clamp(lmcoord.y, 0.0, 1.0);

    vec3 caveAmbient = baseColor.rgb * 0.35;
    vec3 ambientReflection = mix(caveAmbient, reflectionColor, skyVisibility);

    float reflectWeight = fresnel * float(isEyeInWater == 0);
    vec3 finalColor = mix(baseColor.rgb * lmNeutral, ambientReflection, reflectWeight);

    float caveAlphaReduce = mix(0.15, 0.0, skyVisibility);
    float finalAlpha = clamp((0.5 - rainStrength * 0.05) + fresnel * 0.40 - caveAlphaReduce, 0.0, 1.0);

    vec3 halfDir = normalize(sunDirView - viewDir);
    float spec = max(dot(N, halfDir), 0.0);

    float specularHighlight = pow(spec, 50.0);
    vec3 specularColor = vec3(1.0, 1.0, 0.9) * 1.0;
    if (sunHeight < NIGHT_HEIGHT_THRESHOLD) {
        specularColor = vec3(0.35, 0.38, 0.4) * 0.6;
    }
    specularColor *= (1.0 - rainStrength * 0.7);


    gl_FragData[0] = vec4(finalColor, finalAlpha);

    vec3 ssrNormal = normalize(mix(flatNormal, N, 0.25));
    gl_FragData[1] = vec4(ssrNormal * 0.5 + 0.5, float(isEyeInWater == 0));
}
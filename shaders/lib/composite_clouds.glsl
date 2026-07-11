#ifndef COMPOSITE_CLOUDS_GLSL
#define COMPOSITE_CLOUDS_GLSL

float cloudHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float cloudNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = cloudHash(i);
    float b = cloudHash(i + vec2(1.0, 0.0));
    float c = cloudHash(i + vec2(0.0, 1.0));
    float d = cloudHash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float cloudFbm(vec2 p) {
    float value = 0.0;
    float amp = 0.5;
    float ampSum = 0.0;
    for (int i = 0; i < 4; i++) {
        value += amp * cloudNoise(p);
        ampSum += amp;
        p = p * 2.15 + vec2(37.1, 91.7);
        amp *= 0.5;
    }
    return value / ampSum;
}

// --- REVISED: vibrant, matching Complementary ---
vec3 cloudColorByTime(vec3 sunDir, int wt, float rain) {
    vec3 night   = vec3(0.10, 0.11, 0.17);
    vec3 sunrise = vec3(1.00, 0.62, 0.45);  // warm peach-pink
    vec3 day     = vec3(0.96, 0.98, 1.00);  // cool white
    vec3 sunset  = vec3(1.00, 0.55, 0.32);  // deep orange

    float h = sunDir.y;
    bool isMorning = wt < 12000;
    vec3 horizonCol = isMorning ? sunrise : sunset;

    float dayFactor   = smoothstep(0.0, DAY_HEIGHT_THRESHOLD, h);
    float nightFactor = smoothstep(0.0, NIGHT_HEIGHT_THRESHOLD, h);

    vec3 col = mix(horizonCol, day, dayFactor);
    col = mix(col, night, nightFactor);

    bool isNight = h < NIGHT_HEIGHT_THRESHOLD;
    vec3 stormCol = isNight ? vec3(0.05, 0.05, 0.07) : vec3(0.30, 0.31, 0.34);
    return mix(col, stormCol, rain * 0.85);
}

vec4 renderClouds(vec3 rayDir, vec3 rayOrigin, float sceneDist, bool isSky, vec3 sunDir) {
    float grazingFade = smoothstep(0.0, 0.12, rayDir.y);
    if (grazingFade <= 0.0) return vec4(0.0);

    float t = (CLOUD_HEIGHT - rayOrigin.y) / max(rayDir.y, 0.0001);
    if (t <= 0.0) return vec4(0.0);

    float occlusionFade = isSky ? 1.0 : (1.0 - smoothstep(sceneDist * 0.75, sceneDist, t));
    if (occlusionFade <= 0.0) return vec4(0.0);

    vec3 hitPos = rayOrigin + rayDir * t;
    vec2 basePos = hitPos.xz * CLOUD_SCALE;
    vec2 timeOffset = vec2(frameTimeCounter * CLOUD_SPEED, frameTimeCounter * CLOUD_SPEED * 0.6);

    vec2 warpPos = hitPos.xz * CLOUD_WARP_SCALE + frameTimeCounter * CLOUD_WARP_SPEED;
    vec2 warp = vec2(cloudFbm(warpPos), cloudFbm(warpPos + vec2(19.3, 4.7))) - 0.5;

    vec2 shapeSamplePos = basePos + timeOffset + warp * 1.6;
    float shape  = cloudFbm(shapeSamplePos);
    float detail = cloudFbm(basePos * 3.3 + timeOffset * 1.6 + warp * 0.6);

    float density = mix(shape, detail, 0.35);
    density = smoothstep(CLOUD_COVERAGE, CLOUD_COVERAGE + CLOUD_SOFTNESS, density);
    density = pow(density, 0.55);

    float horizonFade = clamp(1.0 - (t / CLOUD_MAX_DISTANCE), 0.0, 1.0);
    density *= horizonFade * grazingFade * occlusionFade;

    vec2 shadowSamplePos = shapeSamplePos + sunDir.xz * CLOUD_SHADOW_OFFSET * CLOUD_SCALE;
    float shadowShape = cloudFbm(shadowSamplePos);
    float shadowDensity = smoothstep(CLOUD_COVERAGE, CLOUD_COVERAGE + CLOUD_SOFTNESS, shadowShape);

    float cloudLight = 1.0 - clamp(shadowDensity - shape, 0.0, 1.0) * CLOUD_SHADOW_STRENGTH;

    float sunDot = max(dot(rayDir, sunDir), 0.0);
    float rimLight = pow(sunDot, 4.0) * CLOUD_RIM_STRENGTH;

    vec3 timeColor = cloudColorByTime(sunDir, worldTime, rainStrength);
    vec3 cloudColor = mix(vec3(0.55, 0.57, 0.62), vec3(1.0), density) * timeColor * cloudLight;
    cloudColor += vec3(1.0, 0.85, 0.65) * rimLight * density;

    return vec4(cloudColor, clamp(density, 0.0, 1.0));
}

#endif
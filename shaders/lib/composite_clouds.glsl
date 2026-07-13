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

vec3 cloudColorByTime(vec3 sunDir, int wt_, float rain) {
    float wt = float(wt_);

    vec3 dawnCloud     = vec3(0.80, 0.62, 0.42);  
    vec3 sunriseCloud  = vec3(0.90, 0.80, 0.58); 
    vec3 dayCloud      = vec3(0.88, 0.91, 1.00);  
    vec3 sunsetCloud   = vec3(0.796, 0.702, 0.502);
    vec3 nightCloud    = vec3(0.30, 0.28, 0.30); 
    vec3 midnightCloud = vec3(0.08, 0.09, 0.13);  

    vec3 col = sunriseCloud;
    col = mix(col, dayCloud,      smoothstep(0.0,     1000.0, wt));
    col = mix(col, sunsetCloud,   smoothstep(11000.0, 12000.0, wt));
    col = mix(col, nightCloud,    smoothstep(12000.0, 13000.0, wt));
    col = mix(col, midnightCloud, smoothstep(13000.0, 13500.0, wt)); 
    col = mix(col, dawnCloud,     smoothstep(22500.0, 23200.0, wt)); 
    col = mix(col, sunriseCloud,  smoothstep(23000.0, 23800.0, wt));

    bool isNight = sunDir.y < -0.30;
    vec3 stormCol = isNight ? vec3(0.05, 0.05, 0.07) : vec3(0.30, 0.31, 0.34);
    return mix(col, stormCol, rain * 0.85);
}

vec3 cloudAmbientColor(vec3 sunDir, int wt_, float rain) {
    float wt = float(wt_);

    vec3 dawnAmb     = vec3(0.14, 0.11, 0.10);  
    vec3 sunriseAmb  = vec3(0.16, 0.13, 0.11);  
    vec3 dayAmb      = vec3(0.20, 0.30, 0.45);  
    vec3 sunsetAmb   = vec3(0.15, 0.10, 0.08);  
    vec3 nightAmb    = vec3(0.06, 0.06, 0.08); 
    vec3 midnightAmb = vec3(0.02, 0.02, 0.05);  

    vec3 amb = sunriseAmb;
    amb = mix(amb, dayAmb,      smoothstep(0.0,     1000.0, wt));
    amb = mix(amb, sunsetAmb,   smoothstep(11000.0, 12000.0, wt));
    amb = mix(amb, nightAmb,    smoothstep(12000.0, 13000.0, wt));
    amb = mix(amb, midnightAmb, smoothstep(13000.0, 13500.0, wt)); 
    amb = mix(amb, dawnAmb,     smoothstep(22500.0, 23200.0, wt)); 
    amb = mix(amb, sunriseAmb,  smoothstep(23000.0, 23800.0, wt));

    vec3 stormAmb = vec3(0.08, 0.09, 0.11);
    return mix(amb, stormAmb, rain * 0.7);
}

vec4 renderClouds(vec3 rayDir, vec3 rayOrigin, float sceneDist, bool isSky, vec3 sunDir) {
    float grazingFade = smoothstep(0.0, 0.12, abs(rayDir.y)); 
    if (grazingFade <= 0.0) return vec4(0.0);
    if (abs(rayDir.y) < 0.0001) return vec4(0.0);

    float t = (CLOUD_HEIGHT - rayOrigin.y) / rayDir.y; 
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
    float rimLight = pow(sunDot, 3.0) * CLOUD_RIM_STRENGTH * 2.0;

    vec3 timeColor = cloudColorByTime(sunDir, worldTime, rainStrength);
    vec3 ambientColor = cloudAmbientColor(sunDir, worldTime, rainStrength);

    vec3 shadowedCol = mix(vec3(0.18, 0.20, 0.24), ambientColor, 0.6);
    vec3 litCol = timeColor;

    vec3 cloudColor = mix(shadowedCol, litCol, cloudLight);

    vec3 rimColor = vec3(1.0, 0.75, 0.45) * (sunDir.y > 0.0 ? 1.0 : 0.7);
    cloudColor += rimColor * rimLight * density;

    return vec4(cloudColor, clamp(density, 0.0, 1.0));
}

#endif
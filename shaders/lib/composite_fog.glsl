#ifndef COMPOSITE_FOG_GLSL
#define COMPOSITE_FOG_GLSL

vec3 applyRenderDistanceFog(vec3 col, float linDepth, bool isSky) {
    if (isSky) return col;
    float realDistance = linDepth * far;
    float fogFactor = clamp((realDistance - fogStart) / max(fogEnd - fogStart, 0.001), 0.0, 1.0);
    fogFactor = pow(fogFactor, RENDER_DISTANCE_FOG_CURVE) * RENDER_DISTANCE_FOG_INTENSITY;
    return mix(col, fogColor, fogFactor);
}

vec3 aerialFogColorByTime(vec3 sunDir, int wt, float rain) {
    // --- REVISED: vibrant, matching Complementary ---
    vec3 night = vec3(0.06, 0.06, 0.16);
    vec3 dawn  = vec3(1.00, 0.72, 0.55);  // warm peach
    vec3 day   = vec3(0.76, 0.86, 0.96);  // light cyan-blue
    vec3 dusk  = vec3(0.96, 0.68, 0.48);  // warm coral

    float h = sunDir.y;
    bool isMorning = wt < 12000;
    vec3 horizonCol = isMorning ? dawn : dusk;

    float dayFactor   = smoothstep(0.0, DAY_HEIGHT_THRESHOLD, h);
    float nightFactor = smoothstep(0.0, NIGHT_HEIGHT_THRESHOLD, h);

    vec3 col = mix(horizonCol, day, dayFactor);
    col = mix(col, night, nightFactor);

    bool isNight = h < NIGHT_HEIGHT_THRESHOLD;
    vec3 stormCol = isNight ? vec3(0.04, 0.04, 0.07) : vec3(0.42, 0.44, 0.48);
    return mix(col, stormCol, rain * 0.7);
}

vec3 applyAerialFog(vec3 col, float linDepth, bool isSky, vec3 rayDir, vec3 sunDir) {
    if (isSky) return col;
    float realDistance = linDepth * far;
    float fogFactor = 1.0 - exp(-max(realDistance - AERIAL_FOG_START, 0.0) * AERIAL_FOG_DENSITY);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
    vec3 fogCol = aerialFogColorByTime(sunDir, worldTime, rainStrength);
    return mix(col, fogCol, fogFactor);
}

vec3 applyWeatherFog(vec3 col, float linDepth) {
    if (biome_precipitation != PPT_RAIN || rainStrength <= 0.001) return col;
    float realDistance = linDepth * far;
    float fogFactor = 1.0 - exp(-realDistance * WEATHER_FOG_DENSITY * rainStrength);
    fogFactor = clamp(fogFactor, 0.0, WEATHER_FOG_MAX) * pow(rainStrength, 1.5);
    vec3 weatherFogColor = vec3(0.32, 0.42, 0.48);
    return mix(col, weatherFogColor, fogFactor);
}

#endif
#ifndef COMPOSITE_FOG_GLSL
#define COMPOSITE_FOG_GLSL

vec3 getHorizonColorByTime(vec3 sunDir, int wt_, float rain) {
    float wt = float(wt_);

    vec3 dawnFog     = vec3(0.72, 0.54, 0.38);  
    vec3 sunriseFog  = vec3(0.80, 0.71, 0.52);  
    vec3 dayFog      = vec3(0.62, 0.76, 0.87);  
    vec3 sunsetFog   = vec3(0.68, 0.40, 0.24);
    vec3 nightFog    = vec3(0.34, 0.32, 0.34); 
    vec3 midnightFog = vec3(0.13, 0.24, 0.28); 

    vec3 col = sunriseFog;
    col = mix(col, dayFog,      smoothstep(0.0,     1000.0, wt));
    col = mix(col, sunsetFog,   smoothstep(11000.0, 12000.0, wt));
    col = mix(col, nightFog,    smoothstep(12000.0, 13000.0, wt));
    col = mix(col, midnightFog, smoothstep(13000.0, 13500.0, wt)); 
    col = mix(col, dawnFog,     smoothstep(22500.0, 23200.0, wt)); 
    col = mix(col, sunriseFog,  smoothstep(23000.0, 23800.0, wt));

    bool isNight = sunDir.y < -0.30;
    vec3 stormCol = isNight ? vec3(0.03, 0.03, 0.05) : vec3(0.38, 0.40, 0.43);
    return mix(col, stormCol, rain * 0.75);
}

vec3 applyRenderDistanceFog(vec3 col, float linDepth, bool isSky, vec3 sunDir, int wt, float rain) {
    if (isSky) return col;
    float realDistance = linDepth * far;
    float fogFactor = clamp((realDistance - fogStart) / max(fogEnd - fogStart, 0.001), 0.0, 1.0);
    fogFactor = pow(fogFactor, RENDER_DISTANCE_FOG_CURVE) * RENDER_DISTANCE_FOG_INTENSITY;
    
    vec3 fogCol = getHorizonColorByTime(sunDir, wt, rain);
    return mix(col, fogCol, fogFactor);
}

vec3 aerialFogColorByTime(vec3 sunDir, int wt, float rain) {
    return getHorizonColorByTime(sunDir, wt, rain);
}

vec3 applyAerialFog(vec3 col, float linDepth, bool isSky, vec3 rayDir, vec3 sunDir, int wt, float rain) {
    if (isSky) return col;
    float realDistance = linDepth * far;
    
    float fogFactor = 1.0 - exp(-max(realDistance - AERIAL_FOG_START, 0.0) * AERIAL_FOG_DENSITY);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
    
    float heightFactor = exp(-max(cameraPosition.y - 62.0, 0.0) * 0.008);
    fogFactor = mix(fogFactor, min(fogFactor * 1.5, 1.0), heightFactor * 0.6);
    
    vec3 fogCol = aerialFogColorByTime(sunDir, wt, rain);
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
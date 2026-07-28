#ifndef NETHER_FOG_GLSL
#define NETHER_FOG_GLSL

#define NETHER_FOG_NEAR         8.0    
#define NETHER_FOG_HORIZON      150.0  
#define NETHER_FOG_CURVE        1.6   
#define NETHER_FOG_MAX_OPACITY  0.96   

#define NETHER_FOG_PATCH_SCALE    1.2
#define NETHER_FOG_PATCH_SPEED    vec2(0.015, 0.013)
#define NETHER_FOG_PATCH_STRENGTH 0.15 

vec3 applyFogPatchiness(vec3 fogColor) {
    vec2 uv = frameTimeCounter * NETHER_FOG_PATCH_SPEED * NETHER_FOG_PATCH_SCALE;
    float n = texture2D(noisetex, uv).r;
    n = n * n - 0.15;
    if (n <= 0.0) return fogColor;
    vec3 brightFog = fogColor * (1.0 + n * 0.4);
    return mix(fogColor, brightFog, NETHER_FOG_PATCH_STRENGTH);
}

vec3 applyNetherVolumetricFog(vec3 col, vec3 camPos, vec3 worldPos, bool isSky, vec3 moodColor) {
    vec3 fogColor = applyFogPatchiness(moodColor);

    if (isSky) {
        return mix(col, fogColor, NETHER_FOG_MAX_OPACITY);
    }

    float dist = length(worldPos - camPos);
    float t = clamp((dist - NETHER_FOG_NEAR) / (NETHER_FOG_HORIZON - NETHER_FOG_NEAR), 0.0, 1.0);
    float fogFactor = pow(t, NETHER_FOG_CURVE) * NETHER_FOG_MAX_OPACITY;

    return mix(col, fogColor, fogFactor);
}

#endif
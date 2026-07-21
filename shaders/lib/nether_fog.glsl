#ifndef NETHER_FOG_GLSL
#define NETHER_FOG_GLSL

#define NETHER_FOG_STEPS 10
#define NETHER_FOG_MAX_DIST 190.0
#define NETHER_FOG_NOISE_SCALE 0.045
#define NETHER_FOG_DRIFT_SPEED 0.015
#define NETHER_FOG_DENSITY_MULT 0.015
#define NETHER_FOG_MAX_OPACITY 0.68
#define NETHER_FOG_WARM_LOW 0.15
#define NETHER_FOG_WARM_HIGH 0.60
#define NETHER_FOG_WARM_MIX 0.20
#define NETHER_FOG_WARM_COLOR vec3(0.369, 0.165, 0.012)

#define NETHER_FOG_PATCH_SCALE    1.0
#define NETHER_FOG_PATCH_SPEED    vec2(0.021, 0.019)
#define NETHER_FOG_PATCH_STRENGTH 0.5

vec3 applyFogPatchiness(vec3 fogColor) {
    vec2 uv = frameTimeCounter * NETHER_FOG_PATCH_SPEED * NETHER_FOG_PATCH_SCALE;
    float n = texture2D(noisetex, uv).r;
    n = n * n - 0.1;
    if (n <= 0.0) return fogColor;

    vec3 brightFog = vec3(
        fogColor.r * (n + 1.0),
        mix(fogColor.g, max(fogColor.r, fogColor.b * 2.0), n),
        fogColor.b
    );
    return mix(fogColor, brightFog, NETHER_FOG_PATCH_STRENGTH);
}

vec3 applyNetherVolumetricFog(vec3 col, vec3 camPos, vec3 worldPos, bool isSky, vec3 moodColor) {
    if (isSky) return col;

    vec3 rayVec  = worldPos - camPos;
    float fullDist = length(rayVec);
    float rayLen   = min(fullDist, NETHER_FOG_MAX_DIST);
    vec3 rayDir    = rayVec / max(fullDist, 0.0001);

    float stepSize = rayLen / float(NETHER_FOG_STEPS);
    float dither = hash12(gl_FragCoord.xy);
    vec3 pos = camPos + rayDir * stepSize * dither;

    vec3 drift = vec3(frameTimeCounter, frameTimeCounter * 0.6, frameTimeCounter * 0.8) * NETHER_FOG_DRIFT_SPEED;

    float density = 0.0;
    for (int i = 0; i < NETHER_FOG_STEPS; i++) {
        pos += rayDir * stepSize;
        float n = fbm3dN(pos * NETHER_FOG_NOISE_SCALE + drift);
        density += n * stepSize;
    }

    float fogFactor = 1.0 - exp(-density * NETHER_FOG_DENSITY_MULT);
    fogFactor = clamp(fogFactor, 0.0, NETHER_FOG_MAX_OPACITY);

    float sceneLuma = getLuma(col);
    float warmBleed = smoothstep(NETHER_FOG_WARM_LOW, NETHER_FOG_WARM_HIGH, sceneLuma);
    vec3 fogColor = mix(moodColor, NETHER_FOG_WARM_COLOR, warmBleed * NETHER_FOG_WARM_MIX);
    fogColor = applyFogPatchiness(fogColor);

    return mix(col, fogColor, fogFactor);
}

#endif
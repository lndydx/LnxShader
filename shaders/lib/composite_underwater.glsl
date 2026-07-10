#ifndef COMPOSITE_UNDERWATER_GLSL
#define COMPOSITE_UNDERWATER_GLSL

vec3 computeUnderwaterAmbient(vec3 baseColor, vec2 wobbledUV, float linDepth, vec3 worldPos, float distortX, float distortY, vec3 sunDirWorld) {
    float waterSurfaceY = 62.0;
    float depthFromSurface = max(0.0, waterSurfaceY - worldPos.y);
    vec3 shallowWaterColor = vec3(0.16, 0.42, 0.40);
    vec3 deepWaterColor    = vec3(0.05, 0.16, 0.16);

    float gradientFactor = smoothstep(0.0, 30.0, depthFromSurface);
    vec3 oceanTint = mix(shallowWaterColor, deepWaterColor, gradientFactor);

    float environmentDarkness = mix(1.0, 0.45, gradientFactor);
    vec3 waterTintedColor = baseColor * oceanTint * environmentDarkness * 0.9;

    float realDistance = linDepth * far;

    float fogStartLocal = 8.0;
    float fogEndLocal   = far * 0.65;

    float fogFactor = clamp((realDistance - fogStartLocal) / (fogEndLocal - fogStartLocal), 0.0, 1.0);
    fogFactor = smoothstep(0.0, 1.0, fogFactor);

    vec3 brightWaterFogColor = vec3(0.03, 0.10, 0.15);
    vec3 mixedColor = mix(waterTintedColor, brightWaterFogColor, fogFactor);

    // --- God rays: streaks that lean with the sun instead of round blobs ---
    float changeT = frameTimeCounter * 0.5;

    vec2 sunHoriz = sunDirWorld.xz;
    float sunHorizLen = length(sunHoriz);
    vec2 sunHorizDir = sunHorizLen > 0.001 ? sunHoriz / sunHorizLen : vec2(1.0, 0.0);
    float tiltAmount = sunHorizLen / max(sunDirWorld.y, 0.15);

    vec2 shaftPos = worldPos.xz - sunHorizDir * depthFromSurface * tiltAmount
                    + vec2(distortX, distortY) * 40.0;

    float across = dot(shaftPos, vec2(-sunHorizDir.y, sunHorizDir.x));
    float wobble = sin(worldPos.y * 0.12 + changeT * 0.6) * 0.6;

    float raysPattern = sin((across + wobble) * 0.9 + changeT * 0.15)
                       + sin((across + wobble) * 2.3 - changeT * 0.25) * 0.5;

    float finalShaft = pow(clamp(raysPattern * 0.4 + 0.5, 0.0, 1.0), 6.0);

    float surfaceMask = smoothstep(0.5, 1.0, depthFromSurface);
    float shaftOpacity = mix(0.55, 0.18, gradientFactor);
    finalShaft *= shaftOpacity * surfaceMask;

    float distanceFade = 1.0 - smoothstep(12.0, 25.0, linDepth);
    finalShaft *= distanceFade * (1.0 - fogFactor);

    float skyLight = texture2D(lightmap, wobbledUV).g;
    finalShaft *= smoothstep(0.15, 0.45, skyLight);

    finalShaft *= smoothstep(0.0, 0.15, sunDirWorld.y);

    vec3 lightGlowColor = vec3(0.55, 0.85, 0.80);
    mixedColor += lightGlowColor * finalShaft;

    return clamp(mixedColor, 0.0, 1.0);
}

vec3 applyClearUnderwater(vec3 col, vec2 uv, float rawDepth, float linDepth, vec3 worldPos, bool isWaterToSky, float rayDirY, vec3 sunDirWorld) {
    float speed = frameTimeCounter * 1.5;
    float waveIntensity = 0.0016;

    float distortX = sin(uv.y * 5.0 + speed) * cos(uv.x * 2.5 + speed * 0.5) * waveIntensity;
    float distortY = cos(uv.x * 4.0 - speed) * sin(uv.y * 3.0 - speed * 0.7) * waveIntensity;
    vec2 wobbledUV = uv + vec2(distortX, distortY);

    vec3 baseColor = texture2D(colortex0, wobbledUV).rgb;
    return computeUnderwaterAmbient(baseColor, wobbledUV, linDepth, worldPos, distortX, distortY, sunDirWorld);
}

#endif
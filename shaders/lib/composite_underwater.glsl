#ifndef COMPOSITE_UNDERWATER_GLSL
#define COMPOSITE_UNDERWATER_GLSL

vec3 computeUnderwaterAmbient(vec3 baseColor, vec2 wobbledUV, float linDepth, vec3 worldPos, float distortX, float distortY) {
    float waterSurfaceY = 62.0;
    float depthFromSurface = max(0.0, waterSurfaceY - worldPos.y);
    vec3 shallowWaterColor = vec3(0.25, 0.62, 0.58);
    vec3 deepWaterColor    = vec3(0.20, 0.50, 0.44);

    float gradientFactor = smoothstep(0.0, 30.0, depthFromSurface);
    vec3 oceanTint = mix(shallowWaterColor, deepWaterColor, gradientFactor);

    float environmentDarkness = mix(1.0, 1.1, gradientFactor);
    vec3 waterTintedColor = baseColor * oceanTint * environmentDarkness * 1.25;

    float realDistance = linDepth * far;

    float fogStartLocal = 8.0;
    float fogEndLocal   = far * 0.65;

    float fogFactor = clamp((realDistance - fogStartLocal) / (fogEndLocal - fogStartLocal), 0.0, 1.0);
    fogFactor = smoothstep(0.0, 1.0, fogFactor);

    vec3 brightWaterFogColor = vec3(0.10, 0.30, 0.45);
    vec3 mixedColor = mix(waterTintedColor, brightWaterFogColor, fogFactor);

    float changeT = frameTimeCounter * 1.2;
    vec3 blendPos = worldPos + vec3(distortX * 60.0, worldPos.y * 0.08, distortY * 60.0);
    vec2 refraction = vec2(sin(blendPos.z * 0.6 + changeT), cos(blendPos.x * 0.6 + changeT)) * 0.18;

    float caustics1 = sin(sin((blendPos.x + refraction.x) * 2.2 + changeT) + sin((blendPos.z + refraction.y) * 2.2 + changeT));
    float caustics2 = sin(cos((blendPos.z - refraction.x) * 3.5 - changeT) + sin((blendPos.x - refraction.y) * 3.5 + changeT));

    float combinedCaustics = max(caustics1, caustics2);
    float finalShaft = pow(max(0.0, combinedCaustics * 0.5 + 0.5), 3.2);

    float surfaceMask = smoothstep(0.5, 1.0, depthFromSurface);
    float causticsOpacity = mix(0.50, 0.25, gradientFactor);
    finalShaft *= causticsOpacity * surfaceMask;

    float distanceFade = 1.0 - smoothstep(12.0, 25.0, linDepth);
    finalShaft *= distanceFade * (1.0 - fogFactor);

    float skyLight = texture2D(lightmap, wobbledUV).g;
    finalShaft *= smoothstep(0.15, 0.45, skyLight);

    vec3 lightGlowColor = vec3(0.50, 0.88, 0.82);
    mixedColor += lightGlowColor * finalShaft;

    return clamp(mixedColor, 0.0, 1.0);
}

vec3 applyClearUnderwater(vec3 col, vec2 uv, float rawDepth, float linDepth, vec3 worldPos, bool isWaterToSky, float rayDirY) {
    float speed = frameTimeCounter * 1.5;
    float waveIntensity = 0.0016;

    float distortX = sin(uv.y * 5.0 + speed) * cos(uv.x * 2.5 + speed * 0.5) * waveIntensity;
    float distortY = cos(uv.x * 4.0 - speed) * sin(uv.y * 3.0 - speed * 0.7) * waveIntensity;
    vec2 wobbledUV = uv + vec2(distortX, distortY);

    vec3 baseColor = texture2D(colortex0, wobbledUV).rgb;
    return computeUnderwaterAmbient(baseColor, wobbledUV, linDepth, worldPos, distortX, distortY);
}

#endif
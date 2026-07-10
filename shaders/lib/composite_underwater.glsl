#ifndef COMPOSITE_UNDERWATER_GLSL
#define COMPOSITE_UNDERWATER_GLSL

vec3 computeUnderwaterAmbient(vec3 baseColor, vec2 wobbledUV, float linDepth, vec3 worldPos, float distortX, float distortY, vec3 sunDirWorld, out float ambientIntensityOut, out float depthFromSurfaceOut) {
    float waterSurfaceY = 62.0;
    float depthFromSurface = max(0.0, waterSurfaceY - worldPos.y);
    float viewDistance = linDepth * far;

    // WATER ABSORPTION 
    vec3 absorptionCoeff = vec3(0.035, 0.012, 0.006);
    vec3 transmittance = exp(-absorptionCoeff * viewDistance);
    vec3 absorbedColor = baseColor * transmittance;

    vec3 scatterColor = vec3(0.03, 0.32, 0.42);
    vec3 scatterCoeff = vec3(0.02, 0.018, 0.014);
    vec3 inscatter = scatterColor * (1.0 - exp(-scatterCoeff * viewDistance));

    // AMBIENT LIGHT 
    float verticalAtten = exp(-0.015 * depthFromSurface);
    float skyLight = texture2D(lightmap, wobbledUV).g;
    float sunHeightFactor = smoothstep(-0.05, 0.25, sunDirWorld.y);
    float ambientIntensity = clamp(verticalAtten * skyLight * mix(0.25, 1.0, sunHeightFactor), 0.24, 1.0);

    vec3 litColor = (absorbedColor + inscatter) * ambientIntensity * 1.45;

    // FOG 
    vec3 deepFogColor = vec3(0.02, 0.14, 0.20) * ambientIntensity;
    float fogFactor = smoothstep(far * 0.55, far * 1.10, viewDistance);
    vec3 finalColor = mix(litColor, deepFogColor, fogFactor);

    ambientIntensityOut = ambientIntensity;
    depthFromSurfaceOut = depthFromSurface;
    return max(finalColor, 0.0);
}

float sampleGodrayShadow(vec3 playerPos) {
    vec4 sPos = shadowProjection * (shadowModelView * vec4(playerPos, 1.0));
    sPos.xyz = distort(sPos.xyz);
    sPos.xyz = sPos.xyz * 0.5 + 0.5;

    if (sPos.x < 0.0 || sPos.x > 1.0 || sPos.y < 0.0 || sPos.y > 1.0 || sPos.z > 1.0) return 0.0;

    float bias = 0.0015;
    return step(sPos.z - bias, texture2D(shadowtex1, sPos.xy).r);
}

vec3 computeGodRays(vec3 worldPos, vec2 wobbledUV, vec3 rayDir, float depthFromSurface, float viewDistance, vec3 sunDirWorld, float ambientIntensity) {
    if (sunDirWorld.y < 0.0) return vec3(0.0);

    float marchDist = min(viewDistance, GODRAY_MAX_DISTANCE);
    if (marchDist <= 0.05) return vec3(0.0);

    float stepLen = marchDist / float(GODRAY_STEPS);
    vec3 rayStep = rayDir * stepLen;

    float dither = hash12(wobbledUV * vec2(viewWidth, viewHeight) + fract(frameTimeCounter));
    vec3 samplePos = rayDir * (stepLen * dither); 

    float accum = 0.0;
    for (int i = 0; i < GODRAY_STEPS; i++) {
        accum += sampleGodrayShadow(samplePos);
        samplePos += rayStep;
    }
    accum /= float(GODRAY_STEPS);

    float VoS = max(dot(rayDir, sunDirWorld), 0.0);
    float phase = 0.2 + pow(VoS, 6.0) * 3.0;

    float t = frameTimeCounter;
    float shimmer = 0.85 + 0.15 * sin(dot(worldPos.xz, vec2(0.15, 0.11)) + t * 0.6);

    float shaft = accum * phase * shimmer;

    float skyLight = texture2D(lightmap, wobbledUV).g;
    shaft *= mix(0.2, 1.0, skyLight);
    shaft *= smoothstep(0.0, 0.15, sunDirWorld.y);
    shaft *= ambientIntensity;
    shaft *= smoothstep(0.0, GODRAY_MAX_DISTANCE * 0.3, marchDist);

    vec3 rayColor = vec3(0.85, 0.95, 1.0);
    return rayColor * shaft * GODRAY_INTENSITY;
}

// CAUSTICS 
vec3 computeCaustics(vec3 worldPos, float depthFromSurface, float viewDistance, float ambientIntensity, float skyLight) {
    float t = frameTimeCounter * 0.5;
    vec2 p = worldPos.xz * 0.35;

    vec2 p1 = p + vec2(t * 0.6, t * 0.4);
    vec2 p2 = p * 1.7 - vec2(t * 0.5, t * 0.7);

    float c1 = sin(p1.x) + sin(p1.y) + sin((p1.x + p1.y) * 0.6);
    float c2 = sin(p2.x * 1.3) + sin(p2.y * 1.3) + sin((p2.x - p2.y) * 0.8);

    float caustic = c1 * c2;
    caustic = pow(clamp(caustic * 0.15 + 0.5, 0.0, 1.0), 5.0); 

    float depthFade = exp(-depthFromSurface * 0.06); 
    float distanceFade = 1.0 - smoothstep(14.0, 30.0, viewDistance);

    caustic *= depthFade * distanceFade * skyLight * ambientIntensity;

    vec3 causticColor = vec3(0.85, 1.0, 0.92);
    return causticColor * caustic * 0.45;
}

vec3 applyClearUnderwater(vec3 col, vec2 uv, float rawDepth, float linDepth, vec3 worldPos, bool isWaterToSky, vec3 rayDir, vec3 sunDirWorld) {
    float speed = frameTimeCounter * 1.5;
    float waveIntensity = 0.0016;

    float distortX = sin(uv.y * 5.0 + speed) * cos(uv.x * 2.5 + speed * 0.5) * waveIntensity;
    float distortY = cos(uv.x * 4.0 - speed) * sin(uv.y * 3.0 - speed * 0.7) * waveIntensity;
    vec2 wobbledUV = uv + vec2(distortX, distortY);

    vec3 baseColor = texture2D(colortex0, wobbledUV).rgb;

    float ambientIntensity;
    float depthFromSurface;
    vec3 ambientColor = computeUnderwaterAmbient(baseColor, wobbledUV, linDepth, worldPos, distortX, distortY, sunDirWorld, ambientIntensity, depthFromSurface);

    float viewDistance = linDepth * far;
    vec3 rays = computeGodRays(worldPos, wobbledUV, rayDir, depthFromSurface, viewDistance, sunDirWorld, ambientIntensity);

    float skyLight = texture2D(lightmap, wobbledUV).g;
    vec3 caustics = computeCaustics(worldPos, depthFromSurface, viewDistance, ambientIntensity, skyLight);

    return ambientColor + rays + caustics;
}

#endif
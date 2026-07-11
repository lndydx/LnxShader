#ifndef COMPOSITE_UNDERWATER_GLSL
#define COMPOSITE_UNDERWATER_GLSL

// SIMPLEX NOISE 2D
vec2 mod289v2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 mod289v3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289v3(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                       -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289v2(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                    + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
                            dot(x12.zw,x12.zw)), 0.0);
    m = m*m;
    m = m*m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float water_caustics(vec2 p) {
    float n = snoise(p);
    p -= vec2(n, n * 0.7) * 0.07;
    p *= 1.62;
    n = snoise(p);
    p -= vec2(n, n * 0.7) * 0.07;
    n = snoise(p);
    p -= vec2(n, n * 0.7) * 0.07;
    n = snoise(p);
    return n;
}

// AMBIENT
vec3 computeUnderwaterAmbient(vec3 baseColor, vec2 wobbledUV, float linDepth, vec3 worldPos, float distortX, float distortY, vec3 sunDirWorld, out float ambientIntensityOut, out float depthFromSurfaceOut) {
    float waterSurfaceY = 62.0;
    float depthFromSurface = max(0.0, waterSurfaceY - worldPos.y);
    float viewDistance = linDepth * far;

    vec3 absorptionCoeff = vec3(0.035, 0.012, 0.006);
    vec3 transmittance = exp(-absorptionCoeff * viewDistance);
    vec3 absorbedColor = baseColor * transmittance;

    vec3 scatterColor = vec3(0.05, 0.36, 0.48);
    vec3 scatterCoeff = vec3(0.02, 0.018, 0.014);
    vec3 inscatter = scatterColor * (1.0 - exp(-scatterCoeff * viewDistance));

    float verticalAtten = exp(-0.015 * depthFromSurface);
    float skyLight = texture2D(lightmap, wobbledUV).g;
    float sunHeightFactor = smoothstep(-0.05, 0.25, sunDirWorld.y);
    float ambientIntensity = clamp(verticalAtten * skyLight * mix(0.25, 1.0, sunHeightFactor), 0.24, 1.0);

    vec3 litColor = (absorbedColor + inscatter) * ambientIntensity * 1.45;

    vec3 deepFogColor = vec3(0.02, 0.14, 0.20) * ambientIntensity;
    float fogFactor = smoothstep(far * 0.55, far * 1.10, viewDistance);
    vec3 finalColor = mix(litColor, deepFogColor, fogFactor);

    ambientIntensityOut = ambientIntensity;
    depthFromSurfaceOut = depthFromSurface;
    return max(finalColor, 0.0);
}

// GODRAY
vec3 computeGodRays(vec3 worldPos, vec2 wobbledUV, vec3 rayDir, float depthFromSurface, float viewDistance, vec3 sunDirWorld, float ambientIntensity) {
    return vec3(0.0);
}

// CAUSTIC RAYS 
vec3 computeCaustics(vec3 worldPos, float depthFromSurface, float viewDistance, float skyLight, vec3 sunDirWorld) {
    if (sunDirWorld.y < 0.0) return vec3(0.0);
    if (skyLight < 0.05) return vec3(0.0);
    
    float surfaceFade = smoothstep(0.0, 1.5, depthFromSurface);
    if (surfaceFade < 0.001) return vec3(0.0);
    
    float layerIntensity;
    if (depthFromSurface < 10.0) {
        layerIntensity = 1.0;
    } else if (depthFromSurface < 20.0) {
        layerIntensity = 1.0 - smoothstep(10.0, 20.0, depthFromSurface);
        layerIntensity *= 0.4;
    } else {
        return vec3(0.0);
    }
    
    if (layerIntensity < 0.001) return vec3(0.0);
    
    float t = frameTimeCounter * 0.75;
    vec2 p = worldPos.xz * 0.09;
    float w = water_caustics(p * 3.0 + vec2(t * 0.2, t * 0.15));
    
    float intensity = exp(w * 2.8 - 1.0);
    intensity = intensity * layerIntensity * surfaceFade;
    
    float sunHeight = smoothstep(0.0, 0.1, sunDirWorld.y);
    float distFade = 1.0 - smoothstep(10.0, 120.0, viewDistance);
    
    intensity *= sunHeight * distFade * skyLight;
    
    if (intensity < 0.001) return vec3(0.0);
    
    vec3 causticColor = vec3(0.82, 0.95, 1.0);
    return causticColor * intensity * 0.25;
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
    vec3 caustics = computeCaustics(worldPos, depthFromSurface, viewDistance, skyLight, sunDirWorld);

    return ambientColor + rays + caustics;
}

#endif
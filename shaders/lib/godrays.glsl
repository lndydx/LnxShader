#ifndef GODRAYS_GLSL
#define GODRAYS_GLSL

// CONFIGURATION
#define GODRAY_ENABLED 1
#define GODRAY_SAMPLES 40
#define GODRAY_MAX_DIST 250.0
#define GODRAY_DENSITY 0.006
#define GODRAY_SCATTERING 0.60
#define GODRAY_ISOTROPIC 0.70
#define GODRAY_ABSORPTION 0.3
#define GODRAY_CONTRAST 2.0
#define GODRAY_HALO_CAP 0.5        
#define GODRAY_HALO_INTENSITY 0.5  
#define GODRAY_SHAFT_CAP 6.0        
#define GODRAY_SHAFT_INTENSITY 0.5

float interleavedGradientNoise(vec2 fragCoord) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(fragCoord, magic.xy)));
}

float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(denom, 1.5));
}

vec3 worldToShadow(vec3 worldPos) {
    vec4 shadowPos = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    shadowPos.xyz = distort(shadowPos.xyz);
    return shadowPos.xyz * 0.5 + 0.5;
}

float sampleShadow(vec3 shadowCoord) {
    if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
        shadowCoord.y < 0.0 || shadowCoord.y > 1.0 ||
        shadowCoord.z < 0.0 || shadowCoord.z > 1.0) {
        return 1.0;
    }
    float shadowDepth = texture2D(shadowtex1, shadowCoord.xy).r;
    return shadowDepth + 0.001 > shadowCoord.z ? 1.0 : 0.0;
}

float getGodRayTimeIntensity() {
    int t = worldTime;

    if (t >= 23000 || t <= 1200) {
        float normalized;
        if (t >= 23000) normalized = float(t - 23000);
        else normalized = 1000.0 + float(t);
        float fadeIn = smoothstep(0.0, 700.0, normalized);
        float fadeOut = 1.0 - smoothstep(1800.0, 2200.0, normalized);
        return fadeIn * fadeOut;
    }

    if (t >= 11000 && t <= 13000) {
        float normalized = float(t - 11000);
        float fadeIn = smoothstep(0.0, 300.0, normalized);
        float fadeOut = 1.0 - smoothstep(1500.0, 2000.0, normalized);
        return fadeIn * fadeOut;
    }

    return 0.0;
}

vec3 getGodRayColor() {
    float wt = float(worldTime);

    vec3 dawnGod   = vec3(1.00, 0.95, 0.55);
    vec3 dayGod    = vec3(1.00, 0.92, 0.55);
    vec3 sunsetGod = vec3(1.00, 0.78, 0.25);
    vec3 nightGod  = vec3(0.75, 0.80, 0.95);  

    vec3 col = dawnGod;
    col = mix(col, dayGod,    smoothstep(0.0,     1500.0, wt));
    col = mix(col, sunsetGod, smoothstep(11000.0, 12000.0, wt));
    col = mix(col, nightGod,  smoothstep(12500.0, 13500.0, wt));
    col = mix(col, dawnGod,   smoothstep(22500.0, 23500.0, wt));

    return col;
}

// VOLUMETRIC GOD RAYS
vec3 computeGodRays(vec2 uv, float rawDepth, vec3 sunDirWorld) {
    #if GODRAY_ENABLED != 1
        return vec3(0.0);
    #endif

    float timeIntensity = getGodRayTimeIntensity();
    if (timeIntensity < 0.001) return vec3(0.0);
    if (rainStrength > 0.3) timeIntensity *= (1.0 - rainStrength * 0.6);

    bool isSky = rawDepth >= 0.9999;
    vec3 viewPos = getViewPos(uv, rawDepth);
    float surfaceDist = length(viewPos);
    float rayLen = isSky ? GODRAY_MAX_DIST : min(surfaceDist, GODRAY_MAX_DIST);
    if (rayLen < 0.5) return vec3(0.0);

    vec3 viewDirVS = getViewPos(uv, 0.0);
    vec3 rayDir = normalize((gbufferModelViewInverse * vec4(viewDirVS, 0.0)).xyz);

    float stepSize = rayLen / float(GODRAY_SAMPLES);
    vec3 stepVec = rayDir * stepSize;

    float dither = interleavedGradientNoise(gl_FragCoord.xy);
    vec3 currentPos = stepVec * dither;

    float transmittance = 1.0;
    vec3 densityAccum = vec3(0.0); 
    float litSteps = 0.0;

    for (int i = 0; i < GODRAY_SAMPLES; i++) {
        currentPos += stepVec;

        vec3 shadowCoord = worldToShadow(currentPos);
        float shadow = sampleShadow(shadowCoord);
        litSteps += shadow;

        float density = GODRAY_DENSITY * stepSize;
        float stepTransmittance = exp(-GODRAY_ABSORPTION * density);

        vec3 stepDensity = vec3(0.0);
        if (shadow > 0.5) {
            stepDensity = getGodRayColor() * density;
        }

        densityAccum += transmittance * stepDensity;
        transmittance *= stepTransmittance;

        if (transmittance < 0.01) break;
    }

    float litRatio = litSteps / float(GODRAY_SAMPLES);
    float shaftMask = pow(litRatio, GODRAY_CONTRAST);

    float haloWeight = smoothstep(0.85, 1.0, litRatio);

    float phaseRaw = hgPhase(max(dot(rayDir, sunDirWorld), 0.0), GODRAY_SCATTERING);
    float phaseCap = mix(GODRAY_SHAFT_CAP, GODRAY_HALO_CAP, haloWeight);
    float phase = min(phaseRaw, phaseCap);
    phase = max(phase, GODRAY_ISOTROPIC);

    float finalIntensity = mix(GODRAY_SHAFT_INTENSITY, GODRAY_HALO_INTENSITY, haloWeight);

    vec3 result = densityAccum * shaftMask * phase * finalIntensity * timeIntensity;

    float luma = dot(result, vec3(0.299, 0.587, 0.114));
    result = mix(result, vec3(luma), clamp(luma * 0.35, 0.0, 0.6));

    return result;
}

#endif
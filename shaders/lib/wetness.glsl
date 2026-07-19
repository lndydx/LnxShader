#ifndef WETNESS_GLSL
#define WETNESS_GLSL

#define WETNESS_DARKEN 0.35
#define WETNESS_SKY_STRENGTH 0.25
#define WETNESS_UPFACING_MIN 0.3
#define WETNESS_SHADOW_BIAS 0.0015

#define PUDDLE_SCALE 0.045
#define PUDDLE_EDGE_SOFTNESS 0.12
#define PUDDLE_FLATNESS_MIN 0.6
#define PUDDLE_FLATNESS_MAX 0.9
#define PUDDLE_RIPPLE_SCALE 0.6
#define PUDDLE_RIPPLE_SPEED 0.35
#define PUDDLE_RIPPLE_STRENGTH 0.05
#define PUDDLE_DARKEN_MULT 0.6
#define PUDDLE_SKY_STRENGTH_MULT 1.8

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float getPuddleMask(vec3 worldPos, float wetnessAmount) {
    float n = valueNoise(worldPos.xz * PUDDLE_SCALE);
    float threshold = mix(0.75, 0.35, wetnessAmount);
    return smoothstep(threshold - PUDDLE_EDGE_SOFTNESS, threshold + PUDDLE_EDGE_SOFTNESS, n);
}

vec2 getPuddleRippleOffset(vec3 worldPos) {
    vec2 p = worldPos.xz * PUDDLE_RIPPLE_SCALE + frameTimeCounter * PUDDLE_RIPPLE_SPEED;
    float n1 = valueNoise(p);
    float n2 = valueNoise(p + vec2(4.7, 1.3));
    return (vec2(n1, n2) - 0.5) * PUDDLE_RIPPLE_STRENGTH;
}

float getSkyExposure(vec3 worldPos) {
    vec3 shadowViewPos  = (shadowModelView * vec4(worldPos - cameraPosition, 1.0)).xyz;
    vec3 shadowClipPos  = distort((shadowProjection * vec4(shadowViewPos, 1.0)).xyz);
    vec3 shadowScreenPos = shadowClipPos * 0.5 + 0.5;

    if (shadowScreenPos.x < 0.0 || shadowScreenPos.x > 1.0 ||
        shadowScreenPos.y < 0.0 || shadowScreenPos.y > 1.0) {
        return 0.0;
    }

    const vec2 offsets[5] = vec2[5](
        vec2(0.0, 0.0),
        vec2(1.0, 0.0),
        vec2(-1.0, 0.0),
        vec2(0.0, 1.0),
        vec2(0.0, -1.0)
    );

    float texel = 1.0 / 2048.0; 
    float exposure = 0.0;
    for (int i = 0; i < 5; i++) {
        vec2 sampleUV = shadowScreenPos.xy + offsets[i] * texel * 2.0;
        float shadowDepth = texture2D(shadowtex1, sampleUV).r;
        exposure += (shadowScreenPos.z - WETNESS_SHADOW_BIAS <= shadowDepth) ? 1.0 : 0.0;
    }
    return exposure / 5.0;
}

vec3 applyWetSurface(vec3 color, vec3 viewPos, vec3 worldPos, float wetnessAmount, vec3 sunDir, vec3 normal, float skylight) {
    if (wetnessAmount <= 0.01) return color;
    if (biome_precipitation == 0) return color;

    float skyExposure = smoothstep(0.82, 0.97, skylight);
    if (skyExposure <= 0.01) return color;

    vec3 normalWorld = normalize(mat3(gbufferModelViewInverse) * normal);
    float upFacing = max(normalWorld.y, 0.0);
    float surfaceMask = mix(WETNESS_UPFACING_MIN, 1.0, upFacing);

    float puddleMask = getPuddleMask(worldPos, wetnessAmount * wetnessAmount);
    puddleMask *= smoothstep(PUDDLE_FLATNESS_MIN, PUDDLE_FLATNESS_MAX, upFacing);

    float wetFactor    = wetnessAmount * skyExposure * surfaceMask;
    float puddleFactor = wetnessAmount * skyExposure * puddleMask;

    color = mix(color, color * (1.0 - WETNESS_DARKEN), wetFactor);
    color = mix(color, color * (1.0 - WETNESS_DARKEN * PUDDLE_DARKEN_MULT), puddleFactor);

    vec2 ripple = getPuddleRippleOffset(worldPos) * puddleMask;
    vec3 puddleNormal = normalize(normal + vec3(ripple, 0.0));

    vec3 V = normalize(-viewPos);
    float fresnelWet    = pow(1.0 - max(dot(normal, V), 0.0), 3.0);
    float fresnelPuddle = pow(1.0 - max(dot(puddleNormal, V), 0.0), 2.0);

    color += fogColor * fresnelWet * wetFactor * WETNESS_SKY_STRENGTH;
    color += fogColor * fresnelPuddle * puddleFactor * WETNESS_SKY_STRENGTH * PUDDLE_SKY_STRENGTH_MULT;

    return color;
}

#endif

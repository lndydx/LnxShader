#ifndef COMPOSITE_POST_GLSL
#define COMPOSITE_POST_GLSL

vec3 getWhiteBalance(vec3 sunDir) {
    vec3 neutral = vec3(1.0, 1.0, 1.0);
    vec3 warm    = vec3(1.10, 1.00, 0.85);

    float h = sunDir.y;
    float horizonProximity = 1.0 - smoothstep(0.0, 0.26, abs(h));
    bool isNight = h < NIGHT_HEIGHT_THRESHOLD;

    float warmFactor = horizonProximity * 0.9;
    warmFactor = max(warmFactor, isNight ? 0.5 : 0.0);

    return mix(neutral, warm, warmFactor);
}

vec3 applyContrast(vec3 col, float amount) {
    vec3 x = clamp(col, 0.0, 1.0);
    vec3 s = x * x * (3.0 - 2.0 * x);
    return mix(x, s, clamp(amount - 1.0, 0.0, 1.0) * 1.5);
}

vec3 applyVibrance(vec3 col, float amount) {
    float luma = getLuma(col);
    float maxC = max(col.r, max(col.g, col.b));
    float minC = min(col.r, min(col.g, col.b));
    float sat = maxC - minC;
    float boost = amount * (1.0 - sat);
    return mix(vec3(luma), col, 1.0 + boost);
}

float getSaturationBoost(vec3 sunDir) {
    float h = sunDir.y;
    float horizonBoost = 1.0 - smoothstep(0.0, 0.26, abs(h));
    bool isNight = h < NIGHT_HEIGHT_THRESHOLD;
    float base = isNight ? 1.2 : 1.15;
    return mix(base, 1.25, horizonBoost);
}

vec3 applyColorGrade(vec3 col, vec3 sunDir) {
    col *= getWhiteBalance(sunDir);

    float satBoost = getSaturationBoost(sunDir);
    col = applyVibrance(col, VIBRANCE * (satBoost - 1.0) * 2.0);

    float luma = getLuma(col);
    col = mix(vec3(luma), col, satBoost);

    col = applyContrast(col, CONTRAST);
    return col;
}

vec3 applySharpen(vec3 col, vec2 uv) {
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);

    vec3 blur =
        texture2D(colortex0, uv + vec2( texel.x, 0.0)).rgb +
        texture2D(colortex0, uv + vec2(-texel.x, 0.0)).rgb +
        texture2D(colortex0, uv + vec2(0.0,  texel.y)).rgb +
        texture2D(colortex0, uv + vec2(0.0, -texel.y)).rgb;
    blur *= 0.25;

    return col + (col - blur) * SHARPEN_STRENGTH;
}

vec3 acesTonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float sampleAverageLuminance() {
    float sum = 0.0;
    const int GRID = 5;
    for (int gx = 0; gx < GRID; gx++) {
        for (int gy = 0; gy < GRID; gy++) {
            vec2 uv = (vec2(float(gx), float(gy)) + 0.5) / float(GRID);
            sum += getLuma(texture2D(colortex0, uv).rgb);
        }
    }
    return sum / float(GRID * GRID);
}

float encodeExposure(float e) {
    return clamp((e - EXPOSURE_MIN) / (EXPOSURE_MAX - EXPOSURE_MIN), 0.0, 1.0);
}

float decodeExposure(float e01) {
    return e01 * (EXPOSURE_MAX - EXPOSURE_MIN) + EXPOSURE_MIN;
}

float computeExposure() {
    float avgLuma = max(sampleAverageLuminance(), 0.0001);
    float targetExposure = clamp(TARGET_LUMA / avgLuma, EXPOSURE_MIN, EXPOSURE_MAX);

    vec2 historyTexel = vec2(0.5 / viewWidth, 0.5 / viewHeight);
    float lastExposureRaw = texture2D(colortex2, historyTexel).r;
    float lastExposure = decodeExposure(lastExposureRaw);

    float adaptSpeed = clamp(1.0 - exp(-max(frameTime, 0.0001) * EXPOSURE_ADAPT_RATE), 0.0, 1.0);
    return mix(lastExposure, targetExposure, adaptSpeed);
}

vec3 getBloomContribution(vec3 col, vec2 uv) {
    float resScale = 1.0;
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);

    float selfLuma = getLuma(col);
    float selfWarmth = clamp(col.r - col.b, 0.0, 1.0);
    float selfEffLuma = selfLuma + selfWarmth * 0.2;

    float selfMask = smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + BLOOM_KNEE, selfEffLuma);
    vec3 core = col * selfMask * BLOOM_CORE_BOOST;
    core = min(core, vec3(1.2));

    vec3 bloomSum = vec3(0.0);
    float weightSum = 0.0;

    const int SAMPLES = 8;
    for (int i = 0; i < SAMPLES; i++) {
        float angle = (float(i) / float(SAMPLES)) * 6.2831853;
        vec2 dirOffset = vec2(cos(angle), sin(angle));

        vec2 uvNear = uv + dirOffset * texel * (BLOOM_RADIUS_PX * resScale);
        vec2 uvFar  = uv + dirOffset * texel * (BLOOM_RADIUS_PX_WIDE * resScale);

        vec3 sampNear = texture2D(colortex0, uvNear).rgb;
        vec3 sampFar  = texture2D(colortex0, uvFar).rgb;

        float warmthNear = clamp(sampNear.r - sampNear.b, 0.0, 1.0);
        float warmthFar  = clamp(sampFar.r - sampFar.b, 0.0, 1.0);

        float effLumaNear = getLuma(sampNear) + warmthNear * 0.2;
        float effLumaFar  = getLuma(sampFar)  + warmthFar  * 0.2;

        bloomSum += sampNear * smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + BLOOM_KNEE, effLumaNear) * 1.0;
        bloomSum += sampFar  * smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + BLOOM_KNEE, effLumaFar)  * 0.25;
        weightSum += 1.25;
    }

    vec3 bloomColor = bloomSum / max(weightSum, 0.0001);
    return core + bloomColor * BLOOM_INTENSITY;
}

#endif
#ifndef END_SKY_GLSL
#define END_SKY_GLSL

#include "/lib/end_palette.glsl"
#include "/lib/end_stars.glsl"

float hashE1(float n) { return fract(sin(n) * 83729.29412221); }
float hashE3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.3))) * 37913.80952); }

float noiseE2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hashE1(dot(i, vec2(1.0, 57.0)));
    float b = hashE1(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
    float c = hashE1(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
    float d = hashE1(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbmE2(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    float sum = 0.0;
    for (int i = 0; i < 5; i++) {
        v += a * noiseE2(p);
        sum += a;
        p = p * 2.07 + vec2(19.3, 7.7);
        a *= 0.5;
    }
    return v / sum;
}

float noiseE3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hashE3(i + vec3(0.0, 0.0, 0.0));
    float n100 = hashE3(i + vec3(1.0, 0.0, 0.0));
    float n010 = hashE3(i + vec3(0.0, 1.0, 0.0));
    float n110 = hashE3(i + vec3(1.0, 1.0, 0.0));
    float n001 = hashE3(i + vec3(0.0, 0.0, 1.0));
    float n101 = hashE3(i + vec3(1.0, 0.0, 1.0));
    float n011 = hashE3(i + vec3(0.0, 1.0, 1.0));
    float n111 = hashE3(i + vec3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);

    float nxy0 = mix(nx00, nx10, f.y);
    float nxy1 = mix(nx01, nx11, f.y);

    return mix(nxy0, nxy1, f.z);
}

float fbmE3d(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    float sum = 0.0;
    for (int i = 0; i < 5; i++) {
        v += a * noiseE3(p);
        sum += a;
        p = p * 2.07 + vec3(19.3, 7.7, 13.1);
        a *= 0.5;
    }
    return v / sum;
}

#define NEBULA_WARP_SCALE 0.60
#define NEBULA_WARP_STRENGTH1 1.4
#define NEBULA_WARP_STRENGTH2 0.6
#define NEBULA_DENSITY_LOW 0.30
#define NEBULA_DENSITY_HIGH 0.75
#define NEBULA_VERTICAL_FADE_START -0.2
#define NEBULA_VERTICAL_FADE_END 0.9

vec2 warpNebula(vec2 p) {
    vec2 w1 = vec2(fbmE2(p * 0.8 + 17.0), fbmE2(p * 0.8 - 9.0));
    p += (w1 - 0.5) * NEBULA_WARP_STRENGTH1;
    vec2 w2 = vec2(fbmE2(p * 1.6 + 44.0), fbmE2(p * 1.6 - 21.0));
    p += (w2 - 0.5) * NEBULA_WARP_STRENGTH2;
    return p;
}

vec3 renderNebula(vec3 worldDir) {
    vec2 p = worldDir.xz / (abs(worldDir.y) + 0.35);

    vec2 warped = warpNebula(p * NEBULA_WARP_SCALE);
    float structureA = fbmE2(warped * 1.1);
    float structureB = fbmE2(warped * 3.2 + 88.0);

    float density = mix(structureA, structureB, 0.35);
    density = smoothstep(NEBULA_DENSITY_LOW, NEBULA_DENSITY_HIGH, density);

    float colorMix = fbmE2(warped * 0.6 + 5.0);
    vec3 core = mix(NEBULA_CORE_BLUE, NEBULA_CORE_MAGENTA, colorMix);
    vec3 col  = mix(NEBULA_EDGE, core, density);

    float verticalFade = 1.0 - smoothstep(NEBULA_VERTICAL_FADE_START, NEBULA_VERTICAL_FADE_END, abs(worldDir.y));
    return col * density * verticalFade;
}

#define SPARKLE_SCALE 80.0
#define SPARKLE_SCALE_2 120.0
#define SPARKLE_DENSITY 0.08
#define SPARKLE_DENSITY_2 0.07
#define SPARKLE_SIZE 0.34
#define SPARKLE_SIZE_2 0.40
#define SPARKLE_TWINKLE_SPEED 1.6

float starField(vec3 dir, float cellScale, float density, float pointSize, float time) {
    vec3 p = dir * cellScale;
    vec3 cell = floor(p);
    vec3 f = fract(p);

    float chance = hashE3(cell + 11.0);
    if (chance > density) return 0.0;

    vec3 jitter = vec3(hashE3(cell + 1.7), hashE3(cell + 8.3), hashE3(cell + 4.1));
    float dist = length(f - jitter);
    float point_ = smoothstep(pointSize, 0.0, dist);

    float phase = hashE3(cell + 99.0) * 6.2831853;
    float speedVar = 0.6 + hashE3(cell + 55.0) * 0.9;
    float twinkle = 0.30 + 0.70 * (0.5 + 0.5 * sin(time * SPARKLE_TWINKLE_SPEED * speedVar + phase));

    return point_ * twinkle;
}

vec3 renderEndSparkleStars(vec3 dir, float time) {
    float s1 = starField(dir, SPARKLE_SCALE, SPARKLE_DENSITY, SPARKLE_SIZE, time);
    float s2 = starField(dir, SPARKLE_SCALE_2, SPARKLE_DENSITY_2, SPARKLE_SIZE_2, time * 1.35 + 40.0);

    float sparkle = clamp(s1 + s2 * 0.8, 0.0, 1.0);
    if (sparkle <= 0.0) return vec3(0.0);

    vec3 white  = vec3(1.0, 1.0, 1.0);
    vec3 violet = vec3(0.85, 0.75, 1.0);
    vec3 cyan   = vec3(0.70, 0.90, 1.0);

    float colorPick = hashE3(floor(dir * SPARKLE_SCALE) + 3.3);
    vec3 sparkleCol = colorPick < 0.5 ? mix(white, violet, colorPick * 2.0)
                                       : mix(violet, cyan, (colorPick - 0.5) * 2.0);

    return sparkleCol * sparkle;
}

#define AURORA_DUST_WARP_SCALE 3.0
#define AURORA_DUST_WARP_AMOUNT 0.05
#define AURORA_DUST_NOISE_SCALE 1.6
#define AURORA_DUST_DETAIL_SCALE 3.4
#define AURORA_DUST_THRESH_LOW 0.35
#define AURORA_DUST_THRESH_HIGH 0.75
#define AURORA_DUST_STRENGTH 0.55

float auroraDustNoise(vec3 local, float bandFalloff) {
    vec3 warp = vec3(fbmE3d(local * AURORA_DUST_WARP_SCALE + vec3(400.0, 100.0, 250.0)),
                      fbmE3d(local * AURORA_DUST_WARP_SCALE + vec3(100.0, 400.0, 60.0)),
                      fbmE3d(local * AURORA_DUST_WARP_SCALE + vec3(60.0, 250.0, 400.0))) - 0.5;
    vec3 p = local + warp * AURORA_DUST_WARP_AMOUNT;

    float n = fbmE3d(p * AURORA_DUST_NOISE_SCALE + vec3(200.0, 50.0, 90.0));
    n += fbmE3d(p * AURORA_DUST_DETAIL_SCALE + vec3(80.0, 300.0, 15.0)) * 0.4;
    n /= 1.4;

    float patch = smoothstep(AURORA_DUST_THRESH_LOW, AURORA_DUST_THRESH_HIGH, n);
    patch *= smoothstep(0.0, 0.18, bandFalloff);

    return patch;
}

#define AURORA_ANGLE_SCALE 2.0
#define AURORA_HEIGHT_SCALE 1.5
#define AURORA_MORPH_SPEED 0.05
#define AURORA_CENTER_HEIGHT 0.30
#define AURORA_VERTICAL_SPREAD 0.65
#define AURORA_FADE_SOFTNESS 0.50
#define AURORA_STRETCH_POWER 0.5
#define AURORA_INTENSITY 0.40

vec3 renderEndAurora(vec3 worldDir, float time) {
    float h = worldDir.y;

    float distFromCenter = abs(h - AURORA_CENTER_HEIGHT);
    float fadeStart = AURORA_VERTICAL_SPREAD - AURORA_FADE_SOFTNESS;
    float fadeEnd   = AURORA_VERTICAL_SPREAD + AURORA_FADE_SOFTNESS;
    if (distFromCenter > fadeEnd) return vec3(0.0);

    vec3 local = vec3(worldDir.x, worldDir.z, h) * vec3(AURORA_ANGLE_SCALE, AURORA_ANGLE_SCALE, AURORA_HEIGHT_SCALE);

    vec3 morphOffset = vec3(time * AURORA_MORPH_SPEED,
                             time * AURORA_MORPH_SPEED * 0.73,
                             time * AURORA_MORPH_SPEED * 0.51);

    vec3 warp1 = vec3(fbmE3d(local * 1.4 + vec3(10.0, 30.0, 60.0) + morphOffset),
                       fbmE3d(local * 0.9 + vec3(70.0, 5.0, 20.0) + morphOffset),
                       fbmE3d(local * 1.1 + vec3(15.0, 45.0, 8.0) + morphOffset)) - 0.5;
    local += warp1 * 0.9;

    vec3 warp2 = vec3(fbmE3d(local * 3.0 + vec3(5.0, 90.0, 33.0) + morphOffset),
                       fbmE3d(local * 2.0 + vec3(40.0, 12.0, 77.0) + morphOffset),
                       fbmE3d(local * 2.5 + vec3(22.0, 61.0, 9.0) + morphOffset)) - 0.5;
    local += warp2 * 0.35;

    float struc  = fbmE3d(local * 1.6 + vec3(50.0) + morphOffset);
    float detail = fbmE3d(local * 4.0 + vec3(120.0, 4.0, 88.0) + morphOffset * 1.3);

    float verticalFade = 1.0 - smoothstep(fadeStart, fadeEnd, distFromCenter);
    verticalFade = clamp(verticalFade, 0.0, 1.0);
    verticalFade = pow(verticalFade, AURORA_STRETCH_POWER);

    float columnVariance = mix(0.75, 1.25, struc);
    float band = clamp(verticalFade * columnVariance, 0.0, 1.0);

    float brightness = band * (0.30 + struc * 0.5 + detail * 0.35);

    float dustMask = auroraDustNoise(local * 0.6, band) * AURORA_DUST_STRENGTH;
    brightness *= (1.0 - dustMask);

    brightness = max(brightness, 0.0) * AURORA_INTENSITY;
    if (brightness < 0.01) return vec3(0.0);

    vec3 colA = NEBULA_CORE_BLUE;
    vec3 colB = NEBULA_CORE_MAGENTA;
    vec3 colC = vec3(1.00, 0.50, 0.88);

    vec3 col = mix(colA, colB, struc);
    col = mix(col, colC, detail * 0.45);

    return col * brightness;
}

vec3 renderEndSky(vec3 worldDir, float time) {
    vec3 col = vec3(0.0);

    col += renderNebula(worldDir);
    col += renderEndAurora(worldDir, time) * 0.6;
    col += renderEndSparkleStars(worldDir, time) * 0.5;
    col += renderEndConstellations(worldDir, time);

    return col;
}

#endif
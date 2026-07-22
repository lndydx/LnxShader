#ifndef NETHER_SKY_GLSL
#define NETHER_SKY_GLSL

float hash1N(float n) { return fract(sin(n) * 83729.29412221); }
float hash3N(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.3))) * 37913.80952); }

float noise3N(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hash3N(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash3N(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash3N(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash3N(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash3N(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash3N(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash3N(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash3N(i + vec3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);

    float nxy0 = mix(nx00, nx10, f.y);
    float nxy1 = mix(nx01, nx11, f.y);

    return mix(nxy0, nxy1, f.z);
}

float fbm3dN(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    float sum = 0.0;
    for (int i = 0; i < 5; i++) {
        v += a * noise3N(p);
        sum += a;
        p = p * 2.07 + vec3(19.3, 7.7, 13.1);
        a *= 0.5;
    }
    return v / sum;
}

#define BIOME_NETHER_WASTES 100
#define BIOME_SOUL_SAND_VALLEY 101
#define BIOME_CRIMSON_FOREST 102
#define BIOME_WARPED_FOREST 103
#define BIOME_BASALT_DELTAS 104

#define COL_NETHER_WASTES vec3(0.38, 0.08, 0.06)
#define COL_SOUL_SAND_VALLEY vec3(0.12, 0.38, 0.35)
#define COL_CRIMSON_FOREST vec3(0.50, 0.08, 0.10)
#define COL_WARPED_FOREST vec3(0.30, 0.12, 0.45)
#define COL_BASALT_DELTAS vec3(0.18, 0.17, 0.18)
#define COL_NETHER_DEFAULT vec3(0.35, 0.12, 0.08)

vec3 getNetherBiomeColor(int biomeId) {
    if (biomeId == BIOME_NETHER_WASTES)    return COL_NETHER_WASTES;
    if (biomeId == BIOME_SOUL_SAND_VALLEY) return COL_SOUL_SAND_VALLEY;
    if (biomeId == BIOME_CRIMSON_FOREST)   return COL_CRIMSON_FOREST;
    if (biomeId == BIOME_WARPED_FOREST)    return COL_WARPED_FOREST;
    if (biomeId == BIOME_BASALT_DELTAS)    return COL_BASALT_DELTAS;
    return COL_NETHER_DEFAULT;
}

const vec3 FILL_NETHER_WASTES    = vec3(0.100, 0.040, 0.030);
const vec3 FILL_SOUL_SAND_VALLEY = vec3(0.030, 0.090, 0.110);
const vec3 FILL_CRIMSON_FOREST   = vec3(0.110, 0.035, 0.045);
const vec3 FILL_WARPED_FOREST    = vec3(0.040, 0.070, 0.100);
const vec3 FILL_BASALT_DELTAS    = vec3(0.060, 0.058, 0.065);
const vec3 FILL_NETHER_DEFAULT   = vec3(0.080, 0.040, 0.035);

vec3 getNetherAmbientFillColor(int biomeId) {
    if (biomeId == BIOME_NETHER_WASTES)    return FILL_NETHER_WASTES;
    if (biomeId == BIOME_SOUL_SAND_VALLEY) return FILL_SOUL_SAND_VALLEY;
    if (biomeId == BIOME_CRIMSON_FOREST)   return FILL_CRIMSON_FOREST;
    if (biomeId == BIOME_WARPED_FOREST)    return FILL_WARPED_FOREST;
    if (biomeId == BIOME_BASALT_DELTAS)    return FILL_BASALT_DELTAS;
    return FILL_NETHER_DEFAULT;
}

const vec3 FOG_NETHER_WASTES    = vec3(0.55, 0.35, 0.28);
const vec3 FOG_SOUL_SAND_VALLEY = vec3(0.38, 0.56, 0.54);
const vec3 FOG_CRIMSON_FOREST   = vec3(0.58, 0.28, 0.30);
const vec3 FOG_WARPED_FOREST    = vec3(0.38, 0.42, 0.58);
const vec3 FOG_BASALT_DELTAS    = vec3(0.44, 0.42, 0.42);
const vec3 FOG_NETHER_DEFAULT   = vec3(0.48, 0.40, 0.36);

vec3 getNetherFogColor(int biomeId) {
    if (biomeId == BIOME_NETHER_WASTES)    return FOG_NETHER_WASTES;
    if (biomeId == BIOME_SOUL_SAND_VALLEY) return FOG_SOUL_SAND_VALLEY;
    if (biomeId == BIOME_CRIMSON_FOREST)   return FOG_CRIMSON_FOREST;
    if (biomeId == BIOME_WARPED_FOREST)    return FOG_WARPED_FOREST;
    if (biomeId == BIOME_BASALT_DELTAS)    return FOG_BASALT_DELTAS;
    return FOG_NETHER_DEFAULT;
}

#define NETHER_AMBIENT_STRENGTH 0.03

vec3 renderNetherAmbientGlow(vec3 biomeColor) {
    vec3 darkAmbient = biomeColor * 0.4;
    return darkAmbient * NETHER_AMBIENT_STRENGTH;
}

#define SMOKE_DUST_WARP_SCALE   2.5
#define SMOKE_DUST_WARP_AMOUNT  0.04
#define SMOKE_DUST_NOISE_SCALE  1.4
#define SMOKE_DUST_DETAIL_SCALE 3.0
#define SMOKE_DUST_THRESH_LOW   0.40
#define SMOKE_DUST_THRESH_HIGH  0.80
#define SMOKE_DUST_STRENGTH     0.40

float smokeDustNoise(vec3 local, float bandFalloff) {
    vec3 warp = vec3(fbm3dN(local * SMOKE_DUST_WARP_SCALE + vec3(400.0, 100.0, 250.0)),
                      fbm3dN(local * SMOKE_DUST_WARP_SCALE + vec3(100.0, 400.0, 60.0)),
                      fbm3dN(local * SMOKE_DUST_WARP_SCALE + vec3(60.0, 250.0, 400.0))) - 0.5;
    vec3 p = local + warp * SMOKE_DUST_WARP_AMOUNT;

    float n = fbm3dN(p * SMOKE_DUST_NOISE_SCALE + vec3(200.0, 50.0, 90.0));
    n += fbm3dN(p * SMOKE_DUST_DETAIL_SCALE + vec3(80.0, 300.0, 15.0)) * 0.35;
    n /= 1.35;

    float patch = smoothstep(SMOKE_DUST_THRESH_LOW, SMOKE_DUST_THRESH_HIGH, n);
    patch *= smoothstep(0.0, 0.15, bandFalloff);

    return patch;
}

#define SMOKE_ANGLE_SCALE      1.8
#define SMOKE_HEIGHT_SCALE     1.2
#define SMOKE_MORPH_SPEED      0.04
#define SMOKE_CENTER_HEIGHT    0.35
#define SMOKE_VERTICAL_SPREAD  0.55
#define SMOKE_FADE_SOFTNESS    0.60
#define SMOKE_STRETCH_POWER    0.6
#define SMOKE_INTENSITY        0.45

vec3 renderNetherSmoke(vec3 worldDir, float time, vec3 biomeColor) {
    float h = worldDir.y;

    float distFromCenter = abs(h - SMOKE_CENTER_HEIGHT);
    float fadeStart = SMOKE_VERTICAL_SPREAD - SMOKE_FADE_SOFTNESS;
    float fadeEnd   = SMOKE_VERTICAL_SPREAD + SMOKE_FADE_SOFTNESS;
    if (distFromCenter > fadeEnd) return vec3(0.0);

    vec3 local = vec3(worldDir.x, worldDir.z, h) * vec3(SMOKE_ANGLE_SCALE, SMOKE_ANGLE_SCALE, SMOKE_HEIGHT_SCALE);

    vec3 morphOffset = vec3(time * SMOKE_MORPH_SPEED,
                             time * SMOKE_MORPH_SPEED * 0.73,
                             time * SMOKE_MORPH_SPEED * 0.51);

    vec3 warp1 = vec3(fbm3dN(local * 1.4 + vec3(10.0, 30.0, 60.0) + morphOffset),
                       fbm3dN(local * 0.9 + vec3(70.0, 5.0, 20.0) + morphOffset),
                       fbm3dN(local * 1.1 + vec3(15.0, 45.0, 8.0) + morphOffset)) - 0.5;
    local += warp1 * 0.8;

    vec3 warp2 = vec3(fbm3dN(local * 3.0 + vec3(5.0, 90.0, 33.0) + morphOffset),
                       fbm3dN(local * 2.0 + vec3(40.0, 12.0, 77.0) + morphOffset),
                       fbm3dN(local * 2.5 + vec3(22.0, 61.0, 9.0) + morphOffset)) - 0.5;
    local += warp2 * 0.30;

    float struc  = fbm3dN(local * 1.6 + vec3(50.0) + morphOffset);
    float detail = fbm3dN(local * 4.0 + vec3(120.0, 4.0, 88.0) + morphOffset * 1.3);

    float verticalFade = 1.0 - smoothstep(fadeStart, fadeEnd, distFromCenter);
    verticalFade = clamp(verticalFade, 0.0, 1.0);
    verticalFade = pow(verticalFade, SMOKE_STRETCH_POWER);

    float columnVariance = mix(0.80, 1.20, struc);
    float band = clamp(verticalFade * columnVariance, 0.0, 1.0);

    float brightness = band * (0.25 + struc * 0.4 + detail * 0.3);

    float dustMask = smokeDustNoise(local * 0.6, band) * SMOKE_DUST_STRENGTH;
    brightness *= (1.0 - dustMask);

    brightness = max(brightness, 0.0) * SMOKE_INTENSITY;
    if (brightness < 0.01) return vec3(0.0);

    vec3 smokeDark  = vec3(0.04, 0.04, 0.05);
    vec3 smokeLight = vec3(0.28, 0.26, 0.25);
    vec3 col = mix(smokeDark, smokeLight, struc);

    col = mix(col, biomeColor * 0.6, 0.10 + detail * 0.08);

    return col * brightness;
}

vec3 renderNetherAtmosphere(vec3 worldDir, float time, int biomeId) {
    vec3 biomeColor = getNetherBiomeColor(biomeId);
    vec3 col = vec3(0.0);

    col += renderNetherAmbientGlow(biomeColor);
    col += renderNetherSmoke(worldDir, time, biomeColor);

    return col;
}

#endif
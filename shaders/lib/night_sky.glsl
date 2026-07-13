#ifndef NIGHT_SKY_GLSL
#define NIGHT_SKY_GLSL

// HASH & NOISE
float hash1(float n) { return fract(sin(n) * 83729.29412221); }

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.3))) * 37913.80952); }

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash1(dot(i, vec2(1.0, 57.0)));
    float b = hash1(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
    float c = hash1(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
    float d = hash1(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm3(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    float sum = 0.0;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        sum += a;
        p = p * 2.07 + vec2(19.3, 7.7);
        a *= 0.5;
    }
    return v / sum;
}

// GALAXY 
#define GALAXY_AZIMUTH_ROTATE 90.0
#define GALAXY_MORPH_SPEED 0.009

vec3 getGalaxyDir() {
    vec3 baseDir = normalize(vec3(0.0, 0.40, 0.92));
    float rad = radians(GALAXY_AZIMUTH_ROTATE);
    float c = cos(rad), s = sin(rad);
    vec3 shifted = vec3(baseDir.x * c + baseDir.z * s, baseDir.y, -baseDir.x * s + baseDir.z * c);
    return normalize(shifted);
}


// DARK DUST LANE 
#define DUST_WARP_SCALE   3.0
#define DUST_WARP_AMOUNT  0.01
#define DUST_NOISE_SCALE  3.8
#define DUST_DETAIL_SCALE 8.0
#define DUST_THRESHOLD_LOW  0.35 
#define DUST_THRESHOLD_HIGH 0.75 
#define DUST_STRENGTH 0.90
#define DUST_COLOR vec3(0.05, 0.03, 0.045) 

float darkDustNoise(vec2 local, float bandFalloff) {
    vec2 warp = vec2(fbm3(local * DUST_WARP_SCALE + vec2(400.0, 100.0)),
                      fbm3(local * DUST_WARP_SCALE + vec2(100.0, 400.0))) - 0.5;
    vec2 p = local + warp * DUST_WARP_AMOUNT;

    float n = fbm3(p * DUST_NOISE_SCALE + vec2(200.0, 50.0));
    n += fbm3(p * DUST_DETAIL_SCALE + vec2(80.0, 300.0)) * 0.4;
    n /= 1.4;

    float patch = smoothstep(DUST_THRESHOLD_LOW, DUST_THRESHOLD_HIGH, n);
    patch *= smoothstep(0.0, 0.18, bandFalloff);

    return patch;
}

// SPARKLE / TWINKLING STARS 
#define SPARKLE_SCALE          80.0
#define SPARKLE_SCALE_2        120.0
#define SPARKLE_DENSITY        0.10
#define SPARKLE_DENSITY_2      0.09
#define SPARKLE_SIZE           0.20  
#define SPARKLE_SIZE_2         0.23   
#define SPARKLE_TWINKLE_SPEED  1.6
#define SPARKLE_HALO_OUTER    -0.30
#define SPARKLE_HALO_INNER     0.55
#define SPARKLE_BASE_DENSITY   0.30  

float starField(vec3 dir, float cellScale, float density, float pointSize, float time) {
    vec3 p = dir * cellScale;
    vec3 cell = floor(p);
    vec3 f = fract(p);

    float chance = hash3(cell + 11.0);
    if (chance > density) return 0.0;

    vec3 jitter = vec3(hash3(cell + 1.7), hash3(cell + 8.3), hash3(cell + 4.1));
    float dist = length(f - jitter);
    float point_ = smoothstep(pointSize, 0.0, dist);

    float phase = hash3(cell + 99.0) * 6.2831853;
    float speedVar = 0.6 + hash3(cell + 55.0) * 0.9;
    float twinkle = 0.30 + 0.70 * (0.5 + 0.5 * sin(time * SPARKLE_TWINKLE_SPEED * speedVar + phase));

    return point_ * twinkle;
}

vec3 renderSparkleStars(vec3 dir, vec3 galaxyDir, float time) {
    float align = dot(dir, galaxyDir);

    float halo = mix(SPARKLE_BASE_DENSITY, 1.0, smoothstep(SPARKLE_HALO_OUTER, SPARKLE_HALO_INNER, align));

    float s1 = starField(dir, SPARKLE_SCALE, SPARKLE_DENSITY, SPARKLE_SIZE, time);
    float s2 = starField(dir, SPARKLE_SCALE_2, SPARKLE_DENSITY_2, SPARKLE_SIZE_2, time * 1.35 + 40.0);

    float sparkle = clamp(s1 + s2 * 0.8, 0.0, 1.0) * halo;
    if (sparkle <= 0.0) return vec3(0.0);

    vec3 warmCol = vec3(1.0, 0.92, 0.80);
    vec3 coolCol = vec3(0.80, 0.88, 1.0);
    vec3 sparkleCol = mix(coolCol, warmCol, hash3(floor(dir * SPARKLE_SCALE) + 3.3));

    return sparkleCol * sparkle;
}

// GALAXY BAND
vec3 renderGalaxy(vec3 dir, vec3 galaxyDir, float time) {
    float align = max(dot(dir, galaxyDir), 0.0);
    if (align < 0.30) return vec3(0.0);

    vec3 up = abs(galaxyDir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 u = normalize(cross(up, galaxyDir));
    vec3 v = cross(galaxyDir, u);

    float angle = radians(30.0);
    float c = cos(angle), s = sin(angle);
    vec2 local = vec2(dot(dir, u), dot(dir, v)) / max(align, 0.001);
    local = vec2(local.x * c - local.y * s, local.x * s + local.y * c);
    vec2 morphOffset = vec2(time * GALAXY_MORPH_SPEED, time * GALAXY_MORPH_SPEED * 0.73);

    vec2 warp1 = vec2(fbm3(local * 6.0 + vec2(10.0, 30.0) + morphOffset), fbm3(local * 2.5 + vec2(70.0, 5.0) + morphOffset)) - 0.5;
    local += warp1 * 0.5;
    vec2 warp2 = vec2(fbm3(local * 12.0 + vec2(5.0, 90.0) + morphOffset), fbm3(local * 6.0 + vec2(40.0, 12.0) + morphOffset)) - 0.5;
    local += warp2 * 0.15;

    float el = length(local * vec2(1.0, 0.32));
    float band = exp(-el * el / 0.12);

    float struc  = fbm3(local * 3.2 + vec2(50.0) + morphOffset);
    float detail = fbm3(local * 9.0 + vec2(120.0, 4.0) + morphOffset * 1.3);

    float dust = (1.0 - smoothstep(0.0, 0.1, abs(local.y))) * fbm3(local * 8.0 + vec2(3.0));

    float brightness = band * (0.25 + struc * 0.55 + detail * 0.35);
    brightness -= dust * 0.45;
    brightness = max(brightness, 0.0);

    float core = exp(-el * el / 0.012);
    brightness += core * 0.4;

    vec3 colA = vec3(0.10, 0.22, 0.60);
    vec3 colB = vec3(0.55, 0.30, 0.85);
    vec3 colC = vec3(0.85, 0.55, 0.70);
    vec3 col = mix(colA, colB, struc);
    col = mix(col, colC, detail * 0.4);
    col = mix(col, vec3(0.95, 0.98, 1.0), core * 0.5);

    // dust lane gelap yang nyatu di dalam band, bentuk robek-robek, ngikutin band-nya
    float dustMask = darkDustNoise(local, band) * DUST_STRENGTH;
    brightness *= (1.0 - dustMask);
    col = mix(col, DUST_COLOR, dustMask * 0.9);

    float sectorFade = smoothstep(0.30, 0.55, align);
    return col * brightness * 1.3 * sectorFade;
}

// ENTRY POINT
vec3 renderNightSky(vec3 worldDir, float time, int worldTime, float rainStrength) {
    if (worldTime < 15800 || worldTime > 21400) return vec3(0.0);
    if (rainStrength > 0.6) return vec3(0.0);

    float t = float(worldTime);
    float fade = smoothstep(15800.0, 16400.0, t) * (1.0 - smoothstep(20800.0, 21400.0, t));
    fade *= 1.0 - rainStrength * 0.8;

    vec3 galaxyDir = getGalaxyDir();

    vec3 col = vec3(0.0);
    col += renderGalaxy(worldDir, galaxyDir, time);
    col += renderSparkleStars(worldDir, galaxyDir, time);

    return col * fade;
}

#endif
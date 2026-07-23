#ifndef END_STARS_GLSL
#define END_STARS_GLSL

#define END_CONSTELLATION_SEED 42 //[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50]
#define END_CONSTELLATION_COUNT 8 //[3 5 7 10 11 12 14 16]
#define END_CONSTELLATION_JITTER_ANGLE 0.12
#define END_STARS_PER_CONSTELLATION 7
#define END_CONSTELLATION_PATCH_RADIUS 0.095

#define END_STAR_SPREAD_JITTER 0.5 //[tuning] 0 = grid spiral sempurna & kaku, 1 = hampir sekacau random lama. 0.25-0.45 rekomendasi

#define END_CONSTELLATION_MIN_ELEVATION -0.75
#define END_CONSTELLATION_MAX_ELEVATION  0.98

#define END_STAR_SIZE_MIN 0.006
#define END_STAR_SIZE_MAX 0.015
#define END_STAR_BRIGHT_MIN 0.6
#define END_STAR_BRIGHT_MAX 1.0
#define END_STAR_CORE_SCALE 0.8
#define END_STAR_HALO_SCALE 3.2
#define END_STAR_HALO_INTENSITY 0.40

#define END_STAR_COLOR_COOL vec3(0.522, 0.639, 1.000)
#define END_STAR_COLOR_WARM vec3(0.918, 0.341, 0.580)
#define END_STAR_WARM_CHANCE 0.55

float hashES1(float n) {
    vec3 p3 = fract(vec3(n, n, n) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 getEndConstellationCenter(int idx) {
    float n = float(END_CONSTELLATION_COUNT);
    float i = float(idx) + 0.5;
    float goldenAngle = 2.39996323;

    float yT = i / n;
    float y = mix(END_CONSTELLATION_MAX_ELEVATION, END_CONSTELLATION_MIN_ELEVATION, yT);
    float radius = sqrt(max(1.0 - y * y, 0.0));
    float theta = goldenAngle * i + float(END_CONSTELLATION_SEED) * 0.017;

    vec3 center = normalize(vec3(cos(theta) * radius, y, sin(theta) * radius));

    float seedBase = float(END_CONSTELLATION_SEED) + float(idx) * 71.0;
    float jitterYaw   = (hashES1(seedBase * 3.3) - 0.5) * 2.0 * END_CONSTELLATION_JITTER_ANGLE;
    float jitterPitch = (hashES1(seedBase * 7.7 + 1.0) - 0.5) * 2.0 * END_CONSTELLATION_JITTER_ANGLE;

    vec3 up = abs(center.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 u  = normalize(cross(up, center));
    vec3 v  = cross(center, u);

    return normalize(center + u * jitterYaw + v * jitterPitch);
}

vec2 sunflowerDiscPos(int j, int n, float patchRadius, float phaseOffset) {
    float goldenAngle = 2.39996323;
    float r = sqrt((float(j) + 0.5) / float(n)) * patchRadius;
    float theta = float(j) * goldenAngle + phaseOffset;
    return r * vec2(cos(theta), sin(theta));
}

vec3 renderSingleEndConstellation(vec3 dir, int idx, float time) {
    vec3 center = getEndConstellationCenter(idx);
    float align = dot(dir, center);
    if (align < 0.90) return vec3(0.0);

    vec3 up = abs(center.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 u = normalize(cross(up, center));
    vec3 v = cross(center, u);
    vec2 local = vec2(dot(dir, u), dot(dir, v)) / max(align, 0.001);

    if (length(local) > END_CONSTELLATION_PATCH_RADIUS * 1.6) return vec3(0.0);

    vec2 starPos[END_STARS_PER_CONSTELLATION];
    float starSize[END_STARS_PER_CONSTELLATION];
    float starBright[END_STARS_PER_CONSTELLATION];
    vec3 starCol[END_STARS_PER_CONSTELLATION];
    float starPhase[END_STARS_PER_CONSTELLATION];

    float baseSeed = float(END_CONSTELLATION_SEED) + float(idx) * 53.0;
    float spiralPhase = hashES1(baseSeed * 2.1) * 6.2831853;
    float cellSpacing = END_CONSTELLATION_PATCH_RADIUS / sqrt(float(END_STARS_PER_CONSTELLATION));

    for (int j = 0; j < END_STARS_PER_CONSTELLATION; j++) {
        vec2 gridPos = sunflowerDiscPos(j, END_STARS_PER_CONSTELLATION, END_CONSTELLATION_PATCH_RADIUS, spiralPhase);

        float s = baseSeed + float(j) * 9.173;
        vec2 jitter = (vec2(hashES1(s * 1.7), hashES1(s * 2.3)) - 0.5) * 2.0 * cellSpacing * END_STAR_SPREAD_JITTER;

        starPos[j] = gridPos + jitter;

        float sizeRand = hashES1(s * 4.1);
        starSize[j]   = mix(END_STAR_SIZE_MIN, END_STAR_SIZE_MAX, sizeRand);
        starBright[j] = mix(END_STAR_BRIGHT_MIN, END_STAR_BRIGHT_MAX, sizeRand);
        starPhase[j]  = hashES1(s * 8.8) * 6.2831853;

        float warm = step(END_STAR_WARM_CHANCE, hashES1(s * 6.6));
        starCol[j] = mix(END_STAR_COLOR_COOL, END_STAR_COLOR_WARM, warm);
    }

    vec3 result = vec3(0.0);
    for (int j = 0; j < END_STARS_PER_CONSTELLATION; j++) {
        float dist = length(local - starPos[j]);
        float core = smoothstep(starSize[j] * END_STAR_CORE_SCALE, 0.0, dist);
        float halo = smoothstep(starSize[j] * END_STAR_HALO_SCALE, 0.0, dist) * END_STAR_HALO_INTENSITY;

        float twinkle = 0.75 + 0.25 * sin(time * 1.2 + starPhase[j]);

        result += starCol[j] * (core + halo) * starBright[j] * twinkle;
    }

    float patchFade = 1.0 - smoothstep(END_CONSTELLATION_PATCH_RADIUS * 0.9, END_CONSTELLATION_PATCH_RADIUS * 1.6, length(local));
    return result * patchFade;
}

vec3 renderEndConstellations(vec3 worldDir, float time) {
    vec3 col = vec3(0.0);
    for (int i = 0; i < END_CONSTELLATION_COUNT; i++) {
        col += renderSingleEndConstellation(worldDir, i, time);
    }
    return col;
}

#endif
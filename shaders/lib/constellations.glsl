#ifndef CONSTELLATIONS_GLSL
#define CONSTELLATIONS_GLSL

// CONFIGURATION
#define CONSTELLATION_SEED 10
#define CONSTELLATION_COUNT 7
#define STARS_PER_CONSTELLATION 7
#define CONSTELLATION_PATCH_RADIUS 0.14

#define STAR_MIN_DIST_FRAC 0.70     
#define STAR_PLACEMENT_ATTEMPTS 10

#define CONSTELLATION_MIN_ELEVATION 0.05     
#define CONSTELLATION_MAX_ELEVATION 0.95     
#define CONSTELLATION_GALAXY_EXCLUSION 0.65  

#define STAR_SIZE_MIN 0.006
#define STAR_SIZE_MAX 0.016
#define STAR_BRIGHT_MIN 0.6
#define STAR_BRIGHT_MAX 1.0
#define STAR_CORE_SCALE 0.8
#define STAR_HALO_SCALE 3.0
#define STAR_HALO_INTENSITY 0.35

#define STAR_COLOR_COOL vec3(0.345, 0.596, 0.976) 
#define STAR_COLOR_WARM vec3(0.976, 0.796, 0.482)   
#define STAR_WARM_CHANCE 0.70                 

#define LINE_WIDTH 0.0022
#define LINE_BRIGHTNESS 0.30
#define LINE_COLOR vec3(0.310, 0.325, 0.392)
#define DEBUG_CONSTELLATIONS 0

// HASH 
float hashC1(float n) { return fract(sin(n) * 51937.4123); }

float distToSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - ba * h);
}

vec3 pushOutsideGalaxy(vec3 dir, vec3 galaxyDir, float minSep) {
    float align = clamp(dot(dir, galaxyDir), -1.0, 1.0);
    float angle = acos(align);
    if (angle >= minSep) return dir;

    vec3 tangent = dir - galaxyDir * align;
    float tangentLen = length(tangent);
    vec3 perp = (tangentLen > 0.0001)
        ? tangent / tangentLen
        : normalize(cross(galaxyDir, vec3(0.0, 1.0, 0.0)));

    return normalize(galaxyDir * cos(minSep) + perp * sin(minSep));
}

vec3 getConstellationCenter(int idx, vec3 galaxyDir) {
    float n = float(CONSTELLATION_COUNT);
    float i = float(idx) + 0.5;

    float goldenAngle = 2.39996323; 
    float yT = i / n;
    float y = mix(CONSTELLATION_MAX_ELEVATION, CONSTELLATION_MIN_ELEVATION, yT);
    float radius = sqrt(max(1.0 - y * y, 0.0));
    float theta = goldenAngle * i + float(CONSTELLATION_SEED) * 0.017;

    vec3 dir = normalize(vec3(cos(theta) * radius, y, sin(theta) * radius));

    return pushOutsideGalaxy(dir, galaxyDir, CONSTELLATION_GALAXY_EXCLUSION);
}

// RENDER: CONSTELLATION
vec3 renderSingleConstellation(vec3 dir, vec3 galaxyDir, int idx, float time) {
    vec3 center = getConstellationCenter(idx, galaxyDir);
    float align = dot(dir, center);
    if (align < 0.90) return vec3(0.0);

    vec3 up = abs(center.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 u = normalize(cross(up, center));
    vec3 v = cross(center, u);
    vec2 local = vec2(dot(dir, u), dot(dir, v)) / max(align, 0.001);

    if (length(local) > CONSTELLATION_PATCH_RADIUS * 1.6) return vec3(0.0);

    vec2 starPos[STARS_PER_CONSTELLATION];
    float starSize[STARS_PER_CONSTELLATION];
    float starBright[STARS_PER_CONSTELLATION];
    vec3 starCol[STARS_PER_CONSTELLATION];
    float starPhase[STARS_PER_CONSTELLATION];

float baseSeed = float(CONSTELLATION_SEED) + float(idx) * 53.0;
    float minDist = CONSTELLATION_PATCH_RADIUS * STAR_MIN_DIST_FRAC;

    for (int j = 0; j < STARS_PER_CONSTELLATION; j++) {
        vec2 bestPos = vec2(0.0);
        bool found = false;

        for (int a = 0; a < STAR_PLACEMENT_ATTEMPTS; a++) {
            float sa = baseSeed + float(j) * 9.173 + float(a) * 131.7;
            vec2 candidate = (vec2(hashC1(sa * 1.7), hashC1(sa * 2.3)) - 0.5) * 2.0 * CONSTELLATION_PATCH_RADIUS;

            bool ok = true;
            for (int k = 0; k < j; k++) {
                if (length(candidate - starPos[k]) < minDist) ok = false;
            }

            if (!found) {
                bestPos = candidate; 
                if (ok) found = true;
            }
        }

        starPos[j] = bestPos;
        float s = baseSeed + float(j) * 9.173;
        float sizeRand = hashC1(s * 4.1);

        starSize[j]   = mix(STAR_SIZE_MIN, STAR_SIZE_MAX, sizeRand);
        starBright[j] = mix(STAR_BRIGHT_MIN, STAR_BRIGHT_MAX, sizeRand);
        starPhase[j]  = hashC1(s * 8.8) * 6.2831853;

        float warm = step(STAR_WARM_CHANCE, hashC1(s * 6.6));
        starCol[j] = mix(STAR_COLOR_COOL, STAR_COLOR_WARM, warm);
    }

    int starOrder[STARS_PER_CONSTELLATION];
    float orderKey[STARS_PER_CONSTELLATION];
    for (int j = 0; j < STARS_PER_CONSTELLATION; j++) {
        float s = baseSeed + float(j) * 9.173;
        orderKey[j] = hashC1(s * 12.7 + 3.3);
        starOrder[j] = j;
    }
    for (int i = 1; i < STARS_PER_CONSTELLATION; i++) {
        float keyVal = orderKey[i];
        int idxVal = starOrder[i];
        int k = i - 1;
        while (k >= 0 && orderKey[k] > keyVal) {
            orderKey[k + 1] = orderKey[k];
            starOrder[k + 1] = starOrder[k];
            k--;
        }
        orderKey[k + 1] = keyVal;
        starOrder[k + 1] = idxVal;
    }

    vec3 result = vec3(0.0);

    for (int j = 0; j < STARS_PER_CONSTELLATION - 1; j++) {
        int a = starOrder[j];
        int b = starOrder[j + 1];
        float d = distToSegment(local, starPos[a], starPos[b]);
        result += LINE_COLOR * smoothstep(LINE_WIDTH, 0.0, d) * LINE_BRIGHTNESS;
    }
    {
        int a = starOrder[0];
        int b = starOrder[STARS_PER_CONSTELLATION / 2];
        float d = distToSegment(local, starPos[a], starPos[b]);
        result += LINE_COLOR * smoothstep(LINE_WIDTH, 0.0, d) * LINE_BRIGHTNESS;
    }

    for (int j = 0; j < STARS_PER_CONSTELLATION; j++) {
        float dist = length(local - starPos[j]);
        float core = smoothstep(starSize[j] * STAR_CORE_SCALE, 0.0, dist);
        float halo = smoothstep(starSize[j] * STAR_HALO_SCALE, 0.0, dist) * STAR_HALO_INTENSITY;

        float twinkle = 0.75 + 0.25 * sin(time * 1.2 + starPhase[j]);

        result += starCol[j] * (core + halo) * starBright[j] * twinkle;
    }

    float patchFade = 1.0 - smoothstep(CONSTELLATION_PATCH_RADIUS * 0.9, CONSTELLATION_PATCH_RADIUS * 1.6, length(local));
    return result * patchFade;
}

vec3 renderConstellations(vec3 worldDir, float time, int worldTime, float rainStrength) {
    vec3 galaxyDir = getGalaxyDir();

#if DEBUG_CONSTELLATIONS
    for (int i = 0; i < CONSTELLATION_COUNT; i++) {
        vec3 c = getConstellationCenter(i, galaxyDir);
        if (dot(worldDir, c) > 0.98) return vec3(1.0, 1.0, 0.0);
    }
    vec3 colDBG = vec3(0.0);
    for (int i = 0; i < CONSTELLATION_COUNT; i++) {
        colDBG += renderSingleConstellation(worldDir, galaxyDir, i, time);
    }
    return colDBG;
#endif

    if (worldTime < 15800 || worldTime > 21400) return vec3(0.0);
    if (rainStrength > 0.6) return vec3(0.0);

    float t = float(worldTime);
    float fade = smoothstep(15800.0, 16400.0, t) * (1.0 - smoothstep(20800.0, 21400.0, t));
    fade *= 1.0 - rainStrength * 0.8;
    if (fade <= 0.0) return vec3(0.0);

    vec3 col = vec3(0.0);
    for (int i = 0; i < CONSTELLATION_COUNT; i++) {
        col += renderSingleConstellation(worldDir, galaxyDir, i, time);
    }

    return col * fade;
}

#endif
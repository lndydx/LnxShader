#version 120

uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform int worldTime;
uniform float rainStrength;

varying vec4 starData;

const float sunPathRotation = 30.0;

#define SKY_SATURATION 1.15
#define SKY_CONTRAST   1.2
#define SUN_GLOW_INTENSITY 0.10
#define SUN_DISC_SIZE 50.0

#define DAY_HEIGHT_THRESHOLD 0.5
#define NIGHT_HEIGHT_THRESHOLD -0.3
#define SKY_ZENITH_END  0.55

struct SkyPalette {
    vec3 zenith;
    vec3 mid;
    vec3 horizon;
};

SkyPalette dawnSky() {
    return SkyPalette(vec3(0.243, 0.215, 0.282), vec3(0.772, 0.611, 0.572), vec3(0.635, 0.776, 0.909));
}
SkyPalette daySky() {
    return SkyPalette(vec3(0.360, 0.529, 0.717), vec3(0.603, 0.756, 0.898), vec3(0.741, 0.803, 0.862));
}
SkyPalette duskSky() {
    return SkyPalette(vec3(0.286, 0.247, 0.317), vec3(0.666, 0.552, 0.525), vec3(0.810, 0.603, 0.164));
}
SkyPalette nightSky() {
    return SkyPalette(vec3(0.02, 0.02, 0.08), vec3(0.04, 0.04, 0.10), vec3(0.06, 0.06, 0.15));
}

SkyPalette mixPalette(SkyPalette a, SkyPalette b, float t) {
    return SkyPalette(mix(a.zenith, b.zenith, t), mix(a.mid, b.mid, t), mix(a.horizon, b.horizon, t));
}

SkyPalette getSkyPalette(int wt, float sunHeight) {
    bool isMorning = wt < 12000;
    SkyPalette horizonPal = isMorning ? dawnSky() : duskSky();

    float dayFactor   = smoothstep(0.0, DAY_HEIGHT_THRESHOLD, sunHeight);
    float nightFactor = smoothstep(0.0, NIGHT_HEIGHT_THRESHOLD, sunHeight);

    SkyPalette pal = mixPalette(horizonPal, daySky(), dayFactor);
    pal = mixPalette(pal, nightSky(), nightFactor);
    return pal;
}

vec3 adjustSkyLook(vec3 col) {
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, SKY_SATURATION);
    col = (col - 0.5) * SKY_CONTRAST + 0.5;
    return max(col, 0.0);
}

vec3 applyRainSky(vec3 col, float sunHeight, float rain) {
    if (rain <= 0.001) return col;

    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 desat = mix(col, vec3(luma), rain * 0.85);

    bool isNight = sunHeight < NIGHT_HEIGHT_THRESHOLD;
    vec3 stormTint = isNight ? vec3(0.04, 0.04, 0.06) : vec3(0.40, 0.41, 0.44);
    vec3 col2 = mix(desat, stormTint, rain * 0.75);

    float darkenAmount = isNight ? 0.5 : 0.2;
    col2 *= mix(1.0, 1.0 - darkenAmount, rain);

    return col2;
}

vec3 calcSkyColor(vec3 pos) {
    float upDot = dot(pos, gbufferModelView[1].xyz);

    vec3 sunDir = normalize(sunPosition);
    float sunHeight = dot(sunDir, gbufferModelView[1].xyz);

    SkyPalette pal = getSkyPalette(worldTime, sunHeight);

    vec3 col = mix(pal.mid, pal.zenith, smoothstep(0.0, SKY_ZENITH_END, upDot));
    col = adjustSkyLook(col);
    col = applyRainSky(col, sunHeight, rainStrength);

    float sunDot = max(dot(pos, sunDir), 0.0);
    float disc = pow(sunDot, SUN_DISC_SIZE) * SUN_GLOW_INTENSITY;
    float sunFade = 1.0 - rainStrength * 0.8;
    col += vec3(1.0, 0.85, 0.65) * disc * sunFade;

    return col;
}

/* DRAWBUFFERS:0 */

void main() {
    vec3 color;
    if (starData.a > 0.5) {
        color = starData.rgb;
    } else {
        vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
        pos = gbufferProjectionInverse * pos;
        color = calcSkyColor(normalize(pos.xyz));
    }

    gl_FragData[0] = vec4(color, 1.0);
}
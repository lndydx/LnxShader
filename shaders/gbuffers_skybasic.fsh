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
#define SKY_ZENITH_BIAS 0.65

struct SkyPalette {
    vec3 zenith;
    vec3 mid;
    vec3 horizon;
};

SkyPalette dawnSky() {
    return SkyPalette(vec3(0.176, 0.235, 0.478), vec3(0.545, 0.400, 0.522), vec3(0.965, 0.588, 0.345));
}
SkyPalette daySky() {
    return SkyPalette(vec3(0.235, 0.408, 0.886), vec3(0.227, 0.510, 0.714), vec3(0.580, 0.808, 0.898));
}
SkyPalette duskSky() {
    return SkyPalette(        vec3(0.043, 0.055, 0.125),  // zenith: biru dongker pekat, hampir malam
        vec3(0.161, 0.196, 0.325),  // mid: biru abu-abu lebih terang, transisi tenang
        vec3(0.886, 0.831, 0.647) );
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

    float t = clamp(upDot, 0.0, 1.0);
    float easedT = smoothstep(0.0, 1.0, t);
    easedT = pow(easedT, SKY_ZENITH_BIAS);

    vec3 col = mix(mix(pal.horizon, pal.mid, easedT), mix(pal.mid, pal.zenith, easedT), easedT);
    col = adjustSkyLook(col);
    col = applyRainSky(col, sunHeight, rainStrength);

    float sunDot = max(dot(pos, sunDir), 0.0);
    float disc = pow(sunDot, SUN_DISC_SIZE) * SUN_GLOW_INTENSITY;
    float sunFade = 1.0 - rainStrength * 0.8;
    col += vec3(1.0, 0.85, 0.65) * disc * sunFade;

    return col;
}

/* DRAWBUFFERS:01 */

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
    gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0); 
}
#version 120

uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform int worldTime;
uniform float rainStrength;
uniform float frameTimeCounter;

varying vec4 starData;

#include "/lib/night_sky.glsl"
#include "/lib/constellations.glsl"

const float sunPathRotation = 30.0;

#define SKY_SATURATION 1.10
#define SKY_CONTRAST   1.12
#define SUN_GLOW_INTENSITY 0.28
#define SUN_DISC_SIZE 34.0
#define MOON_GLOW_INTENSITY 0.10
#define MOON_DISC_SIZE 42.0

#define DAY_HEIGHT_THRESHOLD 0.40
#define NIGHT_HEIGHT_THRESHOLD -0.30

struct SkyPalette {
    vec3 zenith;   
    vec3 mid;     
    vec3 horizon; 
};

SkyPalette mixPalette(SkyPalette a, SkyPalette b, float t) {
    return SkyPalette(
        mix(a.zenith,  b.zenith,  t),
        mix(a.mid,     b.mid,     t),
        mix(a.horizon, b.horizon, t)
    );
}

SkyPalette dawnSky() {    
    return SkyPalette(
        vec3(0.075, 0.102, 0.145),
        vec3(0.133, 0.192, 0.247),
        vec3(0.796, 0.702, 0.502)
    );
}

SkyPalette sunriseSky() {  
    return SkyPalette(
        vec3(0.149, 0.204, 0.290),
        vec3(0.161, 0.231, 0.298),
        vec3(0.733, 0.686, 0.565)
    );
}

SkyPalette daySky() {        
    return SkyPalette(
        vec3(0.12, 0.32, 0.72),
        vec3(0.30, 0.55, 0.90),
        vec3(0.65, 0.82, 0.95)
    );
}

SkyPalette sunsetSky() { 
    return SkyPalette(
        vec3(0.059, 0.125, 0.153),
        vec3(0.251, 0.349, 0.467),
        vec3(0.808, 0.655, 0.333)
    );
}

SkyPalette midnightSky() {    
    return SkyPalette(
        vec3(0.043, 0.047, 0.063),
        vec3(0.075, 0.098, 0.125),
        vec3(0.110, 0.173, 0.251)
    );
}

#define NIGHT_SUNSET_MIX 0.35  
#define NIGHT_BRIGHTNESS 1.30  

SkyPalette nightSky() {       
    SkyPalette pal = mixPalette(midnightSky(), sunsetSky(), NIGHT_SUNSET_MIX);
    pal.zenith  *= NIGHT_BRIGHTNESS;
    pal.mid     *= NIGHT_BRIGHTNESS;
    pal.horizon *= NIGHT_BRIGHTNESS * 0.9;
    return pal;
}

#define DAY_HOLD_END 11000.0    

SkyPalette getSkyPalette(int wtInt) {
    float wt = float(wtInt);

    SkyPalette pal = sunriseSky();
    pal = mixPalette(pal, daySky(),      smoothstep(0.0,          1000.0, wt)); 
    pal = mixPalette(pal, sunsetSky(),   smoothstep(DAY_HOLD_END, 12000.0, wt)); 
    pal = mixPalette(pal, nightSky(),    smoothstep(12000.0,     13000.0, wt)); 
    pal = mixPalette(pal, midnightSky(), smoothstep(13000.0,     13500.0, wt)); 
    pal = mixPalette(pal, dawnSky(),     smoothstep(22500.0,     23200.0, wt)); 
    pal = mixPalette(pal, sunriseSky(),  smoothstep(23000.0,     23800.0, wt)); 

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
    vec3 stormTint = isNight ? vec3(0.03, 0.03, 0.05) : vec3(0.38, 0.40, 0.43);
    vec3 col2 = mix(desat, stormTint, rain * 0.75);

    float darkenAmount = isNight ? 0.55 : 0.25;
    col2 *= mix(1.0, 1.0 - darkenAmount, rain);

    return col2;
}

vec3 getSunColor(float sunHeight, float rain) {
    bool isNight = sunHeight < NIGHT_HEIGHT_THRESHOLD;
    if (isNight) {
        vec3 moonCol = vec3(0.75, 0.82, 1.0);
        return moonCol * (1.0 - rain * 0.5);
    }
    
    float horizonProx = 1.0 - smoothstep(0.0, 0.35, sunHeight);
    vec3 sunsetCol = vec3(1.0, 0.55, 0.15);
    vec3 dayCol = vec3(1.0, 0.92, 0.78);
    vec3 sunCol = mix(dayCol, sunsetCol, horizonProx);
    return sunCol * (1.0 - rain * 0.4);
}

vec3 calcSkyColor(vec3 viewDir) {
    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
    float upDot = worldDir.y;

    vec3 sunDirWorld = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    float sunHeight = sunDirWorld.y;

    SkyPalette pal = getSkyPalette(worldTime);

    float t = clamp(upDot * 0.5 + 0.5, 0.0, 1.0);
    
    float horizonBlend = smoothstep(0.30, 0.75, t);
    float zenithBlend  = smoothstep(0.55, 1.0,  t); 

    vec3 col = mix(pal.horizon, pal.mid, horizonBlend);
    col = mix(col, pal.zenith, zenithBlend);
    
    col = adjustSkyLook(col);
    col = applyRainSky(col, sunHeight, rainStrength);

    float sunDot = max(dot(worldDir, sunDirWorld), 0.0);
    
    float discSize = sunHeight < NIGHT_HEIGHT_THRESHOLD ? MOON_DISC_SIZE : SUN_DISC_SIZE;
    float discInt  = sunHeight < NIGHT_HEIGHT_THRESHOLD ? MOON_GLOW_INTENSITY : SUN_GLOW_INTENSITY;
    
    float disc = pow(sunDot, discSize);
    float glow = pow(sunDot, discSize * 0.22) * 0.4;
    
    float sunFade = 1.0 - rainStrength * 0.8;
    vec3 sunCol = getSunColor(sunHeight, rainStrength);
    
    col += sunCol * (disc * discInt + glow * 0.3) * sunFade;
    col += renderNightSky(worldDir, frameTimeCounter, worldTime, rainStrength);
    col += renderConstellations(worldDir, frameTimeCounter, worldTime, rainStrength);

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
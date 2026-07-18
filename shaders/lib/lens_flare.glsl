#ifndef LENS_FLARE_GLSL
#define LENS_FLARE_GLSL

#define LENS_FLARE_INTENSITY 0.70
#define LENS_ANAMORPHIC_WIDTH_PX 3.0 
#define LENS_ANAMORPHIC_LENGTH_PX 260.0   
#define LENS_ANAMORPHIC_INTENSITY 0.30

vec3 lensGhost(vec2 uv, vec2 pos, float radiusPx, vec3 color) {
    vec2 diffPx = (uv - pos) * vec2(viewWidth, viewHeight);
    float dist = length(diffPx);
    float falloff = smoothstep(radiusPx, radiusPx * 0.15, dist);
    return color * falloff;
}

vec3 hueRainbow(float h) {
    vec3 c = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return c;
}

vec3 lensRainbowArc(vec2 uv, vec2 center, vec2 awayDir, float radiusPx, float thicknessPx) {
    vec2 diffPx = (uv - center) * vec2(viewWidth, viewHeight);
    float dist = length(diffPx);
    float ring = smoothstep(thicknessPx, 0.0, abs(dist - radiusPx));
    if (ring <= 0.0) return vec3(0.0);

    float angle = atan(diffPx.y, diffPx.x) / 6.2831853;
    vec3 rainbow = hueRainbow(fract(angle + 0.5));

    vec2 dirToPixel = diffPx / max(dist, 0.001);
    float halfMask = smoothstep(-0.15, 0.35, dot(dirToPixel, awayDir));

    return rainbow * ring * halfMask;
}

vec3 lensAnamorphicGlow(vec2 uv, vec2 sunPos) {
    vec2 diffPx = (uv - sunPos) * vec2(viewWidth, viewHeight);
    float vertFalloff = exp(-abs(diffPx.y) / LENS_ANAMORPHIC_WIDTH_PX);
    float horizFalloff = smoothstep(LENS_ANAMORPHIC_LENGTH_PX, 0.0, abs(diffPx.x));
    return vec3(1.0, 0.92, 0.75) * vertFalloff * horizFalloff * LENS_ANAMORPHIC_INTENSITY;
}

vec3 computeLensFlare(vec2 uv, vec3 sunDirView, vec3 sunDirWorld, float rain, vec3 baseCol) {
    if (sunDirWorld.y < -0.05) return vec3(0.0);

    vec4 sunClip = gbufferProjection * vec4(sunDirView * 100.0, 1.0);
    if (sunClip.w <= 0.0) return vec3(0.0);

    vec2 sunScreen = (sunClip.xy / sunClip.w) * 0.5 + 0.5;

    float edgeFade = smoothstep(0.0, 0.10, sunScreen.x) * smoothstep(1.0, 0.90, sunScreen.x)
                    * smoothstep(0.0, 0.10, sunScreen.y) * smoothstep(1.0, 0.90, sunScreen.y);
    if (edgeFade <= 0.0) return vec3(0.0);

    float sunDepth = texture2D(depthtex0, clamp(sunScreen, 0.0, 1.0)).r;
    float visibility = step(0.9999, sunDepth) * edgeFade * (1.0 - rain);
    if (visibility <= 0.0) return vec3(0.0);

    vec3 flare = vec3(0.0);
    vec2 center = vec2(0.5);
    vec2 axis = center - sunScreen;
    vec2 awayDir = normalize(-axis + 0.0001);

    flare += lensAnamorphicGlow(uv, sunScreen);

    flare += lensGhost(uv, sunScreen + axis * 0.30, 26.0, vec3(0.95, 0.60, 0.30) * 0.45);
    flare += lensGhost(uv, sunScreen + axis * 0.50, 40.0, vec3(0.85, 0.30, 0.20) * 0.40);
    flare += lensGhost(uv, sunScreen + axis * 0.68, 20.0, vec3(0.55, 0.70, 0.90) * 0.35);
    flare += lensGhost(uv, sunScreen + axis * 0.85, 30.0, vec3(0.90, 0.75, 0.35) * 0.40);
    flare += lensGhost(uv, sunScreen + axis * 1.05, 15.0, vec3(0.95, 0.55, 0.60) * 0.35);
    flare += lensGhost(uv, sunScreen + axis * 1.25, 22.0, vec3(0.60, 0.80, 0.95) * 0.30);
    flare += lensGhost(uv, sunScreen + axis * 1.50, 12.0, vec3(0.90, 0.85, 0.50) * 0.30);

    flare += lensRainbowArc(uv, sunScreen + axis * 0.50, awayDir, 46.0, 4.5) * 0.35;
    flare += lensRainbowArc(uv, sunScreen + axis * 0.85, awayDir, 34.0, 3.5) * 0.30;
    flare += lensRainbowArc(uv, sunScreen + axis * 1.25, awayDir, 26.0, 3.0) * 0.25;

    float baseLuma = dot(baseCol, vec3(0.299, 0.587, 0.114));
    float headroom = 1.0 - smoothstep(0.55, 1.1, baseLuma);
    flare *= mix(0.20, 1.0, headroom);

    return flare * visibility * LENS_FLARE_INTENSITY;
}

#endif
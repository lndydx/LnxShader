#ifndef NETHER_LIGHTING_GLSL
#define NETHER_LIGHTING_GLSL

#define NETHER_FILL_STRENGTH 0.35
#define NETHER_FILL_ROLLOFF  0.25

vec3 applyNetherAmbientFill(vec3 color, vec3 fillColor) {
    float sceneLuma = dot(color, vec3(0.299, 0.587, 0.114));
    float fillMask = 1.0 - smoothstep(0.0, NETHER_FILL_ROLLOFF, sceneLuma);
    return color + fillColor * NETHER_FILL_STRENGTH * fillMask;
}

#endif
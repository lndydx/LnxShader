#ifndef COMPOSITE_COMMON_GLSL
#define COMPOSITE_COMMON_GLSL

float linearizeDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

vec3 getViewPos(vec2 uv, float depth) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clipPos;
    viewPos /= viewPos.w;
    return viewPos.xyz;
}

vec3 getStableWorldPos(vec2 uv, float depth) {
    vec3 viewPos = getViewPos(uv, depth);
    vec4 worldDir = gbufferModelViewInverse * vec4(viewPos, 0.0);
    return worldDir.xyz + cameraPosition;
}

vec3 getSunDirWorld() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition);
}

float getLuma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

#endif
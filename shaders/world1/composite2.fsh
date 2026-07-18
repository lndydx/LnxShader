#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform int isEyeInWater;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

#include "/lib/composite_common.glsl"

#define BLUR_RADIUS 1

/* DRAWBUFFERS:0 */

void main() {
    vec3 baseColor = texture2D(colortex0, texcoord).rgb;

    if (isEyeInWater == 1) {
        gl_FragData[0] = vec4(baseColor, 1.0);
        return;
    }

    vec4 normalData = texture2D(colortex1, texcoord);

    float rawDepth = texture2D(depthtex0, texcoord).r;
    float solidDepth = texture2D(depthtex1, texcoord).r;

    if (normalData.a < 0.95 || abs(rawDepth - solidDepth) < 0.0001) {
        gl_FragData[0] = vec4(baseColor, 1.0);
        return;
    }

    vec2 texelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    vec3 blurredReflection = vec3(0.0);
    float blurredHit = 0.0;
    float totalWeight = 0.0;

    for (int x = -BLUR_RADIUS; x <= BLUR_RADIUS; x++) {
        for (int y = -BLUR_RADIUS; y <= BLUR_RADIUS; y++) {
            vec2 sampleUV = texcoord + vec2(x, y) * texelSize;

            float neighborIsWater = texture2D(colortex1, sampleUV).a;
            if (neighborIsWater < 0.95) continue;

            float weight = max(1.0 - (length(vec2(x, y)) / (float(BLUR_RADIUS) * 1.2)), 0.0);

            vec4 refl = texture2D(colortex3, sampleUV);
            blurredReflection += refl.rgb * weight;
            blurredHit += refl.a * weight;
            totalWeight += weight;
        }
    }

    if (totalWeight > 0.0) {
        blurredReflection /= totalWeight;
        blurredHit /= totalWeight;
    }

    vec3 viewPos = getViewPos(texcoord, rawDepth);
    vec3 N = normalize(normalData.rgb * 2.0 - 1.0);
    vec3 V = normalize(viewPos);

    float fresnel = pow(1.0 - clamp(dot(-V, N), 0.0, 1.0), 5.0);
    fresnel = clamp(fresnel * 0.95 + 0.02, 0.0, 1.0);

    float reflectAmount = fresnel * blurredHit;
    baseColor = mix(baseColor, blurredReflection, reflectAmount);

    gl_FragData[0] = vec4(baseColor, 1.0);
}
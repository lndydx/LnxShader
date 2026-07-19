#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferProjection;
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

#define SSR_MAX_STEPS 200
#define SSR_INITIAL_STEP 0.50
#define SSR_STEP_GROWTH 1.30 
#define SSR_MAX_DIST 250.0
#define SSR_THICKNESS_MIN 2.00
#define SSR_THICKNESS_SCALE 3.00
#define SSR_REFINE_STEPS 20

float ditherPattern(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 raymarchSSR(vec3 viewPos, vec3 reflectDir, vec2 screenUV, out bool hit) {
    hit = false;

    float jitter = ditherPattern(screenUV * viewWidth) * SSR_INITIAL_STEP;
    vec3 rayPos = viewPos + reflectDir * (SSR_INITIAL_STEP + jitter);

    float stepDist = SSR_INITIAL_STEP;
    float travelled = 0.0;
    vec2 hitUV = vec2(-1.0);

    for (int i = 0; i < SSR_MAX_STEPS; i++) {
        vec4 clipPos = gbufferProjection * vec4(rayPos, 1.0);
        if (clipPos.w <= 0.0) break; 
        clipPos.xyz /= clipPos.w;
        vec2 sampleUV = clipPos.xy * 0.5 + 0.5;

        if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) {
            break;
        }

        float sceneDepthRaw = texture2D(depthtex1, sampleUV).r;
        if (sceneDepthRaw < 0.9999) {
            vec3 sceneViewPos = getViewPos(sampleUV, sceneDepthRaw);

            if (rayPos.z < sceneViewPos.z) {
                float depthDiff = sceneViewPos.z - rayPos.z;
                float dynamicThickness = max(SSR_THICKNESS_MIN, stepDist * SSR_THICKNESS_SCALE);
                if (depthDiff < dynamicThickness) {
                    hitUV = sampleUV;
                    hit = true;
                    break;
                }
            }
        }

        travelled += stepDist;
        if (travelled > SSR_MAX_DIST) break;

        rayPos += reflectDir * stepDist;
        stepDist *= SSR_STEP_GROWTH;
    }

    if (!hit) return vec3(0.0);

    vec3 lo = rayPos - reflectDir * stepDist;
    vec3 hi = rayPos;
    for (int i = 0; i < SSR_REFINE_STEPS; i++) {
        vec3 mid = (lo + hi) * 0.5;
        vec4 clipPos = gbufferProjection * vec4(mid, 1.0);
        clipPos.xyz /= clipPos.w;
        vec2 sampleUV = clipPos.xy * 0.5 + 0.5;

        float sceneDepthRaw = texture2D(depthtex1, sampleUV).r;
        vec3 sceneViewPos = getViewPos(sampleUV, sceneDepthRaw);

        if (mid.z < sceneViewPos.z) {
            hi = mid;
            hitUV = sampleUV;
        } else {
            lo = mid;
        }
    }

    return texture2D(colortex0, hitUV).rgb;
}

/* DRAWBUFFERS:3 */

void main() {
    vec4 normalData = texture2D(colortex1, texcoord);

    if (normalData.a < 0.95) {
        gl_FragData[0] = vec4(0.0);
        return;
    }

    float rawDepth = texture2D(depthtex0, texcoord).r;
    vec3 viewPos = getViewPos(texcoord, rawDepth);
    vec3 N = normalize(normalData.rgb * 2.0 - 1.0);
    vec3 V = normalize(-viewPos);
    vec3 reflectDir = reflect(-V, N);

    bool hit;
    vec3 reflectionColor = raymarchSSR(viewPos, reflectDir, texcoord, hit);

    gl_FragData[0] = vec4(reflectionColor, hit ? 1.0 : 0.0);
}
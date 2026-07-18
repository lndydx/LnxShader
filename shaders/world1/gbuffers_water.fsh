#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float alphaTestRef = 0.1;
uniform mat4 gbufferModelViewInverse;
uniform int isEyeInWater;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying vec3 flatNormal;
varying float isRealWater;
varying float isLava;
varying vec4 shadowPos;

#define END_SKY_HORIZON vec3(0.08, 0.05, 0.12)
#define END_SKY_ZENITH  vec3(0.03, 0.02, 0.05)

vec3 endSkyColor(vec3 worldDir) {
    float t = clamp(worldDir.y * 0.5 + 0.5, 0.0, 1.0);
    float horizonBlend = smoothstep(0.30, 0.85, t);
    return mix(END_SKY_HORIZON, END_SKY_ZENITH, horizonBlend);
}

/* DRAWBUFFERS:01 */

void main() {
    vec4 baseColor = texture2D(texture, texcoord) * glcolor;

    if (baseColor.a < alphaTestRef) {
        discard;
    }

    vec3 lm = texture2D(lightmap, lmcoord).rgb;

    if (isLava > 0.5) {
        gl_FragData[0] = vec4(baseColor.rgb * lm, 1.0);
        gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
        return;
    }

    if (isRealWater < 0.5) {
        gl_FragData[0] = vec4(baseColor.rgb * lm, baseColor.a);
        gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
        return;
    }

    vec3 N = normalize(viewNormal);
    vec3 viewDir = normalize(viewPos);

    vec3 geoNormal = normalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (dot(geoNormal, viewDir) > 0.0) geoNormal = -geoNormal;

    vec3 reflectDir = reflect(viewDir, geoNormal);
    vec3 worldReflectDir = normalize((gbufferModelViewInverse * vec4(reflectDir, 0.0)).xyz);
    vec3 reflectionColor = endSkyColor(worldReflectDir) * 0.8;

    float cosView = clamp(dot(-viewDir, N), 0.0, 1.0);
    float F0 = 0.02;
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosView, 5.0);

    float reflectWeight = fresnel * float(isEyeInWater == 0);
    reflectWeight = max(reflectWeight, 0.25 * float(isEyeInWater == 0));

    vec3 finalColor = mix(baseColor.rgb * lm, reflectionColor, reflectWeight);

    float finalAlpha = clamp(0.32 + fresnel * 0.55, 0.0, 1.0);

    if (isEyeInWater == 1) {
        vec3 worldRayDir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
        float rayY = worldRayDir.y;
        const float SNELL_COS = 0.6626;
        const float SNELL_SOFTNESS = 0.12;
        float withinWindow = smoothstep(SNELL_COS - SNELL_SOFTNESS, SNELL_COS + SNELL_SOFTNESS, rayY);
        float snellOpacity = (1.0 - withinWindow) * 0.55;
        finalAlpha = max(finalAlpha, snellOpacity);
    }

    gl_FragData[0] = vec4(finalColor, finalAlpha);

    vec3 ssrNormal = normalize(mix(flatNormal, N, 0.25));
    gl_FragData[1] = vec4(ssrNormal * 0.5 + 0.5, 1.0);
}
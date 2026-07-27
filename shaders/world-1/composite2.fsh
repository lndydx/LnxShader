#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;

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
    gl_FragData[0] = vec4(texture2D(colortex0, texcoord).rgb, 1.0);
}
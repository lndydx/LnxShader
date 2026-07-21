#version 120

attribute vec4 at_mid_block;
attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying vec3 flatNormal;
varying float isRealWater;
varying float isLava;

float waveHeight(vec2 pos, float t) {
    return sin(pos.x * 0.8 + pos.y * 0.5 + t * 1.2) * 0.09
         + sin(pos.x * 1.3 - pos.y * 1.1 + t * 0.9) * 0.05;
}

void main() {
    isRealWater = (mc_Entity.x == 10020.0) ? 1.0 : 0.0;
    isLava      = (mc_Entity.x == 10022.0) ? 1.0 : 0.0;

    vec3 absoluteWorldPos = gl_Vertex.xyz + cameraPosition;
    if (at_mid_block.x != 0.0 || at_mid_block.y != 0.0 || at_mid_block.z != 0.0) {
        absoluteWorldPos = floor(cameraPosition) + at_mid_block.xyz / 64.0 + gl_Vertex.xyz;
    }

    float t = frameTimeCounter;
    vec4 displacedVertex = gl_Vertex;
    vec3 normal = vec3(0.0, 1.0, 0.0);

    if (isRealWater > 0.5 || isLava > 0.5) {
        vec2 wavePos = mod(absoluteWorldPos.xz, 8192.0);
        float wave = waveHeight(wavePos, t);
        displacedVertex.y += wave;

        float eps = 0.15;
        float hL = waveHeight(wavePos - vec2(eps, 0.0), t);
        float hR = waveHeight(wavePos + vec2(eps, 0.0), t);
        float hD = waveHeight(wavePos - vec2(0.0, eps), t);
        float hU = waveHeight(wavePos + vec2(0.0, eps), t);
        normal = normalize(vec3((hL - hR) / (2.0 * eps), 1.0, (hD - hU) / (2.0 * eps)));
    }

    flatNormal = normalize(gl_NormalMatrix * vec3(0.0, 1.0, 0.0));
    viewNormal = normalize(gl_NormalMatrix * normal);

    vec4 viewPosition = gl_ModelViewMatrix * displacedVertex;
    viewPos = viewPosition.xyz;
    gl_Position = gl_ProjectionMatrix * viewPosition;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;
}
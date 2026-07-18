#version 120

uniform int isEyeInWater;

varying vec2 texcoord;
varying float eyeInWater;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    eyeInWater = float(isEyeInWater);
}

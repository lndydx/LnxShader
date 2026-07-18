#ifndef LEAF_SSS_INCLUDED
#define LEAF_SSS_INCLUDED

#define SSS_STRENGTH 3.0
#define SSS_POWER 6.0   
#define SSS_THICKNESS_SCALE 40.0 
#define SSS_DENSITY 5.0  
#define SSS_COLOR vec3(1.0, 0.55, 0.2)

vec3 calcLeafSSS(vec3 albedo, vec3 viewDir, vec3 sunDir, vec4 shadowPos, sampler2D shadowtex1) {
    float backlight = pow(clamp(dot(viewDir, sunDir), 0.0, 1.0), SSS_POWER);
    if (backlight <= 0.0) return vec3(0.0);

    float blockerDepth = texture2D(shadowtex1, shadowPos.xy).r;
    float thickness = max(shadowPos.z - blockerDepth, 0.0) * SSS_THICKNESS_SCALE;
    float transmission = exp(-thickness * SSS_DENSITY);

    return albedo * SSS_COLOR * backlight * transmission * SSS_STRENGTH;
}

#endif
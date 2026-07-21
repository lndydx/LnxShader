#ifndef GGX_GLSL
#define GGX_GLSL

// Trowbridge-Reitz / GGX normal distribution function.
// Mengontrol seberapa "terpusat" highlight-nya di sekitar arah pantul sempurna.
float ggxDistribution(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH2 = NdotH * NdotH;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    return a2 / max(3.14159265 * denom * denom, 0.0001);
}

// Smith geometry term (Schlick-GGX, direct-light remap).
// Mengoreksi self-shadowing/self-masking dari microfacet permukaan kasar.
float ggxGeometrySchlick(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / max(NdotV * (1.0 - k) + k, 0.0001);
}

float ggxGeometrySmith(float NdotV, float NdotL, float roughness) {
    return ggxGeometrySchlick(NdotV, roughness) * ggxGeometrySchlick(NdotL, roughness);
}

// Fresnel-Schlick -- dipusatkan di sini biar water & lava konsisten.
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Specular Cook-Torrance lengkap untuk satu arah cahaya.
// N, V, L wajib sudah dinormalisasi. Hasilnya BELUM dikali warna/intensitas cahaya.
vec3 ggxSpecular(vec3 N, vec3 V, vec3 L, float roughness, vec3 F0) {
    vec3 H = normalize(V + L);
    float NdotV = max(dot(N, V), 0.0001);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);

    if (NdotL <= 0.0) return vec3(0.0);

    float D = ggxDistribution(NdotH, roughness);
    float G = ggxGeometrySmith(NdotV, NdotL, roughness);
    vec3  F = fresnelSchlick(VdotH, F0);

    return (D * G * F) / max(4.0 * NdotV * NdotL, 0.0001);
}

#endif
#ifndef END_PALETTE_GLSL
#define END_PALETTE_GLSL

#define SKY_ZENITH          vec3(0.055, 0.020, 0.090) //[tuning] warna paling atas langit
#define SKY_MID             vec3(0.110, 0.045, 0.160) //[tuning] warna tengah langit
#define SKY_HORIZON         vec3(0.220, 0.100, 0.260) //[tuning] warna dekat horizon

#define NEBULA_CORE_MAGENTA vec3(0.55, 0.10, 0.55) //[tuning] inti nebula warna 1
#define NEBULA_CORE_BLUE    vec3(0.047, 0.341, 0.514) //[tuning] inti nebula warna 2
#define NEBULA_EDGE         vec3(0.30, 0.08, 0.35) //[tuning] warna tepi/gas tipis nebula

#define AMBIENT_LIGHT       vec3(0.32, 0.24, 0.42) //[tuning] ambient global, jangan dibikin abu-abu
#define FOG_NEAR            vec3(0.28, 0.16, 0.34) //[tuning] fog dekat kamera
#define FOG_FAR             vec3(0.10, 0.06, 0.16) //[tuning] fog jauh/horizon

#define CRYSTAL_GLOW        vec3(0.85, 0.35, 0.95) //[tuning] warna glow end crystal
#define PORTAL_GLOW         vec3(0.65, 0.20, 0.90) //[tuning] warna glow portal
#define BLOOM_TINT          vec3(0.90, 0.55, 1.00) //[tuning] tint tambahan area bloom

#endif
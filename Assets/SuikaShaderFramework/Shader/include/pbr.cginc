#ifndef SUIKA_PBR
#define SUIKA_PBR

//seed random
float Random (float seed) {
    return frac(sin(dot(seed, float2(12.9898,78.233)))*43758.5453123);
}

#endif
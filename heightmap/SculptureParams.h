//
//  SculptureParams.h
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/25.
//

#ifndef Header_h
#define Header_h

struct PlaneVertex {
    simd_float3 position;
    simd_float3 normal;
};

struct SculptureParams {
    float radius;
    float strength;
    simd_float2 position;
    simd_uint2 dimensions;
    simd_float2 size;
    simd_float2 cellSize;
};

struct MeshParams {
    simd_uint2 dimensions;
    simd_float2 size;
    float maxThickness;
};

#endif /* Header_h */
